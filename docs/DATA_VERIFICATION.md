# Scheme catalog source capture and verification

## Current catalog state — review queue, not production data

`backend/data/schemes.json` contains **40 candidate records** for Maharashtra farmers:

- 17 MahaDBT/Maharashtra scheme entries, including a separate MahaDBT record for Dr. Babasaheb Ambedkar Krushi Swavalamban Yojana;
- one Namo Shetkari state-portal lead;
- two Maharashtra SFAC/FPC business-finance scheme leads documented on the Maharashtra Agriculture Department page; and
- 20 central or central/state programmes intended to be checked for Maharashtra applicability, including NLM livestock components, PM-MKSSY fisheries components, RGM farmer interventions and the SFAC FPC equity-grant lead recorded from the State page.

The catalog is not exhaustive and none of these candidates is presented as government-verified. The source-check date on all 40 rows is `2026-10-08`; this records the research/capture date only. It is not a statement that a scheme is open, that a government page remains current, or that an independent reviewer approved the facts.

All 40 rows have `source_review_complete=false`, `documents_review_complete=false` and `ruleset_complete=false`. No candidate is to be published from this capture alone. `seed.py` creates new records as `UNDER_REVIEW` / `NEEDS_REVIEW`; farmer-facing APIs serve only records marked both `PUBLISHED` and `VERIFIED`.

Current seed-file completeness:

- **40/40** have an HTTPS source URL and source name; **40/40** have a capture date.
- **33** have an official source or scheme-information URL in `application_url`; **7** have it blank because no current application route was established or the source is an older guideline only. A portal/info link is not evidence that applications are open.
- **7** have structured document items; their lists are partial/component-specific and none has passed document review. Every row also has a farmer-facing document note so an empty checklist is not treated as “no documents required.”
- One row contains five deterministic rule objects, but its rule set is not attested complete. All 40 `ruleset_complete` flags remain false; **no row can produce a reliable positive eligibility match yet**.

The seed-file counts do not describe a pilot, program impact, approval rate or verified scheme coverage. Do not call the catalog “complete,” “government-approved,” or “verified” in farmer-facing copy.

## Source capture ledger — checked 8 October 2026

Capture levels are recorded in `source_capture_level` and are retained by the admin editor. They distinguish direct page/PDF review, index-only evidence, search-result-only evidence, old guideline periods and failed fetches from the separate human-review attestation.

