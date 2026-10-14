"""Deterministic, source-aware recommendation and eligibility logic.

The engine never predicts government approval. Only explicitly modeled, reviewed
rules can produce a preliminary eligibility label. Unknown inputs, unreviewed
records, and incomplete rule sets fail closed to insufficient information.
"""
from __future__ import annotations

import math
import re
from typing import Any

ACRES_PER_HECTARE = 2.47105
RULE_OPERATORS = {
    "eq", "equals", "neq", "not_equals", "in", "not_in",
    "lt", "lte", "gt", "gte", "contains_any", "is_true", "is_false",
}
RULE_IMPACTS = {"eligibility", "review", "document"}


def _path(data: dict[str, Any], path: str) -> Any:
    value: Any = data
    for part in path.split("."):
        if not isinstance(value, dict):
            return None
        value = value.get(part)
    return value


def profile_completeness(profile: dict[str, Any]) -> dict[str, Any]:
    """A small, non-sensitive progress indicator; it is not an eligibility score."""
    checks = [
        ("district", bool(profile.get("district"))),
        ("taluka", bool(profile.get("taluka"))),
        ("village", bool(profile.get("village"))),
        ("land", isinstance(profile.get("land_area_acres"), (int, float)) and not isinstance(profile.get("land_area_acres"), bool) and profile.get("land_area_acres", 0) > 0),
        ("crop", bool(profile.get("crop"))),
        ("farmer_category", bool(profile.get("farmer_category")) and profile.get("farmer_category") != "unknown"),
        ("irrigation", profile.get("irrigation") in ("yes", "no")),
        ("land_7_12", profile.get("documents", {}).get("land_7_12") in ("available", "needs_verification")),
        ("land_8a", profile.get("documents", {}).get("land_8a") in ("available", "needs_verification")),
    ]
    total = len(checks)
    done = sum(1 for _, is_done in checks if is_done)
    missing = [key for key, is_done in checks if not is_done]
    return {"percent": round(done * 100 / total) if total else 0, "complete": done, "total": total, "missing": missing}


