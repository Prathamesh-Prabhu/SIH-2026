# ManoFit — AI-Powered Personnel Stress & Welfare Monitoring System
### PRD: CAPF/Armed Forces Welfare Platform
**Tech Stack (locked):** Flutter (iOS + Android) + Supabase (Postgres, Auth, Storage, Edge Functions, Realtime)

> **🔒 AGENT DIRECTIVE — READ BEFORE DOING ANYTHING**
> - **This is ManoFit, a fresh build. The earlier "Mindspace" product is cancelled — do not reference it, its repo, its screenshots, its screen layouts, or its naming for anything.** Every screen here is designed fresh per `manofit-stitch-ui-prompt.md`.
> - **Stack is Flutter + Supabase. Nothing else.** Do not scaffold Node.js, React, Kotlin/native-Android, or any other stack.
> - **Companion files, always keep in context together:** `manofit-stitch-ui-prompt.md` (UI design brief — minimalist, distinctive typography, not generic) and `manofit-architecture.md` (system architecture + environment/`.env` setup).
> - **Never hand-build a screen without first generating its design** per the Stitch file. If a screen isn't designed yet, design it first — don't improvise UI.
> - **Work phase-by-phase (3 phases, §9).** Do not start Phase 2 until Phase 1's usable outcome is verified. Do not start Phase 3 until Phase 2 is verified.
> - **Priority order per the PS is: ML/Analytics engine → HR Admin/ingestion → Assessments → everything else.** The Predictive Behavioral Analytics Engine + ML layer (§5) is the **single largest workstream** — it gets the most build time, and depth here comes before HR Admin polish, before dashboards, and far before any self-help feature. Self-help extras (doodle, breathing, booking, wearables) are real features but explicitly lowest priority.
> - **HR data enters exactly one way: an HR Admin uploads a `.xlsx` or `.csv` file (§2).** There is no HRMS API/SFTP connector and no manual per-record entry form. Do not build them.
> - **The HR Admin console is an analytics surface, not an upload tool (§6).** Its primary screen is graphical, aggregate risk analytics and the predictive-engine view; uploading is one small secondary panel. Never build it upload-first.

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
  engine is the biggest slice of the work, then HR Admin/ingestion, then
  Assessments — self-help extras (doodle, booking, wearables) come last, in
  Phase 3.
- HR data ingestion is file upload only: an HR Admin uploads a .xlsx or .csv.
  No API/SFTP connector, no manual entry form. The HR Admin console is built
  analytics-first (aggregate risk graphs + predictive engine), not upload-first.
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

**Non-negotiable assessment rule:** a completed, consented assessment must refresh the next eligible pseudonymized scoring window and the protected aggregate rollups consumed by HR Admin. Do not build assessment collection as an isolated personal-app feature, or an HR console that only reports upload status. HR Admin receives assessment-informed *cohort* intelligence and recommended unit actions, never an assessment response, person, token, or case queue.

---

## 1. Scope

ManoFit is built from scratch against the government problem statement below — there is no legacy app to reference; every screen and flow here is a fresh design.