| Record/group | Evidence captured | Exact limits that must remain visible |
|---|---|---|
| PMKSY micro-irrigation, MIDH and State Agriculture Mechanization | Direct MahaDBT detail-page capture | Benefit schedules/components and current availability still need a human check. The State mechanization and SMAM pages use substantially matching equipment/repeat-benefit wording; do not double-count or publish both until a reviewer compares the current Government Resolutions and confirms they are distinct. The common MahaDBT “will reopen soon” notice does not mean applications are open. |
| SMAM, NFSNM, Birsa Munda, Jan-Van Vikas, PM-RKVY RAD, Gopinath Munde, Dr. Babasaheb Ambedkar | Direct MahaDBT detail-page captures | Source-page facts were transcribed into the candidate summaries/benefit notes and component-specific document caveats. Use only the captured component/period; confirm current Government Resolution, district coverage, benefit schedule and documents. RAD facts are explicitly for 2025–26; the general NFSM page includes historical terms; Birsa/Dr. Babasaheb/Jan-Van rates and availability remain current-GR/village-list questions. Page-captured amounts are not guarantees. |
| Seven other MahaDBT entries (RAD umbrella, Bhausaheb Fundkar, RKVY-RAFTAAR, CM irrigation/farm pond, RKVY plastic lining, cashew grafts) | Official listing/detail-page attempts, but no usable current terms in the captured page | The scheme name or index listing does not establish benefit, eligibility, documents, current activity or an application window. These rows deliberately retain unknowns. |
| PM-KISAN | Direct capture of `https://pmkisan.gov.in/` | Portal states ₹6,000 per eligible farmer family per year in three instalments and mandatory e-KYC for registered farmers. State verification and exclusion checks apply. Scheme Mitra does not collect Aadhaar or bank credentials. |
| PMFBY | Official portal plus PIB search-result evidence | A 2026 PIB result describes Kharif 2026 national participation and premium caps, but direct fetch failed and the current Maharashtra crop/area/insurer/deadline notification was not captured. Seasonal applicability must be checked. |
| Kisan Credit Card | Direct RBI KCC Directions capture at `https://www.rbi.org.in/Scripts/NotificationUser.aspx?Id=13522&Mode=0` | The RBI 2026 Directions apply to loans sanctioned from **1 January 2027**. Do not apply them to earlier loans; the lending bank sets underwriting and current documentation. |
| PM-KMY | Official MAANDHAN search-result evidence | Direct page fetch returned HTTP 500. Indexed terms are recorded as leads only; re-open the official page and confirm current enrollment before verification. |
| PM-KUSUM | Official MNRE page/search-result evidence | Source states the original period ended **31 March 2026**. Notices for already-sanctioned projects do not prove fresh farmer enrollment is open. |
| Agriculture Infrastructure Fund | Official portal FAQ search-result evidence | Direct FAQ fetch failed. Project eligibility, lender route and acceptance of new proposals in 2026-27 need direct confirmation. |
| Namo Shetkari | Maharashtra Agriculture Department homepage and failed dedicated portal fetch | The dedicated portal returned HTTP 500. Dynamic counters were zero and are not treated as participation/payment/impact data. Benefit, eligibility and route remain unknown. |
| NMEO–Oilseeds, Pulses Mission and PM-DDKY | Official PIB release/search-result evidence | Direct fetch of the relevant 2026 PIB releases failed. Maharashtra cluster/focus-district and approved local plan details are not confirmed; national press releases do not establish individual eligibility. |
| 10,000 FPO scheme | Direct SFAC FPO page and partial review of its linked operational guideline | SFAC’s state-wise list is dated **24 February 2025**; the 2020 guideline includes member thresholds and separate finance provisions, while current addenda/cohort availability and complete financial terms still need review. FPO support is organization-level, not a per-farmer cash grant. |
| Maharashtra FPC credit guarantee and agri-industry capital loan | Direct Maharashtra Agriculture Department/SFAC page capture | Source page is undated. The credit guarantee is lender risk cover; the separate capital assistance is repayable and becomes a term loan. Current availability is unconfirmed. Do not conflate the two. |
| SFAC FPC equity grant (Maharashtra page) | Direct capture of the same undated State SFAC page | Page describes matching equity support capped at ₹10 lakh per FPC with company/shareholder and governance criteria. It is not an individual farmer payment, is distinct from the 10,000 FPO scheme, and current availability/terms are unconfirmed. |
| NMNF and PKVY | Direct Maharashtra official guideline-index capture | NMNF document located is for 2024-25; PKVY/group guidance located is for 2022-23/2023-24. These older documents do not establish a current 2026-27 call. |
| Maharashtra NFSNM seed component | Direct state guideline PDF, dated **13 May 2026**: [Kharif 2026 guideline](https://krishi.maharashtra.gov.in/Site/Upload/Pdf/kharip%202026%20guidelines.pdf) | FY 2026-27 seed-producer terms (including rate-capped assistance and SATHI/NSC steps) apply only to qualifying seed-production components. They are not a general seed-purchase subsidy or a benefit for every farmer/NFSNM component. Crop, variety, district and allocation must match the annexure. |
| NLM rural poultry, sheep/goat and piggery entrepreneurship | Official DAHD scheme-page reference plus direct review of the January 2025 operational-guideline PDF hosted on DAHD | Component unit sizes and capital-subsidy ceilings are transcribed; eligibility includes training/experience, land/lease or group rules, KYC, lender appraisal/loan or self-finance bank guarantee, project viability and State/DAHD approval. Current Maharashtra EOI/allocations and document formats need confirmation. The DAHD-linked NLM portal returned HTTP 500 on direct fetch; recheck it before use. |
| NLM feed and fodder entrepreneurship | Official DAHD programme-page search/listing lead plus direct NLM guideline PDF fetch; detailed component cost norms not transcribed | The page/listing evidence names fodder-seed, silage, hay-baling and fodder-block activity; retain this as a lead pending direct activity-specific guideline review. No rate/unit ceiling is asserted; verify the full activity-specific guideline and Maharashtra call. |
| PM-MKSSY aquaculture insurance incentive | Direct NFDP insurance-component page and Department of Fisheries guideline capture | NFDP states one-time, one-crop-cycle incentive rates and area/volume ceilings; verify current insurer product, allocation and offline-document requirements. Registration on NFDP is mandatory; Scheme Mitra does not collect identity, bank, policy or claim files. |
| PM-MKSSY fisheries performance grants | Direct NFDP component page, direct Department ESMF and direct 2024 PIB Cabinet release | 2024 Cabinet ceilings are recorded only as historical approval terms. NFDP links a V2.0 operational-guideline PDF that returned HTTP 500 on direct fetch; a human reviewer must compare current component caps/criteria before publication. Grants are investment/performance-based, not upfront or a general farmer payment. |
| Rashtriya Gokul Mission farmer interventions | Direct DAHD administrative approval for 2026-27 | The captured approval ran only through **30 September 2026** or the next 16th Finance Commission approval, whichever came first. It lists sex-sorted semen assistance and 3% interest subvention for specified heifer loans; after the 2026-09-30 boundary, current approval, intake and Maharashtra process are unknown. |

### MahaDBT portal-status wording

The shared MahaDBT page displayed a Marathi notice captured 8 October 2026 that the portal would “soon reopen” and that applications from 2025-26 use first-come-first-served processing. This is a portal notice, not proof that applications were open on the capture date. Each scheme/component still requires its own current allocation, eligibility, document and application-route check.

### Other source leads recorded for review

- **Pulses mission:** Cabinet source `https://www.pib.gov.in/PressReleasePage.aspx?PRID=2173547&reg=3&lang=2`; 2026 focus-district release `https://www.pib.gov.in/PressReleasePage.aspx?PRID=2241411&reg=3&lang=1` (direct fetch failed).
- **PM-DDKY:** Cabinet approval `https://www.pib.gov.in/PressReleasePage.aspx?PRID=2145147`; 2026 district-plan source `https://www.pib.gov.in/PressReleasePage.aspx?PRID=2244624&reg=3&lang=2` (direct fetch failed).
- **NMEO–Oilseeds:** 2026 PIB release `https://www.pib.gov.in/PressReleasePage.aspx?PRID=2296205&reg=48&lang=1` (direct fetch failed); official backgrounder `https://www.pib.gov.in/PressNoteDetails.aspx?NoteId=156376&ModuleId=3&reg=3&lang=2`.
- **SFAC 10,000 FPO:** official scheme page `https://sfacindia.com/FPOS.aspx`; linked 2020 operational guideline `https://sfacindia.com/UploadFile/Statistics/Formation%20&%20Promotion%20of%2010,000%20FPOs%20Scheme%20Operational%20Guidelines%20in%20English.pdf`.
- **Maharashtra PKVY/NMNF guideline index:** `https://krishi.maharashtra.gov.in/Site/Information/GuideLinesInformation.aspx?ID=6`.
- **Maharashtra SFAC page:** `https://krishi.maharashtra.gov.in/1148/%E0%A4%AF%E0%A5%8B%E0%A4%9C%E0%A4%A8%E0%A4%BE` (undated; current availability not confirmed).

Official search snippets are retained as **search-result evidence only**. They must be opened and checked directly before a human verifier signs off. If a page is unavailable, use a clearly marked official document or leave the claim unknown—never substitute a third-party summary or guess an application URL.

## Admin review and publication workflow

1. An editor adds or updates the record in `/admin.html`. Every edit creates a new version and returns it to the review queue. The editor records source name/URL, source date, evidence capture level, summary, benefit note, application steps, source facts, document items, document-review note and deterministic eligibility rules. Unknowns must be explicit.
2. The editor's source-review and document-review attestations must reflect an actual check of the current official source. Editing resets the attestations so they must be made again for the new version.
3. The `ruleset_complete` attestation may be checked only when all relevant official eligibility conditions for that record version are captured. If material criteria are unknown or the rule set is incomplete, leave it unchecked; the deterministic engine reports `INSUFFICIENT_INFORMATION` rather than guessing.
4. A verifier other than the last editor reviews the new version against its official source. Verification is blocked unless required record fields, a current official application or scheme-information route, source/document review notes and safe deterministic-rule structure are present. An empty document checklist must not be treated as proof that no documents are required; the farmer-facing note must explain known facts and gaps.
5. A separate administrator account publishes the verified version. The publisher must differ from the verifier. Every change, verification, publication and archive action is audited.
6. Only then is the record visible through farmer-facing APIs. Eligibility remains preliminary guidance; the relevant authority makes the final decision.

Eligibility rules are data, not executable code. They use allow-listed comparison operators, explicit profile fields, a human-readable source fact and an HTTPS source URL. Missing profile values stay unknown. AI or assistant text cannot change a rule result.

## Safe eligibility and farmer language

The deterministic engine distinguishes:

- **Likely Eligible** — all explicitly modeled, source-backed criteria match, the rule set is attested complete, and the record is verified and published.
- **Potentially Eligible — verification required** — eligibility comparisons match but a secondary review/document item remains.
- **Not Eligible based on available information** — an explicit, source-backed eligibility failure is present on a verified and published record. It is not an authority's decision.
- **Insufficient Information** — the source/rule set is not verified and published, rule coverage is incomplete, or a material profile value is unknown.

Every result explains the reason and states that only the relevant authority decides eligibility and approval. A profile-match score is a relevance signal, not an eligibility or approval probability.

## Source and privacy policy

- Government sources are authoritative. Never invent scheme names, benefits, eligibility conditions, documents, deadlines, source dates, application URLs, department ownership, partnerships or outcomes.
- No live scraping, automatic application submission, OTP/payment dependency, Aadhaar/DigiLocker integration or document upload is used in the demo.
- Document availability in a farmer profile is self-reported only. Do not collect identity numbers or unnecessary sensitive information.
- The local assistant uses only published catalog data and linked sources. It can state that a fact is not available; it does not determine eligibility.
- The demo works without external APIs or an AI provider. Seed data is clearly not a government endorsement.

Before real farmer exposure, a named Maharashtra agriculture-domain reviewer must check scheme applicability, exact component conditions, benefit schedule, geography, documents and timing, application route, translation quality and changes in current Government Resolutions. Record the reviewer, timestamp, source/version snapshot and reason for every correction. Keep candidates unpublished until that work is complete.
