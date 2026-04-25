# EU MDR scope decision — REQUIRES FOUNDER SIGNOFF BEFORE BETA

> **This is the single biggest unresolved blocker for anything beyond internal-test deployment.** No real EU patient should see the app until this is decided and documented.

## The question

Under **EU Regulation 2017/745 (Medical Device Regulation, MDR)**, software that provides information used for diagnosis, monitoring, prediction, prognosis, or treatment decisions about a physiological condition is a **medical device**. For a chronic condition (diabetes) with treatment implications, the typical classification is **Class IIa or higher** under MDR Rule 11.

**Decision required:** is Nexdoz going to be marketed as:

### Option A — "Lifestyle / wellness diary" (NOT a medical device)

Nexdoz is a personal journal where users log what they eat, what their meter shows, how they feel. It displays their own data back to them. It does NOT:
- recommend insulin doses
- predict A1C
- suggest carbohydrate adjustments
- auto-generate a clinician-ready summary
- interpret meter readings (e.g. "your glucose is too high, take action")

Under this framing, the app is **not** a medical device. It's a consumer wellness product. No CE mark needed. Launch path: straightforward.

**Trade-off:** you lose every feature that actually differentiates Nexdoz from a spreadsheet. "Meal AI", "meal scan", "clinician summary", "action plans", "recommendations" — all of those trip Rule 11 and force Option B.

### Option B — Class IIa medical device (CE mark required)

Nexdoz provides information that influences treatment decisions. Any of the following crosses the line:
- AI-generated meal recommendations tied to glucose patterns
- Insulin-dose hints
- "Your A1C will likely be X if trends continue" predictions
- "Clinician summary" that aggregates + interprets data with implied clinical relevance
- Auto-suggested action plans

Requirements before launch under this path:
1. **ISO 13485 Quality Management System** — formal documentation, change control, risk management, CAPA
2. **Technical file** — intended purpose, clinical evaluation, risk analysis (ISO 14971), software lifecycle (IEC 62304)
3. **Clinical evaluation** — literature review + (possibly) real-world evidence
4. **Notified Body audit** — for Class IIa, an independent auditor reviews the QMS + technical file and issues the CE certificate. List at <https://ec.europa.eu/growth/tools-databases/nando>
5. **UDI registration** in EUDAMED
6. **Post-market surveillance plan** — ongoing monitoring and periodic safety update reports
7. **Person Responsible for Regulatory Compliance** (PRRC) — Art. 15
8. **Product liability insurance**

**Budget estimate** (ballpark, varies wildly):
- Notified Body audit + certificate: €15,000–€50,000 one-time
- QMS consulting (for a first-time applicant): €20,000–€100,000
- Clinical evaluation: €10,000–€30,000
- PRRC (external contractor if no in-house): €1,000–€3,000/month
- Post-market surveillance ongoing: €5,000–€20,000/year
- **Total pre-launch: €50,000–€200,000**
- **Timeline: 6–18 months** from engaging a notified body to CE mark issued

## Current codebase signal

Claude's review of the user-api vendored FE `api-client` exports suggests the team is building toward Option B:
- `ActionPlan` + `CreateActionPlanRequest` / `UpdateActionPlanRequest` — action plans
- `Recommendation` — recommendations
- `HealthMetrics` — aggregated metrics
- `getClinicianSummary()` — clinician summary endpoint
- Web routes for `/patient/meal-ai`, `/care-plans`

Every one of these endpoints is a Rule 11 trigger. **If kept as-is and deployed to real EU patients without CE mark, this is non-compliant** and exposes the controller to fines (up to €20M or 4% of global turnover, whichever is higher) + product liability.

## Paths forward

### Path 1 — Descope to Option A for launch, re-scope later

Remove (or hide behind a feature flag defaulted to off) every clinical-decision-support feature. Launch as a lifestyle diary. Start the MDR process in parallel for when you want to re-enable the clinical features in v1.0 or v2.0.

Pros: fast to launch, cheap, tests the broader product hypothesis with real users
Cons: you're selling a diary, not the product you designed

### Path 2 — Commit to Option B, delay launch 6–18 months

Pause new feature work. Engage a notified body. Build the QMS. Do the clinical eval. Get the CE mark. Then launch.

Pros: the product you actually want to ship
Cons: significant capital + time; may be out of reach for a pre-revenue solo team

### Path 3 — Hybrid: Option A for EU, Option B for specific markets later

Launch in a non-EU market first (e.g. UK post-Brexit, US under FDA regulations which are different) as a diary, get traction + revenue, then CE-mark for EU.

Pros: unblocks launch in some geography
Cons: complex market strategy; US FDA rules are not simpler than EU MDR

## Decision

**Selected path:** ☐ 1 ☐ 2 ☐ 3 ☐ Other (specify)

**Rationale:** _fill in_

**Responsible parties:**
- Product / scope: _name_
- Regulatory consultant: _name_
- PRRC if Option B: _name_

**Effective date:** _date_

**Review date:** _date_

**Signatures:**
- Founder: ________________________ date: ________
- Legal counsel: ________________________ date: ________
