# ManoFit — AI-Powered Personnel Stress & Welfare Monitoring System
### PRD: CAPF/Armed Forces Welfare Platform
**Tech Stack (locked):** Flutter (iOS + Android) + Supabase (Postgres, Auth, Storage, Edge Functions, Realtime)

> **🔒 AGENT DIRECTIVE — READ BEFORE DOING ANYTHING**
> - **This is ManoFit, a fresh build. The earlier "Mindspace" product is cancelled — do not reference it, its repo, its screenshots, its screen layouts, or its naming for anything.** Every screen here is designed fresh per `manofit-stitch-ui-prompt.md`.
> - **Stack is Flutter + Supabase. Nothing else.** Do not scaffold Node.js, React, Kotlin/native-Android, or any other stack.
> - **Companion files, always keep in context together:** `manofit-stitch-ui-prompt.md` (UI design brief — minimalist, distinctive typography, not generic) and `manofit-architecture.md` (system architecture + environment/`.env` setup).
> - **Never hand-build a screen without first generating its design** per the Stitch file. If a screen isn't designed yet, design it first — don't improvise UI.
> - **Work phase-by-phase (3 phases, §9).** Do not start Phase 2 until Phase 1's usable outcome is verified. Do not start Phase 3 until Phase 2 is verified.
> - **Priority order per the PS is: ML/Analytics engine → HR Admin/ingestion → Assessments → everything else.** Self-help extras (doodle, breathing, booking, wearables) are real features but explicitly lowest priority.

---

### Ready-to-paste prompt for Antigravity (use this to kick off a session)

```
You are building ManoFit, a personnel stress & welfare monitoring platform,
strictly in Flutter (iOS + Android) + Supabase. Do not use any other stack —
no Node.js backend, no Kotlin/native Android, no React. This is a fresh
build; ignore any earlier "Mindspace" product, repo, or screens entirely —
they are cancelled and not a reference for anything.

Read these three files fully before writing any code, and keep re-reading
them as you work — they are the source of truth, not your own assumptions:
  1. manofit-prd.md            (requirements, priorities, 3-phase plan)
  2. manofit-architecture.md   (system architecture, data flows, .env setup)
  3. manofit-stitch-ui-prompt.md (UI design brief — minimalist, distinctive
     typography, not generic — and how to generate each screen)

Rules:
- Work through the 3 phases in manofit-prd.md §9, in order. Do not start a
  phase until the previous phase's "usable outcome" is genuinely working.
- Priority within and across phases follows the PRD exactly: the ML/analytics
  engine, HR Admin/ingestion, and Assessments come first — self-help extras
  (doodle, booking, wearables) come last, in Phase 3.
- Never hand-design a UI screen. Generate it per manofit-stitch-ui-prompt.md
  first — minimalist (one primary action, minimal text/badges per screen)
  and with deliberate, distinctive typography, not a default/system-font
  generic look.
- Use the environment/config setup exactly as specified in
  manofit-architecture.md §9 — real secrets go in Supabase, never in the
  Flutter client bundle.
- Before moving to the next phase, summarize what was built, confirm it
  matches this PRD's "usable outcome" for that phase, and flag any deviation
  before proceeding.

Start with Phase 1.
```

---

## 1. Scope

ManoFit is built from scratch against the government problem statement below — there is no legacy app to reference; every screen and flow here is a fresh design.

