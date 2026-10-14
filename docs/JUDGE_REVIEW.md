# Honest product and readiness review

## Product case

- Focused farmer problem: turning a farm profile into a few explainable scheme pathways, a checklist of what to confirm, and an official next step.
- Intended journey: sign in/demo → complete farm profile → see deterministic profile-fit results → open source-backed conditions → prepare a self-reported checklist → continue to MahaDBT → optionally record personal progress.
- Guardrails: no fabricated submission, approval, department partnership, live application status, or impact claim. Unknown eligibility information stays unknown.
- The local demo does not require external APIs, scraping, or an AI provider.

## Readiness today

The in-progress product includes FastAPI/SQLAlchemy, browser-cookie and mobile bearer authentication, role checks, revocable server-side sessions, CSRF controls, Redis rate-limit configuration, Alembic migrations, a versioned source/document review and publish workflow, audit logs, and a local Postgres/Redis Compose stack. The current-version editor cannot verify their own version; the verifier and publisher must also be different accounts. Local checks report 26 backend tests passing, plus JavaScript syntax and Python compile checks. SQLite migration validation previously passed but was not rerun for this catalog/UI-only update.

**This is still not a production-ready or field-validated service.** PostgreSQL/Redis/Docker and the Flutter release build were not executed in this workspace; there is no browser E2E or independent security/privacy review. Hosting, account recovery/MFA, account-export and backup-retention operations, verified scheme content, field evidence, and accessibility/load testing remain open. A password-confirmed account-deletion flow is implemented, but its production operations and backup-retention handling still need review.

## Product risks and questions

- **Problem validation:** no real farmer interview, baseline, or task-time evidence has been supplied. The synthetic Niphad profile is not research evidence.
- **Catalog scope:** 40 official-source candidate records are present for the intended Maharashtra scope, with capture dates recorded on 2026-10-08. Evidence quality varies from direct detail-page/PDF capture to official search-result-only or older-guideline leads; seven records have no established current application route. No seeded record is independently verified or published, every ruleset remains unattested, and this is not a complete or continuously updated catalog. See `docs/DATA_VERIFICATION.md`.
- **Government authority:** relevant official state/central government sources are authoritative. There is no live API, official approval, or department partnership.
- **Rules and language:** match weights are relevance heuristics; rule explanations and Marathi/Hindi scheme text need subject-matter and professional language review.
- **Accessibility/digital inclusion:** test with farmers with different literacy, disability, device, network, and assisted-service needs.
- **Privacy/security:** never collect Aadhaar numbers, bank details, or actual document files until lawful basis, consent, storage, access, deletion, and breach processes are approved.
- **Sustainability:** unit cost, support model, update staffing, and a pilot owner are unknown.

## Questions to answer with evidence

1. What field evidence proves the problem is frequent and costly in the target taluka?
2. Why is this clearer or more useful than MahaDBT/myScheme's existing search journey?
3. Which part improves user outcomes: understanding, document readiness, assisted onboarding, or task completion?
4. Who has agreed to review scheme data or test the tool? No such partnership is currently claimed.
5. Who checks source changes, and what is the correction/withdrawal SLA?
6. How does someone without a smartphone, data plan, or written Marathi use the service?
7. How will the team measure completion/comprehension without confusing clicks with benefits?
8. What is the cost per assisted user and who funds ongoing scheme-data maintenance?

## Evidence not to fabricate

- `[INSERT ACTUAL SURVEY RESULT]` problem frequency and current farmer journey.
- `[INSERT ACTUAL BASELINE]` task time, relevant schemes known, documents identified, next-step confidence.
- `[INSERT ACTUAL USABILITY RESULT]` completion, comprehension, relevance, and accessibility findings.
- `[INSERT ACTUAL PILOT RESULT]` outcomes collected with consent and an explicit denominator/method.
- `[INSERT VERIFIED SOURCE AND REVIEWER]` current rules, component windows, and human sign-off.
- `[INSERT ACTUAL COST]` support, translation, hosting, outreach, and maintenance costs.

## Next recommended work

1. Interview farmers and local agriculture facilitators; document consent, recruitment, current search path, confusion, and task time.
2. Have a Maharashtra scheme-domain reviewer validate each captured official page, translation, condition, benefit summary, and next step.
3. Observe usability in Marathi and test comprehension of “profile match ≠ eligibility/approval”.
4. Define a small proposed pilot with named owner, sampling plan, accessible alternatives, baseline/post-use method, support, cost, and success criteria.
5. Complete browser E2E, PostgreSQL/Redis, Docker, accessibility, security, privacy, deployment/restore, and load tests before real onboarding.
