from __future__ import annotations

import json
import unittest
from pathlib import Path

from backend.database import DEFAULT_PROFILE
from backend.eligibility import evaluate_scheme, generate_recommendations, profile_completeness, validate_eligibility_rules

SCHEMES = json.loads((Path(__file__).parent / "data" / "schemes.json").read_text(encoding="utf-8"))
OFFICIAL_URL = "https://pmkisan.gov.in/"


def rule(rule_id: str, field: str, operator: str, value, impact: str = "eligibility") -> dict:
    return {
        "id": rule_id,
        "label": f"Recorded {field} condition",
        "field": field,
        "operator": operator,
        "value": value,
        "impact": impact,
        "source_fact": f"Official source records the {field} condition for this test fixture.",
        "source_url": OFFICIAL_URL,
    }


def verified_scheme(*rules: dict, ruleset_complete: bool = True) -> dict:
    return {
        "slug": "unit-test-scheme",
        "name": "Unit test scheme",
        "category": "Irrigation",
        "need": "irrigation",
        "crop_tags": ["onion"],
        "source_url": OFFICIAL_URL,
        "application_url": OFFICIAL_URL,
        "status": "PUBLISHED",
        "verification_status": "VERIFIED",
        "ruleset_complete": ruleset_complete,
        "eligibility_rules": list(rules),
        "document_items": [
            {"id": "land_7_12", "label": "7/12 extract", "stage": "Before applying", "required": True}
        ],
    }


class EligibilityEngineTests(unittest.TestCase):
    def setUp(self):
        self.profile = json.loads(json.dumps(DEFAULT_PROFILE))

    def test_profile_completeness_is_not_eligibility_and_reports_missing_village(self):
        result = profile_completeness(self.profile)
        self.assertEqual(result["percent"], 89)
        self.assertIn("village", result["missing"])

    def test_candidate_catalog_stays_insufficient_until_reviewed_and_rule_complete(self):
        results = generate_recommendations(SCHEMES, self.profile)
        self.assertEqual([r["slug"] for r in results], [r["slug"] for r in generate_recommendations(SCHEMES, self.profile)])
        self.assertEqual(len(results), 40)
        self.assertTrue(all(r["evaluation"]["status"] == "INSUFFICIENT_INFORMATION" for r in results))
        self.assertTrue(all("profile_match" in r["evaluation"] for r in results))
        self.assertTrue(all(r["evaluation"]["source_verified"] is False for r in results))

    def test_all_verified_criteria_matching_produces_likely_not_approval(self):
        scheme = verified_scheme(rule("state_match", "state", "eq", "Maharashtra"))
        result = evaluate_scheme(scheme, self.profile)
        self.assertEqual(result["status"], "LIKELY_ELIGIBLE")
        self.assertTrue(result["source_verified"])
        self.assertIn("relevant authority still makes the final decision", result["decision_reasons"][0])
        self.assertIn("not an official eligibility decision", result["evaluated_note"])

    def test_secondary_review_condition_yields_potentially_eligible(self):
        scheme = verified_scheme(
            rule("state_match", "state", "eq", "Maharashtra"),
            rule("component_review", "irrigation", "eq", "no", impact="review"),
        )
        result = evaluate_scheme(scheme, self.profile)
        self.assertEqual(result["status"], "POTENTIALLY_ELIGIBLE")
        self.assertTrue(any(item["status"] == "review" for item in result["eligibility_rules"]))

    def test_published_source_backed_hard_failure_is_not_eligible_based_on_available_information(self):
        scheme = verified_scheme(rule("state_match", "state", "eq", "Gujarat"))
        result = evaluate_scheme(scheme, self.profile)
        self.assertEqual(result["status"], "NOT_ELIGIBLE")
        self.assertTrue(result["failed_rules"])
        self.assertIn("Not Eligible based on available information", result["status_label"])

    def test_unverified_hard_failure_cannot_produce_not_eligible(self):
        scheme = verified_scheme(rule("state_match", "state", "eq", "Gujarat"))
        scheme["status"] = "UNDER_REVIEW"
        scheme["verification_status"] = "NEEDS_REVIEW"
        result = evaluate_scheme(scheme, self.profile)
        self.assertEqual(result["status"], "INSUFFICIENT_INFORMATION")
        self.assertFalse(result["source_verified"])
        self.assertNotIn("NOT_ELIGIBLE", result["status"])

    def test_missing_required_input_and_incomplete_ruleset_fail_closed(self):
        missing_input = verified_scheme(rule("income_cap", "annual_income_inr", "lte", 150000))
        result = evaluate_scheme(missing_input, self.profile)
        self.assertEqual(result["status"], "INSUFFICIENT_INFORMATION")
        self.assertEqual(result["missing_information"][0]["status"], "unknown")

        incomplete = verified_scheme(rule("state_match", "state", "eq", "Maharashtra"), ruleset_complete=False)
        self.assertEqual(evaluate_scheme(incomplete, self.profile)["status"], "INSUFFICIENT_INFORMATION")

    def test_document_checklist_is_self_reported_and_never_validated(self):
        scheme = verified_scheme(rule("state_match", "state", "eq", "Maharashtra"))
        result = evaluate_scheme(scheme, self.profile)
        land = next(item for item in result["documents"] if item["id"] == "land_7_12")
        self.assertEqual(land["state"], "self_reported_available")
        self.assertFalse(land.get("validated", False))
        self.assertEqual(result["documents_available"], 1)

    def test_rule_validator_requires_source_facts_and_official_https_urls(self):
        invalid = rule("state_match", "state", "eq", "Maharashtra")
        invalid["source_url"] = "http://example.test/rule"
        errors = validate_eligibility_rules([invalid], ruleset_complete=True)
        self.assertTrue(any("HTTPS official source URL" in error for error in errors))
        self.assertTrue(validate_eligibility_rules([], ruleset_complete=True))

    def test_legacy_source_notes_remain_context_not_scheme_level_failures(self):
        scheme = verified_scheme(rule("state_match", "state", "eq", "Maharashtra"))
        scheme["checks"] = [{
            "id": "area_cap", "label": "Captured component-area limit", "field": "land_area_acres",
            "kind": "area_cap", "value": 1.0,
        }]
        large_area = {**self.profile, "land_area_acres": 20.0}
        result = evaluate_scheme(scheme, large_area)
        self.assertEqual(result["checks"][0]["status"], "review")
        self.assertEqual(result["status"], "POTENTIALLY_ELIGIBLE")


if __name__ == "__main__":
    unittest.main()