def _check(check: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    """Legacy source notes retained for display; they do not disqualify by default."""
    kind = check.get("kind", "unknown")
    field = check.get("field", "")
    value = _path(profile, field) if field else None
    result: dict[str, Any] = {
        "id": str(check.get("id", "unidentified_check")),
        "label": str(check.get("label", "Scheme condition")),
        "source_backed": True,
        "decision_role": "context_only",
    }

    if kind == "boolean":
        if value is True:
            result.update(status="pass", explanation="Marked present in the profile; this is self-reported and not document-verified.")
        elif value is False:
            result.update(status="missing", explanation="The profile says this is not present. Confirm whether the selected component requires it.")
        else:
            result.update(status="unknown", explanation="Not recorded in the profile.")
    elif kind == "document":
        if value == "available":
            result.update(status="pass", explanation="Self-reported available; Scheme Mitra has not checked the document.")
        elif value == "needs_verification":
            result.update(status="unknown", explanation="Marked for verification; validity has not been checked.")
        else:
            result.update(status="missing", explanation="Not marked available in the profile. A missing checklist item is not, by itself, proof of ineligibility.")
    elif kind == "area_cap":
        acres = profile.get("land_area_acres")
        if not isinstance(acres, (int, float)) or isinstance(acres, bool):
            result.update(status="unknown", explanation="Land area is missing.")
        elif acres <= check.get("value", -1):
            result.update(status="pass", explanation="Entered area is within the captured benefit-area limit; confirm the eligible plot/component on the current official page.")
        else:
            result.update(status="review", explanation="Entered area exceeds the captured benefit-area limit. This may affect the component/benefit, not necessarily the entire scheme; confirm with the department.")
    elif kind == "conditional_boolean":
        pump = profile.get("electric_water_pump", "unknown")
        connection = profile.get("permanent_electric_connection", "unknown")
        if pump == "no":
            result.update(status="not_applicable", explanation="Profile says no electric water pump is used; confirm this matches the proposed setup.")
        elif pump == "yes" and connection == "yes":
            result.update(status="pass", explanation="Both fields are self-reported; electricity-bill evidence is still listed separately.")
        elif pump == "yes" and connection == "no":
            result.update(status="review", explanation="The captured source page describes a permanent connection requirement when an electric water pump is used; independently verify the current component rule.")
        else:
            result.update(status="unknown", explanation="Confirm whether an electric water pump is used and, if so, whether a permanent connection is available.")
    elif kind == "history":
        if value == "none":
            result.update(status="pass", explanation="Profile says no previous benefit for this item/plot; this history has not been verified.")
        elif value in ("unknown", None, ""):
            result.update(status="unknown", explanation="Previous benefit history is not recorded; verify the scheme-specific waiting period and item/plot rules.")
        else:
            result.update(status="review", explanation="A prior benefit is recorded. Confirm the scheme-specific waiting period and survey/item details on the official portal.")
    elif kind == "crop_tag":
        crop = str(value or "").strip().lower()
        allowed = [str(v).lower() for v in check.get("value", [])]
        if crop and crop in allowed:
            result.update(status="pass", explanation="The captured source mentions this crop/component scope; this is only a relevance signal, not a component-level eligibility decision.")
        elif crop:
            result.update(status="review", explanation="The crop label did not clearly match the limited source summary; check the selected component with the department.")
        else:
            result.update(status="unknown", explanation="Crop is not recorded.")
    elif kind == "conditional_category":
        category = profile.get("social_category", "not_provided")
        if category in ("sc", "st", "nav_buddhist"):
            doc = profile.get("documents", {}).get("caste_certificate")
            if doc == "available":
                result.update(status="pass", explanation="Certificate is self-reported available; it has not been verified.")
            else:
                result.update(status="review", explanation="The source page lists a category certificate for the applicable group; verify the exact component requirement.")
        elif category in ("open", "obc", "not_applicable"):
            result.update(status="not_applicable", explanation="The captured rule describes this document as conditional; check the selected component.")
        else:
            result.update(status="unknown", explanation="Social category is not recorded. The profile does not ask for it unless a scheme condition needs it.")
    else:
        if value not in (None, "", "unknown", "not_provided"):
            result.update(status="review", explanation="A value is recorded; verify the selected item/component against the current official rules.")
        else:
            result.update(status="unknown", explanation="This information is not in the profile and must be checked for the chosen component.")
    return result


def _profile_signal_score(scheme: dict[str, Any], profile: dict[str, Any]) -> int:
    """Return an explainable profile-fit score, never eligibility or probability."""
    state = str(profile.get("state", "")).strip().lower()
    location = 20 if state in ("maharashtra", "mh") else 0

    need = scheme.get("need")
    needs = [str(item).lower() for item in profile.get("support_needs", [])]
    support = 20 if need in needs else (8 if need else 0)

    crop = str(profile.get("crop", "")).strip().lower()
    crop_tags = [str(tag).lower() for tag in scheme.get("crop_tags", [])]
    if crop and crop in crop_tags:
        crop_fit = 20
    elif "*" in crop_tags:
        crop_fit = 12
    elif crop and any(tag in crop for tag in crop_tags):
        crop_fit = 16
    else:
        crop_fit = 0

    completeness = profile_completeness(profile)
    profile_coverage = round(15 * completeness["percent"] / 100)

    docs = profile.get("documents", {})
    core_docs = ["land_7_12", "land_8a"]
    ready = sum(1 for doc in core_docs if docs.get(doc) == "available")
    doc_score = ready * 5

    route_score = 10 if scheme.get("source_url") and scheme.get("application_url") else 0
    raw = location + support + crop_fit + profile_coverage + doc_score + route_score
    return max(0, min(100, raw))


def _match_reasons(scheme: dict[str, Any], profile: dict[str, Any]) -> list[str]:
    reasons: list[str] = []
    if str(profile.get("state", "")).strip().lower() in ("maharashtra", "mh"):
        reasons.append("Your profile is in Maharashtra, the state covered by this portal record.")
    need = scheme.get("need")
    needs = [str(item).lower() for item in profile.get("support_needs", [])]
    if need and need in needs:
        need_label = {"irrigation":"irrigation", "horticulture":"horticulture", "machinery":"farm machinery", "income_support":"income support", "crop_protection":"crop protection", "livestock":"livestock and dairy", "fisheries":"fisheries and aquaculture"}.get(need, need)
        reasons.append(f"You selected {need_label} support as a priority.")
    crop = str(profile.get("crop", "")).strip().lower()
    crop_tags = [str(tag).lower() for tag in scheme.get("crop_tags", [])]
    if crop and crop in crop_tags:
        reasons.append(f"Your crop ({crop}) appears in the scheme's captured crop scope; this is not an eligibility finding.")
    elif "*" in crop_tags and crop:
        reasons.append("The captured page summary does not make crop a specific matching condition.")
    if scheme.get("slug") == "pmksy-micro-irrigation":
        area = profile.get("land_area_acres")
        if isinstance(area, (int, float)) and not isinstance(area, bool) and area <= 5 * ACRES_PER_HECTARE:
            reasons.append("Your entered area is within the captured 5-hectare benefit limit; confirm the exact eligible plot/component.")
    docs = profile.get("documents", {})
    available_land = [label for key, label in (("land_7_12", "7/12"), ("land_8a", "8-A")) if docs.get(key) == "available"]
    if available_land:
        reasons.append("Land records marked available (self-reported): " + " and ".join(available_land) + ".")
    if not reasons:
        reasons.append("The catalogue record has a related scheme topic; this profile-match signal is not an eligibility decision.")
    return reasons[:4]


def _is_missing(value: Any) -> bool:
    return value is None or (isinstance(value, str) and value.strip().casefold() in {"", "unknown", "not_provided", "not recorded"})


def _normal(value: Any) -> Any:
    if isinstance(value, str):
        return value.strip().casefold()
    return value


def _condition_result(actual: Any, operator: str, rule: dict[str, Any]) -> bool | None:
    """Evaluate one allow-listed comparison. None means the input is unusable."""
    operator = str(operator or "").strip().lower()
    if operator not in RULE_OPERATORS or _is_missing(actual):
        return None
    expected = rule.get("values") if operator in {"in", "not_in", "contains_any"} else rule.get("value")
    if expected is None:
        return None
    left = _normal(actual)

    if operator in {"eq", "equals", "neq", "not_equals"}:
        equal = left == _normal(expected)
        return not equal if operator in {"neq", "not_equals"} else equal
    if operator in {"in", "not_in"}:
        if not isinstance(expected, list) or not expected:
            return None
        matched = left in [_normal(item) for item in expected]
        return not matched if operator == "not_in" else matched
    if operator == "contains_any":
        if isinstance(actual, str):
            actual_values = {_normal(part) for part in re.split(r"[,;|]", actual) if part.strip()}
        elif isinstance(actual, (list, tuple, set)):
            actual_values = {_normal(part) for part in actual}
        else:
            return None
        if not isinstance(expected, list) or not expected:
            return None
        return bool(actual_values.intersection({_normal(item) for item in expected}))
    if operator in {"lt", "lte", "gt", "gte"}:
        if isinstance(actual, bool) or isinstance(expected, bool):
            return None
        try:
            left_number, right_number = float(actual), float(expected)
        except (TypeError, ValueError):
            return None
        if not math.isfinite(left_number) or not math.isfinite(right_number):
            return None
        if operator == "lt": return left_number < right_number
        if operator == "lte": return left_number <= right_number
        if operator == "gt": return left_number > right_number
        return left_number >= right_number
    if operator in {"is_true", "is_false"}:
        if not isinstance(actual, bool):
            return None
        return actual is (operator == "is_true")
    return None


def _evaluate_rule(rule: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    rule_id = str(rule.get("id", "unidentified_rule"))[:80]
    label = str(rule.get("label", "Source-backed condition"))[:240]
    field = str(rule.get("field", ""))
    operator = str(rule.get("operator", ""))
    impact = str(rule.get("impact", "eligibility"))
    result: dict[str, Any] = {
        "id": rule_id, "label": label, "field": field,
        "operator": operator, "impact": impact,
        "source_backed": bool(rule.get("source_fact") and rule.get("source_url")),
        "source_fact": str(rule.get("source_fact", ""))[:1200],
        "source_url": str(rule.get("source_url", ""))[:1200],
    }
    if impact not in RULE_IMPACTS or operator not in RULE_OPERATORS or not field:
        result.update(status="unknown", explanation="This rule is malformed or uses an unsupported comparison; a reviewer must correct it.")
        return result

    when = rule.get("when")
    if when is not None:
        if not isinstance(when, dict) or not when.get("field"):
            result.update(status="unknown", explanation="The rule's condition is malformed; a reviewer must correct it.")
            return result
        when_actual = _path(profile, str(when.get("field")))
        when_match = _condition_result(when_actual, str(when.get("operator", "")), when)
        if when_match is None:
            result.update(status="unknown", explanation="Information needed to determine whether this conditional rule applies is missing.")
            return result
        if not when_match:
            result.update(status="not_applicable", explanation="The rule's documented condition does not apply based on the profile provided.")
            return result

    actual = _path(profile, field)
    matched = _condition_result(actual, operator, rule)
    if matched is None:
        result.update(status="unknown", explanation=f"Information for '{label}' is missing, invalid, or not comparable.")
    elif matched:
        result.update(status="pass", explanation="The information entered matches this explicitly recorded comparison; it is not independently verified.")
    elif impact == "eligibility":
        result.update(status="fail", explanation="The information entered does not meet this explicitly recorded scheme criterion. Check the source and relevant component before acting.")
    else:
        result.update(status="review", explanation="The information entered does not match this recorded condition; this is a review/documentation flag, not a scheme-level disqualification.")
    return result


def validate_eligibility_rules(rules: Any, ruleset_complete: bool = False) -> list[str]:
    """Return schema issues for the small, non-executable eligibility-rule format."""
    errors: list[str] = []
    if not isinstance(rules, list):
        return ["eligibility_rules must be a JSON array."]
    if ruleset_complete and not rules:
        errors.append("A complete rule set must contain at least one eligibility rule.")
    seen: set[str] = set()
    for index, rule in enumerate(rules[:100]):
        prefix = f"eligibility_rules[{index}]"
        if not isinstance(rule, dict):
            errors.append(f"{prefix} must be an object.")
            continue
        required = ("id", "label", "field", "operator", "impact", "source_fact", "source_url")
        missing = [key for key in required if not rule.get(key)]
        if missing:
            errors.append(f"{prefix} is missing: {', '.join(missing)}.")
            continue
        rule_id = str(rule.get("id", ""))
        if not re.fullmatch(r"[a-z][a-z0-9_]{1,79}", rule_id):
            errors.append(f"{prefix}.id must be a stable lowercase identifier.")
        if rule_id in seen:
            errors.append(f"{prefix}.id is duplicated.")
        seen.add(rule_id)
        if str(rule.get("operator")) not in RULE_OPERATORS:
            errors.append(f"{prefix}.operator is not supported.")
        if str(rule.get("impact")) not in RULE_IMPACTS:
            errors.append(f"{prefix}.impact must be eligibility, review, or document.")
        op = str(rule.get("operator", ""))
        if op in {"in", "not_in", "contains_any"}:
            if not isinstance(rule.get("values"), list) or not rule.get("values"):
                errors.append(f"{prefix}.values must be a non-empty array for {op}.")
        elif op not in {"is_true", "is_false"} and "value" not in rule:
            errors.append(f"{prefix}.value is required for {op}.")
        if not isinstance(rule.get("source_fact"), str) or len(str(rule.get("source_fact", ""))) < 10:
            errors.append(f"{prefix}.source_fact must identify the supporting official fact.")
        if not isinstance(rule.get("source_url"), str) or not rule.get("source_url", "").startswith("https://"):
            errors.append(f"{prefix}.source_url must be an HTTPS official source URL.")
        when = rule.get("when")
        if when is not None and (not isinstance(when, dict) or not when.get("field") or when.get("operator") not in RULE_OPERATORS):
            errors.append(f"{prefix}.when must be a field/operator/value condition using a supported comparison.")
    if len(rules) > 100:
        errors.append("Eligibility rules are limited to 100 per scheme.")
    return errors


def evaluate_scheme(scheme: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    legacy_checks = [_check(item, profile) for item in scheme.get("checks", []) if isinstance(item, dict)]
    raw_rules = scheme.get("eligibility_rules", [])
    if not isinstance(raw_rules, list):
        raw_rules = []
    rule_results = [_evaluate_rule(item, profile) for item in raw_rules if isinstance(item, dict)]
    # Malformed entries are represented as unknown rather than being silently ignored.
    for index, item in enumerate(raw_rules):
        if not isinstance(item, dict):
            rule_results.append({"id": f"malformed_{index}", "label": "Malformed eligibility rule", "impact": "eligibility", "status": "unknown", "source_backed": False, "explanation": "This rule is malformed and requires reviewer correction."})

    hard_failures = [item for item in rule_results if item.get("impact") == "eligibility" and item.get("status") == "fail" and item.get("source_backed")]
    material_unknowns = [item for item in rule_results if item.get("impact") == "eligibility" and item.get("status") == "unknown"]
    secondary_unresolved = [item for item in rule_results if item.get("impact") in {"review", "document"} and item.get("status") in {"unknown", "review"}]
    legacy_unresolved = [item for item in legacy_checks if item.get("status") in {"unknown", "review", "missing"}]

    ruleset_complete = scheme.get("ruleset_complete") is True
    source_verified = scheme.get("status") == "PUBLISHED" and scheme.get("verification_status") == "VERIFIED"
    has_eligibility_rules = any(item.get("impact") == "eligibility" for item in rule_results)

    if hard_failures and source_verified:
        status_code = "NOT_ELIGIBLE"
        status_label = "Not Eligible based on available information"
        decision_reasons = ["The information entered conflicts with this published, source-backed criterion: " + "; ".join(item["label"] for item in hard_failures) + "."]
    elif not source_verified or not ruleset_complete or not has_eligibility_rules or material_unknowns:
        status_code = "INSUFFICIENT_INFORMATION"
        status_label = "Insufficient Information"
        decision_reasons = []
        if not source_verified:
            decision_reasons.append("This scheme record is not both human-verified and published, so it cannot support a preliminary eligibility finding.")
        if not ruleset_complete:
            decision_reasons.append("The official eligibility rule set is incomplete or has not been attested as complete by a reviewer.")
        if not has_eligibility_rules:
            decision_reasons.append("No machine-readable eligibility criteria are available for this scheme version.")
        if material_unknowns:
            decision_reasons.append("Some required profile facts are missing: " + "; ".join(item["label"] for item in material_unknowns) + ".")
        if not decision_reasons:
            decision_reasons.append("More information is required to compare the profile with the published rules.")
    elif secondary_unresolved or legacy_unresolved:
        status_code = "POTENTIALLY_ELIGIBLE"
        status_label = "Potentially Eligible — verification required"
        unresolved = secondary_unresolved + legacy_unresolved
        decision_reasons = ["All currently evaluated eligibility criteria match, but these items still need verification: " + "; ".join(dict.fromkeys(item["label"] for item in unresolved)) + "."]
    else:
        status_code = "LIKELY_ELIGIBLE"
        status_label = "Likely Eligible"
        decision_reasons = ["All explicitly modeled, human-verified eligibility criteria match the information you provided. The relevant authority still makes the final decision."]

    score = _profile_signal_score(scheme, profile)
    match_reasons = _match_reasons(scheme, profile)
    unresolved_info = [item for item in rule_results if item.get("status") in {"unknown", "review"}]
    unresolved_info += [item for item in legacy_checks if item.get("status") in {"unknown", "review"}]

    documents = []
    for item in scheme.get("document_items", []):
        if not isinstance(item, dict) or not item.get("id"):
            continue
        state = profile.get("documents", {}).get(item["id"], "not_provided")
        if state == "available":
            display_state = "self_reported_available"
        elif state == "needs_verification":
            display_state = "needs_verification"
        elif state in ("not_yet_required", "not_yet_issued"):
            display_state = state
        else:
            display_state = "not_provided"
        documents.append({**item, "state": display_state})

    available = sum(1 for item in documents if item["state"] == "self_reported_available")
    return {
        "scheme_slug": scheme.get("slug", ""),
        "profile_match": score,
        "status": status_code,
        "status_label": status_label,
        "decision_reasons": decision_reasons,
        "match_reasons": match_reasons,
        "passed_rules": [item for item in rule_results if item.get("status") == "pass"],
        "failed_rules": hard_failures,
        "missing_information": unresolved_info,
        "eligibility_rules": rule_results,
        "checks": legacy_checks,
        "ruleset_complete": ruleset_complete,
        "source_verified": source_verified,
        "documents": documents,
        "documents_available": available,
        "documents_total": len(documents),
        "profile_completeness": profile_completeness(profile),
        "evaluated_note": "Preliminary deterministic comparison of the profile information and published source-backed rules. This is not an official eligibility decision, an application submission, or a guarantee. The relevant authority makes the final decision."
    }


def generate_recommendations(schemes: list[dict[str, Any]], profile: dict[str, Any]) -> list[dict[str, Any]]:
    priority = {"LIKELY_ELIGIBLE": 3, "POTENTIALLY_ELIGIBLE": 2, "INSUFFICIENT_INFORMATION": 1, "NOT_ELIGIBLE": 0}
    output = []
    for scheme in schemes:
        result = evaluate_scheme(scheme, profile)
        output.append({**scheme, "evaluation": result})
    output.sort(key=lambda item: (priority.get(item["evaluation"]["status"], 0), item["evaluation"]["profile_match"], item.get("name", "")), reverse=True)
    return output