| PS Requirement | Priority |
|---|---|
| Predictive Behavioral Analytics Engine / Stress & Burnout Risk Models | **Highest — Phase 1** |
| HR data ingestion (leave, deployment, transfers, duty load) + HR Admin | **Highest — Phase 1** |
| Assessments / wellness survey data collection | **Highest — Phase 1** (it's a direct ML input) |
| Privacy / RBAC / anonymization framework | **Highest — Phase 1** (prerequisite for the above) |
| Welfare Intervention Recommendation System + Automated Alerts | High — Phase 2 |
| Commander/Welfare Officer Dashboards | High — Phase 2 |
| AI voice companion + Tele-MANAS auto-escalation | High — Phase 2 |
| Self-help activities (doodle, breathing, booking), wearables | Lowest — Phase 3 |

**PS background**: personnel in CAPFs, Armed Forces, and other uniformed services operate under physically demanding, psychologically stressful conditions. Extended deployments, irregular hours, and exposure to traumatic incidents affect mental well-being, and manual/self-reported stress identification delays intervention. ManoFit is a proactive, privacy-first, AI-driven welfare monitoring system addressing this.

---

## 2. HR Data Collection — How HR Actually Uploads Data

Tiered so no single point of failure blocks rollout:

### Tier 1 — Direct System Integration (preferred, large-scale)
- Secure REST API / SFTP connector to existing HRMS. Nightly batch sync of structured fields only: leave taken/balance, deployment dates, duty roster hours, transfer history, training load.
- Field-level allow-list configured at the connector so only PS-relevant columns are ever pulled — no medical, disciplinary, or next-of-kin data.

### Tier 2 — Bulk Upload Portal (CSV / XLSX, for units without API-ready HRMS)
- HR Admin uploads a standardized `.csv` or `.xlsx` template via a scoped, short-lived signed upload URL to Supabase Storage.
- A Supabase Edge Function (Deno/TypeScript) picks it up: format detection → parse (`csv-parse` for `.csv`, `SheetJS`/`xlsx` for `.xlsx`) → schema validation → duplicate-row detection → pseudonymization (Service/PF number → rotating token) before it touches the analytics engine → audit-logged ingestion → raw file deleted from Storage once committed.
- Rejected rows are returned to HR Admin with the specific error and a downloadable "rejected rows" file to fix and re-upload.

### Tier 3 — Manual Entry (small units, fallback only)
- Constrained form (dropdowns/date-pickers, not free text), rate-limited, fully audit-logged.

### Cross-cutting controls
- Pseudonymization at the point of entry; re-identification only via the isolated identity-mapping vault (see architecture doc), two-person authorized.
- Mandatory HR-record fields (leave, deployment) ingest under organizational policy; optional fields that double as personal wellness inputs ingest only with individual opt-in.
- Versioned HRMS field mappings so one unit's schema change doesn't break ingestion elsewhere.

---

## 3. Solving the Key Technical Challenges (Priority Order)

### 3.1 Privacy & confidentiality
- Encryption in transit (TLS 1.3) and at rest (AES-256). Pseudonymization at ingestion + isolated identity-mapping vault with two-person-authorized re-identification and full audit trail. The ML layer only ever sees derived features, never raw HR records or free-text journal content. Differential privacy noise on aggregate/unit-level views.

### 3.2 Preventing stigmatization
- Commanders see **only aggregate, unit-level trends** — never individual scores. Only Welfare Officers see individual-level flags, and only after human clinical review, never a raw model score.
- Flags are framed as "may benefit from a wellness check-in," never as disciplinary or fitness-for-duty input, and the platform has **no API connection** to any disciplinary/performance system.
- **Personnel do not see their own organizational risk score or flag status** — exposing it would let someone learn what triggers it and adjust self-reports to avoid detection, undermining the model. Transparency instead lives at the policy level (what data categories feed the model, published in plain language); if someone believes they were misidentified, they can request a human review through a Welfare Officer, who explains the reasoning case-by-case without exposing the raw scoring mechanism.

### 3.3 Minimizing false positives/negatives
- Ensemble modeling (structured HR model + NLP sentiment/behavioral model), never a single score in isolation.
- Human-in-the-loop: an "elevated risk" output only ever routes to a Welfare Officer for a supportive human touchpoint — the model never triggers an automated consequence.
- Monthly clinical-review validation loop recalibrating thresholds against a sample of flagged/unflagged cases; confidence bands shown alongside every score.

### 3.4 Ethical & transparent AI
- SHAP-style feature attribution so a Welfare Officer sees *why* someone was flagged, not just a number. Model cards (training window, limitations, last validation date) published internally. An ethics/oversight board (clinical + legal + personnel representative) reviews model changes before deployment.

### 3.5 Securing sensitive data against cyber threats
- Zero-trust, segmented environments (ingestion / analytics / dashboards each isolated). RBAC + mandatory MFA for welfare-data access. Regular third-party pen testing; DPDP Act 2023 and GIGW/CERT-In compliance. Immutable, independently-reviewable audit logs.

### 3.6 Building personnel trust
- A visible in-app "Data & Privacy" explainer, opt-in/opt-out controls beyond mandatory HR operational fields, an independent grievance channel, and ongoing plain-language communication that the system is welfare-first, not surveillance.

---

## 4. AI Voice Companion — Crisis Detection & Tele-MANAS Escalation

1. **Real-time transcript monitoring** — every conversation analyzed turn-by-turn by a dedicated high-recall crisis classifier (separate from the routine mood-sentiment model), catching indirect phrasing, not just exact keywords.
2. **In-conversation response** — the companion shifts into a calm, supportive, stabilizing script and stays engaged; it never ends the conversation.
3. **Parallel automated escalation** — Tele-MANAS (14416) notified immediately with minimum necessary context; a silent alert simultaneously goes to the unit's duty Welfare Officer/Medical Officer (one of the narrow, pre-authorized re-identification cases, given imminent risk).
4. **Human handoff, not automation** — the companion's job is to keep the person safe and engaged until a human takes over; it never tries to resolve the crisis itself.
5. **Post-incident protocol** — logged for mandatory human follow-up within a defined window; explicitly excluded from any performance/disciplinary data pipeline.
6. **Proportionate verification** — the Tele-MANAS notification fires immediately (lowest-risk, highest-benefit action); the on-base Welfare Officer alert has a fast human-verification step to keep on-base responses proportionate.
7. **Localization requirement**: any crisis-line reference in the app must be Tele-MANAS (14416) — never a generic/placeholder helpline number.

---

## 5. Analytics & ML Layer (Highest Priority — Phase 1)

*(Full architecture diagrams for this layer live in `manofit-architecture.md`; this section covers requirements and data sourcing.)*

- **Feature Engineering Pipeline** — converts pseudonymized HR + Assessment data into rolling-window features (30/60/90-day): leave-utilization ratio, consecutive duty days, transfer/deployment-change frequency, training-load trend, self-reported assessment scores. No single raw record is ever scored in isolation.
- **Predictive Behavioral Analytics Engine** — a gradient-boosted tree model (XGBoost/LightGBM), chosen for interpretability over deep learning since explainability is a hard requirement (§3.4).
- **NLP Crisis & Sentiment Model** — two tiers: a routine sentiment classifier for everyday conversation trend tracking, and a separate high-recall crisis classifier dedicated to the escalation path in §4.
- **Ensemble Scoring + Explainability** — combines HR-behavioral and sentiment scores into a Low/Moderate/Elevated band (never a raw number shown outside the model), with a SHAP-style top-factors summary for reviewers.
- **Synthetic Training Data** *(bootstraps the model before real data exists)*. The PS explicitly names the categories: *"Anonymized HR datasets, deployment records, leave history, wellness survey data, workload data, and simulated behavioral datasets."* Generate synthetic datasets in exactly these categories:
  - Statistically realistic HR/deployment/leave/workload records, generated fully offline, no real identifiers.
  - Simulated conversation transcripts (routine-to-crisis sentiment range) to bootstrap the NLP model.
  - Rule-based synthetic labels (e.g., "high consecutive duty + low leave uptake + declining sentiment → synthetic elevated-risk") standing in for real clinical-reviewed outcomes until the Phase 2 validation loop can recalibrate against real labels.
  - Every synthetic record carries a `synthetic: true` flag so it's never mistaken for real data.
  - **Schema parity is a hard requirement**: identical schema to the real pseudonymized ingestion pipeline, so swapping in real anonymized data later requires zero pipeline changes.
- **Model Validation & Governance** — monthly clinical-review sampling, drift/false-positive/negative tracking, versioned model cards, independent rollback capability, Oversight Board sign-off before promoting a retrained model.

**What this layer explicitly does not do**: make disciplinary/performance/fitness-for-duty determinations, output to any system outside the Welfare Intervention Engine, or receive directly identifiable data.

---

## 6. HR Admin Flow

1. HR Admin logs in (MFA mandatory).
2. Chooses ingestion path: Tier 1 sync status view, Tier 2 CSV/XLSX upload, or Tier 3 manual entry (§2).
3. For Tier 2: downloads template → fills → uploads → sees a pre-ingestion report (accepted/rejected rows with reasons) → confirms.
4. Data is pseudonymized automatically before entering the analytics engine — **HR Admin never sees analytics output or individual risk scores**, only ingestion status.
5. Every upload is logged (who, when, what fields, row count), visible in a compliance log for the Oversight Board.
6. HR Admin's role is structurally scoped to data supply only — enforced by RBAC (Postgres Row-Level Security), not just UI hiding.

---

## 7. Personal App — Screens & User Flow

*(Full UI treatment, tokens, and design prompts live in `manofit-stitch-ui-prompt.md` — minimalist, distinctive typography, no generic template look. This section is the functional spec only.)*

**Design rule carried through every personal screen**: the app never shows the user any output of the organizational risk model — no score, no risk trend, no "you seem stressed lately" insight. What it shows is the user's own activity engagement (streaks, minutes, sleep/HRV if a wearable is connected) — never the risk model's output.

**Screens (functional requirements, visual design fully owned by the Stitch file):**
- **Home** — one greeting, a quick mood check-in, and access to the 4 core features (Self-Help, AI Companion, Check-ins, Book Session).
- **Assessments** — the 6 private check-ins (workload, mood, manager relationship, etc.) — **prioritized in Phase 1** because this is direct "wellness survey data" feeding the ML layer.
- **Self-Help** — a doodle/breathing tool for quick grounding.
- **AI Companion** — live voice/chat companion with the crisis-detection layer from §4.
- **Book / Profile / Workshop request** — therapy booking, settings/privacy explainer, workshop topic request (anonymous, HR sees a count per topic only, never who asked).

**Flow:**
1. Onboarding: install → auth (Service/PF number + OTP via Supabase Auth) → consent screen (mandatory vs. optional data).
2. Home dashboard: activity-style overview, no risk indicator anywhere.
3. Assessments completed periodically (feeds ML, §5).
4. Companion conversations, on demand, crisis-detection always running in the background.
5. Personal activity stats: streaks, minutes, wearable-derived sleep/HRV graphs (Phase 3) — never risk-model output.
6. Confidential counseling request routes directly to a Welfare Officer, never through the chain of command.
7. Crisis path: as in §4.

---

## 8. Welfare Officer / Commander Flow & Dashboards

1. **Welfare Officer**: individual-level flagged cases (post human-review) with explainability context → confidential outreach, counseling log, medical escalation.
2. **Commander**: unit-level aggregate dashboards only (no names) → can request resource allocation but cannot see individual identities without the two-person re-identification protocol.
3. **Dashboards** (all admin-only):
   - Welfare Officer: risk-band history timeline per case, feature-attribution chart, case log.
   - Commander: unit-level risk-band distribution (stacked bar), trend lines (avg. leave-utilization, avg. consecutive duty days), cross-unit comparison, month × unit heatmap.
   - Oversight Board: model performance dashboard (false-positive/negative rate, drift), access-audit summary.

---

## 9. Phased Build Plan (3 Phases)

Analytics/ML/HR/Assessments come first; personal-app extras come last. Each phase ships something genuinely usable/testable on its own; no later phase requires reworking an earlier one.

### Phase 1 — Data Foundation, Analytics Core, HR Admin & Assessments
*(This is the PS's centerpiece — build it first and get it right before anything else.)*
- Supabase backend: RLS policies, roles, pseudonymization Edge Function, the isolated identity-mapping-vault project.
- Tier 1 connector stub, Tier 2 CSV/XLSX bulk upload portal, Tier 3 manual entry (§2) + HR Admin portal (§6).
- Minimal Flutter app shell + auth, just enough to serve the **Assessments** screens (§7) — since assessments are a direct ML data source.
- Synthetic dataset generation (§5) in the PS's named categories, schema-matched to the real ingestion schema.
- Feature-engineering pipeline, Predictive Behavioral Analytics Engine, NLP crisis/sentiment model (trained standalone on synthetic + assessment data, not yet wired to a live companion UI), ensemble scoring + explainability.
- **Usable outcome**: HR can safely upload real data, personnel can complete assessments, and a fully working, demoable risk-scoring pipeline exists (testable via API even before dashboards exist) — the core PS deliverable, done first.

### Phase 2 — Welfare Intervention, Dashboards & Live AI Companion
- Welfare Officer console, Commander dashboard, Oversight Board view (§8), consuming Phase 1's model output.
- Welfare Intervention Recommendation System + Automated Alerts.
- AI Companion goes live in the Flutter app, wired to the Phase 1 crisis classifier; Tele-MANAS escalation pipeline (§4) live end-to-end.
- Home screen + mood-check-in.
- **Usable outcome**: the full organizational loop — data in, risk scored, humans alerted, personnel talking to a crisis-safe companion — working end-to-end.

### Phase 3 — Self-Help Extras, Engagement, Wearables & Hardening
- Self-Help (doodle/breathing tool), Book (therapy booking), Profile, workshop-request panel.
- Wearable integration (sleep/HRV/steps via the Flutter `health` package, bridging Health Connect/HealthKit) — personal-graph-only by default, with a separate opt-in before any wearable trend feeds the ML layer.
- Full motion/transition polish and final visual pass per the Stitch file.
- CI/CD, environment isolation, observability, backup/DR, third-party-audit hooks (see architecture doc).
- **Usable outcome**: the full production-ready platform, engagement layer completing it last.

---

## 10. Additional Upgrades (Future / Stretch — Lowest Priority)

- Multilingual companion support for regional languages.
- Peer support network module (separate from clinical escalation).
- Post-deployment reintegration check-ins (2/4/8 weeks after long postings).
- Predictive leave/workload planning (recommend leave scheduling before fatigue builds).
- Family support portal.
- Telemedicine integration beyond Tele-MANAS.
- Predictive (not just historical) early-warning heatmaps.
- Annual independent third-party model audit.

---

*See `manofit-architecture.md` for the full system architecture, data-flow diagrams, security architecture, and environment/`.env` setup. See `manofit-stitch-ui-prompt.md` for the UI design brief.*