| PS Requirement | Priority |
|---|---|
| Predictive Behavioral Analytics Engine / Stress & Burnout Risk Models | **Highest — Phase 1, largest workstream (§5)** |
| HR data ingestion (leave, deployment, transfers, duty load) — **file upload only, `.xlsx`/`.csv`** | **Highest — Phase 1** |
| HR Admin console — **analytics-first: aggregate risk graphs + predictive engine (§6)** | **Highest — Phase 1** |
| Assessments / wellness survey data collection | **Highest — Phase 1** (it's a direct ML input) |
| Privacy / RBAC / anonymization framework | **Highest — Phase 1** (prerequisite for the above) |
| Welfare Intervention Recommendation System + Automated Alerts | High — Phase 2 |
| Commander/Welfare Officer Dashboards | High — Phase 2 |
| AI voice companion + Tele-MANAS auto-escalation | High — Phase 2 |
| Self-help activities (doodle, breathing, booking), wearables | Lowest — Phase 3 |

**PS background**: personnel in CAPFs, Armed Forces, and other uniformed services operate under physically demanding, psychologically stressful conditions. Extended deployments, irregular hours, and exposure to traumatic incidents affect mental well-being, and manual/self-reported stress identification delays intervention. ManoFit is a proactive, privacy-first, AI-driven welfare monitoring system addressing this.

---

## 2. HR Data Ingestion — Single Path: Secure File Upload

HR data enters ManoFit **one way only: an HR Admin uploads a standardized `.xlsx` or `.csv` file.** There is deliberately no HRMS REST/SFTP connector and no manual per-record entry form — one well-controlled path is far easier to secure, audit, and schema-validate than three, and it removes the connector as an attack surface and the manual form as a data-quality risk.

### Upload flow
- HR Admin downloads the current standardized template (`.xlsx` or `.csv`) from the console.
- Fills it with structured fields only: leave taken/balance, deployment dates, duty-roster hours, transfer history, training load. The template has **no columns** for medical, disciplinary, or next-of-kin data.
- Uploads via a scoped, short-lived signed upload URL to Supabase Storage. **Only `.xlsx` and `.csv` are accepted** — any other file type (or a mislabeled one) is rejected at the client and again, on content sniffing, at the Edge Function.
- A Supabase Edge Function (Deno/TypeScript) processes it: format detection → parse (`csv-parse` for `.csv`, `SheetJS`/`xlsx` for `.xlsx`) → schema validation → duplicate-row detection → pseudonymization (Service/PF number → rotating token) **before it touches the analytics engine** → audit-logged ingestion → raw file deleted from Storage once committed.
- The HR Admin gets a pre-ingestion report: accepted row count, and every rejected row with its specific error plus a downloadable "rejected rows" file to fix and re-upload.

### Cross-cutting controls
- Pseudonymization at the point of ingestion; re-identification only via the isolated identity-mapping vault (see architecture doc), two-person authorized.
- Mandatory HR-record fields (leave, deployment) ingest under organizational policy; optional fields that double as personal wellness inputs ingest only with individual opt-in.
- Versioned upload templates so a schema revision in one unit's file doesn't break ingestion for others.
- Every upload logged (who, when, which columns, row count, accept/reject counts) in a compliance log for the Oversight Board.

---

## 3. Solving the Key Technical Challenges (Priority Order)

### 3.1 Privacy & confidentiality
- Encryption in transit (TLS 1.3) and at rest (AES-256). Pseudonymization at ingestion + isolated identity-mapping vault with two-person-authorized re-identification and full audit trail. The ML layer only ever sees derived features, never raw HR records or free-text journal content. Differential privacy noise on aggregate/unit-level views.
- Assessment answers are owner-readable only. A server-side scoring job derives the minimum rolling features needed for the consented model channel; HR Admin and Commander can query only precomputed, k-anonymous aggregate views/RPCs, never `assessments`, `hr_features`, `risk_assessments`, or a pseudonym token.
- Every assessment-derived aggregate applies a configurable minimum cohort threshold (default `k >= 5`), small-cell suppression, and query controls that prevent differencing/re-identification across filters or adjacent time windows. A suppressed value is shown as “insufficient cohort size,” never as zero.
- Consent is versioned, purpose-specific, revocable for future optional processing, and auditable. Withdrawal immediately excludes future assessment/biometric features from scoring, routes the person to the appropriate reduced-signal channel, and does not silently degrade their risk band or cohort comparison.

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
- Before submitting an optional assessment, personnel see the purpose, data categories, retention period, who can see what, and the distinction between confidential individual support and anonymized unit analytics. They can access their submitted assessment history, correct an erroneous response where policy permits, and request a human welfare review without seeing a model score.

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

## 5. Predictive Behavioral Analytics Engine + ML Layer — the centerpiece (Highest Priority, Phase 1)

This is the **largest single workstream in the build** and is time-boxed as such: the engine, its explainability, its synthetic-data foundation, its validation harness, and the graphical surfaces that present it (§5.8) all come before HR Admin polish, before dashboards, and far before any self-help feature. The implementation already exists in the repo at `SIH-2026/ml_service/` (a FastAPI microservice; model design and model card mirrored from the reference work at `C:\Users\asus\OneDrive\Desktop\manofit sih model\ml\`). The job is to **deepen and productionize this**, not restart it.

*(Full architecture diagrams live in `manofit-architecture.md`; this section is requirements + what is already built.)*

### 5.1 Feature engineering
Converts pseudonymized HR + Assessment data into rolling-window features (30/60/90-day). ~32 model inputs, **every one traceable to a problem-statement attribute**, across 8 groups:

| PS attribute | example features |
|---|---|
| Leave patterns | leave days, utilisation ratio, days since last leave, cancellations, short-notice ratio |
| Deployment history | count, total days, longest spell, high-intensity share, days since last |
| Duty schedules | avg weekly hours, irregularity, night ratio, extended spells, rest availed |
| Transfer frequency | transfers in 36 months, months since last |
| Training commitments | training days, courses, pending mandatory |
| Workload trends | current index, 90-day change, volatility |
| Optional self-assessment (opt-in) | score, 90-day change, completions, engagement ratio, recency |
| Voluntary biometrics (opt-in) | sleep duration, resting HR, HRV, steps |

### 5.1a Assessment-to-analytics contract (mandatory)
Assessment completion is a first-class model and dashboard event, not merely a stored survey.

1. The app writes the completed assessment to the owner-only assessment store with questionnaire/version, timestamp, consent version, and a server-resolvable identity reference. The client does not calculate or publish organizational risk.
2. A server-side worker validates range/completeness, resolves the rotating pseudonym inside the privacy boundary, derives 30/60/90-day assessment features, and selects the correct `hr_only`, `hr_wellness`, or `hr_wellness_biometric` channel. It writes an immutable scoring-input/provenance event; raw answers never leave the protected assessment store.
3. The scoring job recomputes the affected pseudonymized record and then refreshes only protected aggregate materialized views: risk distribution, trajectories, assessment-domain strain, coverage/freshness, drivers, forecasts, and intervention-outcome measures. The HR Admin UI reads those views through security-definer RPCs, not tables.
4. A delayed/failed job is visible as a freshness state (last successful run, eligible coverage, excluded/suppressed cohort count, model version). It must not be represented as a current predictive result. The target is to include a valid assessment in the next scheduled scoring run; the PRD does not promise real-time scoring.
5. The audit trail records submission, consent decision, feature derivation, model/version/run, aggregate refresh, and every privileged access. It records metadata and purpose, not raw assessment answers.

**Acceptance test:** submit a consented assessment for a seeded personnel record; after the scoring job, verify that (a) its model channel/features and aggregate rollups change as expected, (b) HR Admin can see only the resulting cohort-level change and freshness/coverage metadata, (c) no HR Admin query can retrieve the person, token, answer, or individual band, and (d) revoking optional consent removes its future assessment features and switches to the reduced-signal channel without breaking the aggregate view.

No single raw record is ever scored in isolation. Consent flags (`wellness_data_available`, `biometric_data_available`) and cohort descriptors (rank, years of service) are **excluded** from the feature set — consent is routing metadata and a fairness axis, never a risk input.

### 5.2 The engine — channel-routed, gradient-boosted ensemble
- Gradient-boosted tree model (HistGradientBoosting / XGBoost), chosen for interpretability over deep learning since explainability is a hard requirement (§3.4).
- **Channel routing** instead of imputing absent optional data: one sub-model per available-signal configuration — `hr_only` (23 features), `hr_wellness` (28), `hr_wellness_biometric` (32) — and each record is routed to the sub-model matching what it actually has. No zero-fill, no penalty for withholding optional data.
- **Isotonic calibration** per channel, so a given score means the same expected severity in every consent group and one band definition is fair across them.
- **Risk score** = `0.5 × P(MODERATE) + 1.0 × P(ELEVATED)`, calibrated to [0, 1]. The output shown to reviewers is a **LOW / MODERATE / ELEVATED band** — the raw number is never surfaced outside the model.

### 5.3 Explainability
Local occlusion attribution: each feature is replaced with its channel's training median and the record re-scored; the resulting drop is that feature's contribution. Deterministic and dependency-free. Only score-raising factors above a small threshold are reported, each labelled with the problem-statement attribute it came from — so a Welfare Officer sees *why* someone was flagged, not just a number (§3.4).

### 5.4 Thresholds — selected, not hand-picked
For each channel, take the highest score cut-point that still achieves **≥ 0.85 recall for ELEVATED** (≥ 0.80 for any-concern), fitted on pooled out-of-fold + validation scores, never the hold-out. Rationale: in welfare screening a false negative (someone who needed support and was never reviewed) is costlier than a false positive (a supportive check-in that wasn't needed), because a positive produces an *offer of help*, never a sanction. An equal-flag-rate parity policy is also implemented and selectable.

### 5.5 NLP crisis & sentiment model
Two tiers: a routine sentiment classifier for everyday conversation-trend tracking, and a separate **high-recall crisis classifier** dedicated to the §4 escalation path (Tele-MANAS 14416). Separate artefacts, separate thresholds. A crisis detection also forces the person's risk band to ELEVATED with the detected cue as the top factor.

### 5.6 Synthetic training data *(bootstraps the model before real data exists)*
The PS names the categories: *"Anonymized HR datasets, deployment records, leave history, wellness survey data, workload data, and simulated behavioral datasets."* Generated fully offline:
- HR/deployment/leave/workload records produced by a **latent-variable simulation**: four unobserved drivers (operational exposure, recovery deficit, organisational instability, personal support/resilience) generate the observed features *and*, separately, a latent welfare strain with a large noise term; the strain is cut at population quantiles into a 60 / 27 / 13 LOW/MODERATE/ELEVATED mix.
- **No exported feature appears in the label formula** — there is no threshold rule for the model to reverse-engineer. Verified: the strongest single feature reaches 0.82 ELEVATED AUC vs 0.94 for the full feature set, and a test fails if any single feature exceeds 0.90.
- Simulated conversation transcripts (routine-to-crisis range) bootstrap the NLP models.
- Every synthetic record carries `synthetic: true`; the trainer **refuses to run** on a dataset not flagged synthetic.
- **Schema parity is a hard requirement**: identical schema to the real pseudonymized ingestion pipeline, so swapping in real anonymized data later requires zero pipeline changes.

### 5.7 Validation & governance
- `GroupShuffleSplit` on personnel id so a person's three windows never straddle a split (measured group overlap: 0); the hold-out is evaluated exactly once, and a test asserts the evaluation path can never refit the model.
- Headline **synthetic** hold-out result: **≈0.94 ROC-AUC and ≈0.87 recall for elevated-risk identification** on 1,000 personnel the model never saw. This is *simulation behaviour, not validated real-world accuracy* — correct external phrasing is *"0.94 ROC-AUC for elevated-risk identification on the synthetic hold-out"*, never *"94% accurate for CAPF personnel"*.
- Versioned model cards (training window, limitations, last validation date), checkpointed artefacts with one-file rollback, a monthly clinical-review recalibration loop, Oversight Board sign-off before promoting a retrained model, and an automated test suite over data contract, leakage, risk bands, and output safety.

### 5.8 Graphical surfacing — how the engine is presented
The engine is **not a black-box API** — its output is rendered as graphical analytics for every authorised consumer (HR Admin console §6, Welfare Officer & Commander dashboards §8):
- Risk-band distribution (stacked bar) per unit and overall, with period-over-period change.
- Band-migration / trajectory over time — how many personnel moved LOW→MODERATE→ELEVATED and back.
- **Predictive view**: forecast of a unit's risk-band trajectory for the next window, with confidence bands.
- Feature-attribution charts: which PS factors are driving elevated risk in a given cohort.
- Month × unit heatmap; cross-unit comparison.
- Model-performance panel: ROC-AUC, ELEVATED recall/precision, flag rate, drift, last recalibration — read from `metrics.json` / the active model card.

**What this layer explicitly does not do**: make disciplinary/performance/fitness-for-duty determinations, output to any system outside the Welfare Intervention Engine, receive directly identifiable data, or show any individual their own score.

---

## 6. HR Admin Console — Risk Analytics First

The HR Admin console is **primarily an analytics surface, not an upload tool.** The main screen is graphical risk analytics and the predictive-engine view; uploading data is one small secondary panel. Every analytic here is **aggregate / unit-level only** — no individual names, no individual risk scores — enforced by Postgres Row-Level Security, not UI hiding. Individual-level review stays exclusively with Welfare Officers (§8). This does not weaken the anti-stigmatization rules in §3.2; it gives the org-admin role the same aggregate picture a Commander gets, plus ingestion control.

### Primary surface — Risk & Predictive Analytics
- **Risk-band distribution** (stacked bars) per unit and overall, with period-over-period movement.
- **Trend lines**: average leave-utilization, average consecutive duty days, workload index, and assessment-informed wellbeing/strain indices. Every trend declares cohort coverage, freshness, and whether a small cell has been suppressed.
- **Band-migration flow** over the last N windows (who moved up, who recovered).
- **Predictive Analytics Engine panel** (§5.8): forecast of each unit's risk trajectory for the next window with confidence bands; driver-attribution chart (which PS factors are pushing risk up in this unit); month × unit heatmap; cross-unit comparison.
- **Model status strip**: last scoring run, personnel coverage, model-card link, headline performance (ROC-AUC, ELEVATED recall, flag rate, drift, last recalibration).
- **Assessment signal & data-quality panel**: eligible/consented assessment coverage, completion and freshness trends, channel mix, suppressed cohorts, validation failures, and the effect of new assessments on *aggregate* risk/driver movement. It must distinguish “no data,” “not consented,” “stale,” and “suppressed” rather than treating any of them as low risk.
- **Unit action planner**: ranks only safe, non-disciplinary, cohort-level welfare actions from observed drivers (for example roster/rest review, workload balancing, voluntary check-in campaign, peer-support session, counseling capacity, or training review). Each recommendation shows its evidence window, confidence/limitations, accountable owner, target date, and success metric. HR Admin can create or request a unit action, but cannot initiate individual outreach or inspect individual cases.
- **Intervention outcome board**: compares protected pre/post cohort measures, uptake, and unresolved aggregate pressure indicators; it records that results are observational and sends unresolved individual concerns only to the Welfare Officer workflow.

### Secondary surface — Data Ingestion (one panel)
1. Download the current template (`.xlsx` / `.csv`).
2. Upload a filled `.xlsx` or `.csv` — no other input method exists (§2).
3. Pre-ingestion report: accepted row count; every rejected row with its error + a downloadable "rejected rows" file.
4. Confirm to commit. Data is pseudonymized automatically before it enters the analytics engine.
5. Compliance log: who uploaded, when, which columns, row count, accept/reject counts — visible to the Oversight Board.

### Role scoping
- HR Admin sees aggregate analytics, unit-action planning, and ingestion. **Never** sees an individual's identity, assessment response, pseudonym token, risk score/band, factor attribution, or intervention/case record; cannot reach the identity vault or Welfare Officer case queue.
- The role reads only privacy-protected aggregate views/RPCs with k-anonymity, suppression, differential-privacy safeguards, and filter/query-budget controls. Direct table access is denied by RBAC/RLS; this is not enforced by hiding UI.
- MFA mandatory on login.

### Required HR-admin behaviour (release gate)
1. A new eligible assessment changes the next refreshed cohort analytics or is explicitly shown as pending/failed; it must never disappear silently.
2. All cohort filters are constrained to approved unit/time grains and remain suppressed below `k`; the UI must not offer drill-down combinations that enable a manager to infer a respondent.
3. Every predicted risk chart shows its model version, scoring time, population/coverage, confidence or uncertainty, and the statement “welfare support only — not disciplinary, performance, or fitness-for-duty evidence.”
4. No action in this console can re-identify a person, export row-level data, assign a person to an intervention, or send a named alert. Only Welfare Officer workflows may do so after human review.
5. The console can export a privacy-safe, aggregate action brief for authorized planning; exports carry the same suppression and audit controls as the screen.

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
   - HR Admin: aggregate risk-band distribution + predictive-engine forecast + driver attribution + ingestion status — aggregate only, no identities (see §6). Mirrors the Commander analytics view without the resource-allocation actions, plus the ingestion panel.
   - Welfare Officer: risk-band history timeline per case, feature-attribution chart, case log.
   - Commander: unit-level risk-band distribution (stacked bar), trend lines (avg. leave-utilization, avg. consecutive duty days), predictive risk-trajectory forecast, cross-unit comparison, month × unit heatmap.
   - Oversight Board: model performance dashboard (false-positive/negative rate, drift), access-audit summary.

---

## 9. Phased Build Plan (3 Phases)

Analytics/ML/HR/Assessments come first; personal-app extras come last. Each phase ships something genuinely usable/testable on its own; no later phase requires reworking an earlier one.

### Phase 1 — Analytics Core (largest slice), Data Foundation, HR Admin & Assessments
*(This is the PS's centerpiece — build it first and get it right before anything else. The ML/analytics engine §5 gets the majority of Phase 1 effort.)*
- **Predictive Behavioral Analytics Engine + ML layer (§5) — the priority.** Deepen and productionize `ml_service/`: feature-engineering pipeline, channel-routed gradient-boosted ensemble with calibration and selected thresholds, occlusion explainability, NLP crisis/sentiment tiers (trained standalone, not yet wired to a live companion UI), validation harness + model card + governance/rollback.
- Synthetic dataset generation (§5.6) in the PS's named categories, latent-variable labels, schema-matched to the real ingestion schema.
- **Graphical surfacing (§5.8) of the engine** — a first working version of the aggregate risk-analytics and predictive-engine graphs, consumed by the HR Admin console.
- Supabase backend: RLS policies, roles, pseudonymization Edge Function, the isolated identity-mapping-vault project.
- Secure file-upload ingestion portal — `.xlsx`/`.csv` only, no API connector, no manual entry (§2).
- Analytics-first HR Admin console (§6): risk & predictive-analytics screen as the primary surface, ingestion as a secondary panel.
- Minimal Flutter app shell + auth, just enough to serve the **Assessments** screens (§7) — since assessments are a direct ML data source.
- **Usable outcome**: a fully working, demoable risk-scoring + prediction pipeline (testable via API), HR can safely upload `.xlsx`/`.csv` data and see aggregate risk analytics and the predictive-engine forecast as graphs, and personnel can complete assessments — the core PS deliverable, done first.

### Phase 2 — Welfare Intervention, Dashboards & Live AI Companion
- Welfare Officer console, Commander dashboard, Oversight Board view (§8), consuming Phase 1's model output; expansion and polish of the HR Admin analytics/predictive graphs from Phase 1.
- Welfare Intervention Recommendation System + Automated Alerts.
- Controlled intervention outcome taxonomy and aggregate feedback loop for governance/calibration; never self-train on free-text case notes or unreviewed intervention outcomes.
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
- Longer-horizon predictive early-warning heatmaps (multi-window trajectory modelling beyond the core next-window forecast delivered in §5.8).
- Annual independent third-party model audit.

---

*See `manofit-architecture.md` for the full system architecture, data-flow diagrams, security architecture, and environment/`.env` setup. See `manofit-stitch-ui-prompt.md` for the UI design brief.*
