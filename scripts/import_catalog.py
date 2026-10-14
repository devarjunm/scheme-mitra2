#!/usr/bin/env python3
"""Import official-source capture records into PostgreSQL as UNDER_REVIEW.

This tool never publishes content and never fetches/scrapes a government site.
It is safe to re-run: existing slugs are skipped. Use --apply only after the
schema migration has run and the target DATABASE_URL has been checked.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from sqlalchemy import select

from backend.db import SessionLocal
from backend.models import AuditLog, Scheme, SchemeVersion

CATALOG = Path(__file__).resolve().parents[1] / "backend" / "data" / "schemes.json"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Write new records to the configured database (otherwise dry-run).")
    args = parser.parse_args()
    records = json.loads(CATALOG.read_text(encoding="utf-8"))
    if not isinstance(records, list):
        raise SystemExit("Catalog must be a JSON array.")
    slugs = [row.get("slug") for row in records if isinstance(row, dict)]
    if len(slugs) != len(records) or len(slugs) != len(set(slugs)) or any(not slug for slug in slugs):
        raise SystemExit("Catalog must contain unique, non-empty scheme slugs.")

    with SessionLocal() as db:
        existing = set(db.scalars(select(Scheme.slug).where(Scheme.slug.in_(slugs))).all())
        pending = [row for row in records if row["slug"] not in existing]
        print(f"Catalog rows: {len(records)}; already present: {len(existing)}; to add as UNDER_REVIEW: {len(pending)}")
        if not args.apply:
            print("Dry-run only. Re-run with --apply to persist; no record will be PUBLISHED.")
            return 0
        for raw in pending:
            captured = dict(raw)
            captured["source_review_complete"] = False
            scheme = Scheme(
                slug=captured["slug"], name=captured["name"], department=captured["department"],
                category=captured.get("category", "General"), level=captured.get("level", "State"),
                status="UNDER_REVIEW", verification_status="NEEDS_REVIEW",
                source_url=captured["source_url"], application_url=captured.get("application_url", ""),
                source_name=captured["source_name"], data_json=captured, version=1,
            )
            db.add(scheme)
            db.flush()
            db.add(SchemeVersion(
                scheme_id=scheme.id, version=1, snapshot=dict(captured), source_url=scheme.source_url,
                change_reason="Initial official-source capture; independent human review required",
            ))
            db.add(AuditLog(
                actor_user_id=None, action="CATALOG_IMPORTED", entity_type="scheme", entity_id=scheme.slug,
                old_value=None, new_value={"status": "UNDER_REVIEW", "version": 1},
                reason="Bulk source-index import; not human-verified or published",
            ))
        db.commit()
        print(f"Imported {len(pending)} record(s) as UNDER_REVIEW. Farmer routes expose PUBLISHED + VERIFIED records only.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
