from __future__ import annotations

import json
from datetime import date
from pathlib import Path

from backend.api.common import validate_official_url
from backend.schemas import ProfileUpdate, SchemeInput


CATALOG = Path(__file__).resolve().parent / "data" / "schemes.json"


def test_catalog_rows_are_review_queue_candidates_with_explicit_capture_dates():
    rows = json.loads(CATALOG.read_text(encoding="utf-8"))
    assert len(rows) == 40
    assert len({row["slug"] for row in rows}) == len(rows)
    assert all(row.get("source_checked_at") == "2026-10-08" for row in rows)
    assert all(row.get("catalog_capture_date") == "2026-10-08" for row in rows)
    assert not any(row.get("source_review_complete") for row in rows)
    assert not any(row.get("documents_review_complete") for row in rows)
    assert not any(row.get("ruleset_complete") for row in rows)
    assert not any(row.get("status") == "PUBLISHED" for row in rows)
    assert all(row.get("source_capture_level") for row in rows)
    assert all(row.get("document_review_note") for row in rows)
    assert all(row.get("source_facts") for row in rows)


def test_catalog_urls_are_https_and_on_the_reviewed_official_allowlist():
    rows = json.loads(CATALOG.read_text(encoding="utf-8"))
    for row in rows:
        assert validate_official_url(row["source_url"]), row["slug"]
        if row.get("application_url"):
            assert validate_official_url(row["application_url"]), row["slug"]


def test_catalog_rows_round_trip_through_admin_scheme_input_including_evidence_level():
    rows = json.loads(CATALOG.read_text(encoding="utf-8"))
    allowed = set(SchemeInput.model_fields)
    for row in rows:
        payload = {key: value for key, value in row.items() if key in allowed}
        validated = SchemeInput.model_validate(payload)
        assert validated.source_capture_level == row["source_capture_level"]
        assert validated.source_checked_at == date(2026, 10, 8)


def test_new_records_keep_application_unknown_when_no_current_route_was_verified():
    rows = {row["slug"]: row for row in json.loads(CATALOG.read_text(encoding="utf-8"))}
    for slug in (
        "national-mission-edible-oils-oilseeds",
        "mission-aatmanirbharta-pulses",
        "pm-dhan-dhaanya-krishi-yojana",
        "national-mission-natural-farming",
        "paramparagat-krishi-vikas-yojana",
        "pm-kusum",
        "namo-shetkari-mahasanman-nidhi",
    ):
        assert rows[slug]["application_url"] == ""
        assert not rows[slug]["source_review_complete"]
        assert not rows[slug]["ruleset_complete"]


def test_new_fisheries_and_livestock_candidates_keep_component_and_current_window_caveats():
    rows = {row["slug"]: row for row in json.loads(CATALOG.read_text(encoding="utf-8"))}
    insurance = rows["pm-mkssy-aquaculture-insurance-incentive"]
    assert "one crop cycle" in insurance["benefit_summary"].lower()
    assert "4 ha" in insurance["benefit_summary"]
    assert not insurance["source_review_complete"] and not insurance["ruleset_complete"]

    performance = rows["pm-mkssy-fisheries-performance-grant"]
    assert any("V2.0" in fact for fact in performance["source_facts"])
    assert "not an upfront subsidy" in performance["benefit_summary"]

    gokul = rows["rashtriya-gokul-mission-bovine-farmer-interventions"]
    assert any("2026-09-30" in fact for fact in gokul["source_facts"])
    assert "unknown" in gokul["summary"].lower()

    for slug in ("nlm-rural-poultry-entrepreneurship", "nlm-sheep-goat-entrepreneurship", "nlm-piggery-entrepreneurship"):
        assert "two conditional instalments" in rows[slug]["benefit_summary"]
        assert not rows[slug]["source_review_complete"]


def test_profile_can_record_optional_livestock_and_fisheries_interest_without_sensitive_data():
    profile_update = ProfileUpdate.model_validate({"support_needs": ["livestock", "fisheries"]})
    assert profile_update.support_needs == ["livestock", "fisheries"]
