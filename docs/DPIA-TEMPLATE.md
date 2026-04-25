# Data Protection Impact Assessment — Nexdoz

> Required under GDPR Art. 35 when processing special-category data (Art. 9) on a large scale. To be filled in BEFORE first real patient uses the service.

_Date: PLACEHOLDER_
_DPO: PLACEHOLDER_
_Document owner: PLACEHOLDER_
_Review cadence: annual + on material change_

## 1. Description of processing

### 1.1 Nature, scope, context, purpose

- **Nature** (what we do to the data): collect, store, display, aggregate, optionally transmit to AI processors on opt-in
- **Scope** (volume + duration): expected PLACEHOLDER users in year 1, retention per PRIVACY-DRAFT.md §5
- **Context** (who, where, why): EU residents self-reporting diabetes care data; controller = PLACEHOLDER
- **Purpose**: personal health tracking + optional clinician summary + optional AI-powered insights

### 1.2 Data categories and flows

List every data category, its source, where it lives, who it flows to.

| Category | Source | Storage location | Flows to |
|---|---|---|---|
| Glucose readings | User entry / device sync | Postgres (EU droplet) | displayed to user; optional clinician export |
| ... | ... | ... | ... |

### 1.3 Technology used

- Go backend (nexdoz-user-api v0.X)
- Next.js web client (nexdoz-web v0.X)
- Expo mobile client (nexdoz-mobile v0.X)
- Postgres 16
- DigitalOcean droplets, Frankfurt region
- Optional: OpenAI / Google Gemini / Anthropic Claude for AI features

## 2. Necessity and proportionality

- **Lawful basis**: Art. 9(2)(a) — explicit consent. Consent UI described in PLACEHOLDER_SECTION of the privacy policy.
- **Data minimization**: list specific fields we collect and why each is needed for the stated purpose.
- **Accuracy**: users can edit all self-reported data at any time.
- **Storage limitation**: retention schedule in PRIVACY-DRAFT.md §5.
- **Lawfulness of transfers**: AI processing is opt-in and disclosed; transfers to US rely on SCCs + adequacy decisions where available.

## 3. Risks to individuals

For each risk, score likelihood (1–5) × impact (1–5), document mitigations.

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Unauthorized access to health data (credential stuffing) | ? | ? | Rate limit on auth; 2FA optional; bcrypt cost 12; CSRF |
| Data breach via compromised DO droplet | ? | ? | UFW, fail2ban, SSH key-only, encrypted backups, 72h notification playbook |
| Accidental PII in logs | ? | ? | Structured logging with explicit allowlist; PII scrub at source |
| Reidentification of "anonymized" AI requests | ? | ? | Never send direct identifiers to AI processors; keep meal descriptions generic |
| Regulator classifies app as Class IIa medical device | HIGH | HIGH | See docs/MDR-SCOPE-DECISION.md — must resolve before launch |
| Third-party processor (DO) breach | LOW | HIGH | DO's own security + DPA + breach-notification obligations flowed to us |

## 4. Measures and safeguards

- **Technical**: TLS 1.2+, encryption at rest for backups, secrets-in-env, least-privilege service accounts
- **Organizational**: DPO designated, breach playbook, staff access controls
- **Contractual**: signed DPA with each processor (DO, Better Stack, AI vendors)

## 5. Consultation

- Consulted with: PLACEHOLDER_LEGAL_COUNSEL, PLACEHOLDER_DPO, PLACEHOLDER_CLINICAL_ADVISOR
- Consulted DPAs: PLACEHOLDER_SUPERVISORY_AUTHORITY? (required if residual risk is high)

## 6. Outcome

- [ ] Risks acceptable — proceed
- [ ] Additional safeguards required — list + timeline
- [ ] Cannot proceed without supervisory authority consultation (Art. 36)

Signatures:
- DPO: ________________________ date: ________
- Controller representative: ________________________ date: ________
