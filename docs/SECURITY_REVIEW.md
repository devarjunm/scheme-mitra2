# Security review — implementation notes and open work

**Status: internal implementation review only. Not a penetration test, legal opinion, or production approval.** The code has basic controls, but the absence of an independent review and deployment evidence means Scheme Mitra must not be described as production-certified.

## Implemented in this repository

- Password hashes use Argon2id through `argon2-cffi`; plaintext passwords are not stored.
- Browser access uses a signed JWT in an HttpOnly cookie; no browser token is stored in local storage. Flutter uses a separate mobile-audience bearer token in secure device storage. Session `jti` values are stored in `auth_sessions`; logout revokes the database session, which is checked on authenticated requests.
- Authenticated unsafe API requests require a double-submit CSRF token; login, registration, and demo bootstrap are unauthenticated bootstrap actions.
- Registration enforces a 12-character minimum plus alphabetic/numeric characters. Login responses do not disclose whether an email exists.
- Role checks are enforced in API dependencies. Farmer accounts cannot access admin endpoints; the current-version editor cannot verify their own version, and publication is a separate action by an account different from the verifier.
- Production configuration fails closed without a non-development JWT secret, PostgreSQL URL, secure cookies, Redis rate-limit URL, explicit trusted hosts, and non-wildcard trusted proxy settings.
- Production rate limiting uses Redis counters. Local in-process limiting is development-only.
- Request IDs are sanitized; errors are returned in generic envelopes; API responses do not expose exception traces. Common security headers and a restrictive CSP are set.
- Source URLs are HTTPS and checked against an allow-list; admin audit/version data stores workflow actions.
- Analytics is allow-listed and metadata is minimized. No Aadhaar number, bank data, uploaded files, or official application status is requested or stored by design.

## Important limitations and required controls

1. **No external test.** No penetration test, threat-model workshop, load/soak test, dependency audit, or independent code review has been completed.
2. **Account assurance.** There is no email verification, account recovery/password reset, MFA, or privileged identity provider. Admin credentials are bootstrapped from environment variables; use a secrets manager and remove the bootstrap secret after first use. Enforce MFA at an approved identity layer before privileged use.
3. **Privacy operations.** Email and farmer profile data are personal data. Password-confirmed account deletion is implemented and tested in the app/backend, with an external web route, but export, in-product consent ledger, retention-policy enforcement, backup-deletion operations, and automated expired-session cleanup are not complete. Exercise the deletion flow and align it with backup retention and applicable-law review before onboarding real farmers.
4. **Transport/deployment.** HTTPS termination, trusted proxy addresses, forwarded-header replacement, TLS to managed PostgreSQL/Redis, network ACLs, WAF, backups, restore drills, and secret rotation depend on infrastructure not supplied here. `docker-compose.yml` is development only.
5. **Sessions.** Signed JWT expiry is bounded; logout revokes the session. Stolen active cookies remain usable until logout/expiry. Add incident-driven global session revocation and periodic expiry cleanup before long-lived production use. User deactivation is checked on each request.
6. **Rate limiting.** Limits are simple per-IP/path minute counters, not adaptive abuse detection. Verify client-IP behavior behind the actual reverse proxy and add monitoring/alerts. Do not set `FORWARDED_ALLOW_IPS=*`.
7. **Data governance.** The admin workflow requires current-source and document-review attestations, a different verifier from the current-version editor, and a different publisher from the verifier; actions are audited. This is an application control, not government approval or proof that rules remain current. No seeded scheme has been independently verified for production. A named agriculture-domain owner must review the actual official sources and corrections before any real farmer-facing publication.
8. **Frontend.** API authorization is authoritative; the admin page's hidden/visible controls are not security controls. Continue escaping dynamic content and reviewing any new HTML sinks.
9. **Data sensitivity.** Structured Aadhaar/bank fields and file uploads are not implemented, but free-text notes/comments could still contain sensitive details; the UI warning is not a DLP control. Never submit real Aadhaar/bank information or upload real documents. If those data are ever needed, redesign storage, encryption, access, consent, retention, breach response, and deletion first.

## Deployment gates

Before production use, attach evidence for: configured secret manager, isolated production network, HTTPS and proxy validation, PostgreSQL/Redis TLS/auth, migration and restore tests, CSRF/session and role tests against the deployed origin, rate-limit tests, scan results, external penetration test, privacy assessment, accessibility review, alerting/incident runbook, and named ownership for the official scheme catalog.
