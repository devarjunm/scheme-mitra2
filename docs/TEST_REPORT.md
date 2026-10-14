# Test report

**Run date:** 2026-10-08 (workspace local time)  
**Status:** local development checks only; not a production sign-off.

## Checks performed for this catalog update

- `python -m pytest -q backend` — **28 passed, 1 warning**. Includes deterministic eligibility, assistant grounding, production-config validation, role/CSRF boundaries, mobile bearer-token authentication and logout, account deletion, unpublished-scheme hiding, source/document review gates, distinct editor/verifier/publisher workflow, catalog tests for the 40 candidate rows, source dates, official URL allow-list, admin-schema round-tripping of evidence capture level, unknown application routes, PM-MKSSY/RGM time-bound caveats, and optional livestock/fisheries support preferences. The warning is Starlette's deprecation notice for the installed `httpx` TestClient integration.
- `node --check frontend/admin.js`, `node --check frontend/app.js` — passed.
- `python -m compileall -q backend` — passed.
- Prior SQLite migration validation — previously succeeded against SQLite; not rerun for this catalog/UI-only update. PostgreSQL migration behavior remains unverified.

## Not tested / limitations

- No live PostgreSQL service was available. PostgreSQL migration execution, runtime constraints/queries, TLS, backups and failover remain unverified.
- No Docker executable was available, so the container build and Compose stack were not run.
- Flutter/Dart, JDK 17 and Android SDK tooling were unavailable. Flutter analysis, widget tests, Gradle sync and release AAB build remain unverified. No signed release artifact was produced.
- CI has not run. There was no real browser/device E2E, accessibility audit, performance/load/soak test, chaos/failover test, backup restore, TLS/proxy integration or multi-worker test.
- No independent security/privacy assessment, penetration test, dependency scan or real farmer pilot has been completed.
- Tests use synthetic data and source-catalog assertions; they do not independently validate any scheme term. The **40 seed records remain review candidates**; no record has source/document sign-off or a complete eligibility ruleset. Search-result-only evidence, older guideline periods, current application windows, Maharashtra district applicability and scheme-specific documents require direct human review.

A successful local check does not prove production safety, scheme correctness, service availability or farmer impact. See [security review](SECURITY_REVIEW.md), [source ledger](DATA_VERIFICATION.md) and [deployment runbook](DEPLOYMENT.md).
