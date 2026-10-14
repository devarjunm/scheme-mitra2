# API reference

The production API is the FastAPI application at `backend/api/main.py`. Interactive OpenAPI is served at `/api-docs`; `/openapi.json` is the machine-readable schema. JSON API routes are under `/api/v1`. The old standard-library MVP API is no longer the entry point.

## Authentication and request safety

- `POST /api/v1/auth/register` — create a farmer account. Required: email, 12+ character password containing letters and digits, and full name. Optional state/district/taluka. Returns a signed session cookie.
- `POST /api/v1/auth/login` — sign in with email/password; unknown account and wrong password return the same error.
- `POST /api/v1/auth/demo` — open the synthetic farmer, only while `DEMO_MODE=true`.
- `GET /api/v1/auth/me` — current authenticated account.
- `POST /api/v1/auth/logout` — revokes the server-side browser session and clears cookies.
- `POST /api/v1/auth/mobile/register`, `/mobile/login`, `/mobile/demo` — issue short-lived, mobile-audience bearer tokens for the Flutter client; demo is available only when enabled.
- `POST /api/v1/auth/mobile/logout` — revokes the supplied mobile bearer session.
- `DELETE /api/v1/account` — password-confirmed account/data deletion; demo users are not deletable and the final active super-admin cannot delete itself.

Web access uses an HttpOnly session cookie (not browser local storage) and unsafe cookie-authenticated requests require `X-CSRF-Token`, matching the readable `scheme_mitra_csrf` cookie. The Flutter client uses a separate bearer-token audience and stores its token in secure device storage. The API rate limiter is Redis-backed in production. Never disable CSRF or trust unreviewed proxy headers to make a client work.

## Farmer and scheme routes

| Method | Route | Purpose |
|---|---|---|
| `GET` / `PUT` | `/api/v1/profile` | Read/update the authenticated farmer profile. |
| `GET` / `POST` / `PUT` / `DELETE` | `/api/v1/land` and `/api/v1/land/{land_id}` | Manage the farmer's own land records. |
| `GET` / `POST` / `PUT` / `DELETE` | `/api/v1/crops` and `/api/v1/crops/{crop_id}` | Manage the farmer's own crop records. |
| `GET` / `PATCH` / `DELETE` | `/api/v1/documents` and `/api/v1/documents/{document_id}` | Manage checklist state only. No file upload or validation. |
| `GET` | `/api/v1/schemes?q=&category=` | Return visible source records with deterministic evaluations. |
| `GET` | `/api/v1/schemes/{slug}` | Return one scheme and this user's evaluation. |
| `GET` / `POST` | `/api/v1/eligibility/{scheme_slug}`, `/api/v1/eligibility/evaluate/{scheme_slug}` | Read or recompute deterministic evaluation for a visible scheme. |
| `GET` | `/api/v1/recommendations` | Compute profile-fit recommendations. |
| `POST` | `/api/v1/recommendations/generate` | Compute and persist recommendation snapshots. Empty JSON body. |
| `GET` | `/api/v1/saved` | List the authenticated farmer's saved schemes. |
| `POST` / `DELETE` | `/api/v1/saved/{slug}` | Add/remove a saved scheme. |
| `GET` / `POST` | `/api/v1/applications` | List/create user-entered application tracker records. |
| `GET` / `PUT` | `/api/v1/applications/{application_id}` | Read/update the authenticated user's tracker record. |
| `POST` | `/api/v1/assistant/question` | Rule-grounded answer from local profile and captured scheme records; no external AI provider. |
| `POST` | `/api/v1/feedback`, `/api/v1/recommendation-feedback` | Save user feedback. |
| `POST` / `GET` | `/api/v1/pilot-surveys`, `/api/v1/pilot-metrics` | Store/read user-scoped pilot observations and product events. |
| `POST` | `/api/v1/events` | Record an allow-listed product event; event metadata is minimized. |
| `GET` | `/api/v1/notifications` | List the authenticated user's notifications. |
| `PUT` | `/api/v1/notifications/{notification_id}/read` | Mark one of the authenticated user's notifications read. |

Eligibility evaluation is deterministic. The `profile_match` value is profile overlap only; it is not an eligibility result, approval probability, or official decision. A checklist's `available` value is self-reported. Application tracker statuses are user-entered and are not fetched from MahaDBT. Optional `support_needs` preferences include irrigation, horticulture, machinery, income support, crop protection, livestock/dairy and fisheries/aquaculture; these preferences only affect relevance ranking and do not prove that a farmer raises livestock or operates an aquaculture business.

## Administration routes

All administration routes require a role. `ADMIN`/`SUPER_ADMIN` can publish/archive and propose pilots; `DATA_VERIFIER`/`ADMIN`/`SUPER_ADMIN` can verify; `ADMIN`/`DATA_VERIFIER`/`SUPER_ADMIN` can view/edit source records. The API also requires a verifier different from the account that last edited the current version, and a publisher different from the recorded verifier. The farmer-facing catalog does not show unpublished records to normal accounts.

- `GET /api/v1/admin/overview`
- `GET /api/v1/admin/schemes`
- `POST /api/v1/admin/schemes` — create a record in `UNDER_REVIEW` (official HTTPS source URL required).
- `PUT /api/v1/admin/schemes/{slug}` — replace source/rule data, increment version, and return the record to review. Body contains both `payload` and `note`, e.g. `{"payload": { ...scheme fields... }, "note": {"reason": "Reviewed source page"}}`.
- `POST /api/v1/admin/schemes/import` — import up to 100 records; all enter review.
- `POST /api/v1/admin/schemes/{slug}/verify` — record named-user human verification. Body: `{"reason":"..."}`. Verification requires the current-source and document-review attestations, explicit document note (including unknowns), source facts, benefits/process, official application route, and structurally valid deterministic rule data.
- `POST /api/v1/admin/schemes/{slug}/publish` — separately publish a verified version. Body: `{"reason":"..."}`.
- `POST /api/v1/admin/schemes/{slug}/archive` — archive a record. Body: `{"reason":"..."}`.
- `GET /api/v1/admin/audit-logs?limit=100`
- `GET /api/v1/admin/analytics` — system usage counts, not impact.
- `GET` / `POST` `/api/v1/admin/pilots` — view or create a pilot proposal. New pilots are explicitly marked `PROPOSED_ONLY`.

Official source/application URLs are HTTPS-only and restricted to the allow-list in `backend/api/common.py`. Extend that allow-list only after source-domain review. Scheme payloads include `application_process`, `document_items`, `document_review_note`, `documents_review_complete`, `eligibility_rules`, `ruleset_complete`, `source_review_complete`, and `source_capture_level`. The capture level records whether evidence was a direct detail page, index, search result, older guideline or failed fetch; it is not human verification. Keep completeness attestations false when material conditions are unknown; the farmer-facing engine then returns `INSUFFICIENT_INFORMATION` instead of inferring a result. These governance fields are stored in versioned scheme data; they do not add profile fields or require a database schema migration.

## Error format

Errors generally use a stable envelope:

```json
{"error":{"code":"VALIDATION_ERROR","message":"Please check the submitted fields.","fields":[{"field":"email","message":"..."}]}}
```

Relevant HTTP responses include `401` unauthenticated, `403` forbidden/CSRF failure, `404` not found, `409` conflict, `422` field validation, `429` rate limit, and `503` database/rate-limit service unavailable. Never expose stack traces or database details to a client.
