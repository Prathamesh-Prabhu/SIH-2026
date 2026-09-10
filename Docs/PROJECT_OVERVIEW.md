# ManoFit — Project Overview (Presentation Brief)

*AI-Powered Personnel Stress & Welfare Monitoring System for CAPF / Armed Forces*
Smart India Hackathon 2026

---

## 1. The problem (one-liner to open with)

> Armed-forces and CAPF personnel face sustained operational stress — long
> deployments, rotations, separation from family, and a strong stigma around
> asking for help. Existing welfare systems are **reactive** (they respond after
> an incident) and **not confidential** (going through the chain of command).
> There is no early-warning system and no private space to seek support.

**ManoFit** is a proactive, privacy-first welfare platform that does three things:

1. Gives every soldier a **confidential** personal wellbeing space (check-ins,
   a voice companion, mindfulness) that the chain of command can never see.
2. Runs a **predictive analytics engine** on *pseudonymised* operational data
   (duty hours, leave, rotations) + anonymous self-reports to flag **units and
   cohorts** trending toward burnout — never naming an individual to a commander.
3. Routes acute crisis signals straight to **Tele-MANAS 14416** and a licensed
   **Welfare Officer**, automatically.

The guiding rule: **help arrives early, and it never costs the person their
privacy or their career.**

---

## 2. What makes it different (say these early)

| Principle | How it shows up |
|---|---|
| **Pseudonymise at the point of entry** | HR data is SHA-256 hashed on upload; the raw Service/PF number is never stored in the analytics database. |
| **Data flows one way, downward, through a privacy layer** | No dashboard ever queries raw personal data directly. |
| **Individuals never see org risk output; org roles never see raw individual identity** | Re-identification needs a two-person, audited exception. |
| **Commanders get differential privacy** | Only unit-level aggregates with k-anonymity > 25 — no individual score is ever derivable. |
| **The ML core is a decoupled microservice** | Testable and callable independently of any screen. |
| **No raw scores are ever shown** | Not to the soldier, not to the commander — only clinical **bands** (Low / Moderate / Elevated) + top contributing factors for the Welfare Officer. |

---

## 3. The five roles (this structures the whole demo)

| Role | Console | Sees | Never sees |
|---|---|---|---|
| **Personnel** (soldier) | Mobile app | Their own check-ins, Tara, mindfulness, mood, streak | Any risk score / band about themselves |
| **HR Admin** | Web console | Aggregate org-wellbeing charts, cohort risk distribution, ingestion status | Individual identities or individual scores |
| **Welfare Officer** | Web console | Individual risk **bands** + factor attributions for casework | Raw model probabilities; disciplinary records |
| **Commander** | Web console | Differentially-private **unit** readiness aggregates only | Any individual data |
| **Oversight / Ethics Board** | Web console | Model card, metrics, audit log, governance | Personal data (read-only audit access) |

RBAC is enforced twice: **Postgres Row-Level Security** on the server (the real
enforcement point) and a **client-side router guard** (`RoleAccess`) so an
HR Admin deep-linking to `/hr-analytics` is bounced, not shown a forbidden board.

---

## 4. System architecture

```
   PERSONNEL (Flutter mobile)          HR / WELFARE / COMMANDER / OVERSIGHT
        │  check-ins, Tara,                    (same Flutter codebase,
        │  mindfulness, mood                    compiled for Web)
        ▼                                              │  .xlsx / .csv upload
 ┌──────────────────────────── SUPABASE ───────────────────────────────┐
 │  Auth (role claims)  ·  Postgres + Row-Level Security  ·  Storage    │
 │  Realtime  ·  Edge Functions (pseudonymisation, alert dispatch,     │
 │  re-identification broker — two-person-auth gated)                  │
 │  Tables: profiles, mood_logs, assessments, mindfulness_logs,        │
 │  mindfulness_moods, hr_features, hr_ingestion_logs, crisis_alerts,  │
 │  counseling_sessions, self_help_logs, audit_logs, system_config     │
 └───────────────┬──────────────────────────────────┬─────────────────┘
                 │ authenticated internal API        │  dynamic endpoints
                 ▼                                    ▼
 ┌───────────────────────────────┐   ┌───────────────────────────────────┐
 │  ANALYTICS / ML MICROSERVICE   │   │  TARA VOICE SERVICE (Node/Express) │
 │  Python · FastAPI · XGBoost    │   │  WebSocket relay → Google Gemini   │
 │  · scikit-learn · Pandas       │   │  Live API (native audio-to-audio)  │
 │  Feature engineering (30/60/90d)│   │  + /chat text endpoint            │
 │  Risk ensemble + calibration   │   │  Holds the GEMINI_API_KEY;         │
 │  NLP: sentiment + crisis (Tier  │   │  real-time crisis lexicon scan    │
 │  1 / Tier 2)  · SHAP-style      │   │  → Tele-MANAS escalation event    │
 │  explainability  · model card   │   └───────────────────────────────────┘
 └───────────────┬───────────────┘
                 ▼
        TELE-MANAS 14416  (national mental-health helpline — crisis auto-notify)
```

**Why three services and not one monolith:**
- **Supabase** = the system of record + auth + RLS. Fast to build, secure by default.
- **ML microservice** is deliberately **decoupled** — the PRD's #1 priority is
  model depth, so it must be independently trainable/testable and swappable
  (real anonymised data ↔ synthetic data, zero code change).
- **Tara service** exists because the Gemini API key must **never** ship inside
  the APK; the phone only ever talks to our relay over a WebSocket.

---

## 5. Feature walkthrough

### 5.1 Personnel app

- **Assessments / private check-ins** — three cadences, each with its **own
  question bank**:
  - *Daily pulse* — 4 quick "today" questions (mood, tiredness, sleep, duty load).
  - *Weekly check-in* — the full **six-domain** model: workload, sleep,
    physical exhaustion, mood, leadership support, unit connection.
  - *Monthly review* — those six (month-framed) **plus four reflective domains**:
    sense of purpose, strain from time away from home, financial pressure,
    outlook on a future in the service.
  - Every answer is pseudonymised, fed to the org-wellbeing roll-up, and
    **never scored back to the user**.
- **Tara — voice companion** — a warm, non-clinical companion built on Google
  **Gemini Live** (native audio-to-audio).
  - **Multilingual**: Auto / English / हिंदी toggle. "Auto" mirrors the user and
    switches freely between Hindi, English and Hinglish.
  - Soft "Leda" voice; English uses a natural Indian-English accent.
  - Separate **text chat** (a small icon) that works without starting a call.
  - **Crisis auto-escalation**: the relay scans the live speech transcript
    against a high-recall lexicon (English + Hindi); a hit raises a
    `crisis_alerts` row (Welfare Officer handoff) and puts a Tele-MANAS
    14416 call one tap away.
  - The call auto-hangs-up when the app is backgrounded or after a quiet stretch.
- **Mindfulness section** (Samsung-Health-style hub):
  - *Breathing* — box, 4-7-8 long-exhale, equal, and a custom pattern, with an
    animated guided session.
  - *Meditation* — **Meditate / Sleep / Music** tabs; each session plays a
    looping soothing ambience (rain, ocean, forest, campfire, night crickets…)
    streamed from Google's free Sound Library, with a calm countdown player.
  - *Mood check-in* — a 5-point Samsung-style scale + contributing-factor chips.
  - *Doodle* — a low-pressure expressive activity.
  - *History* — a timeline of everything logged.
- **Streak & profile** — a consecutive-day wellbeing streak (any mood /
  mindfulness / check-in entry), a streak-driven **rank** (Recruit → Ironclad)
  and 8 milestone badges — all computed client-side, shown to personnel only.
- **Book a session** — request a confidential counselling slot.
- **Self-help micro-tools** — grounding, worry-dissolver, breathing calmer,
  ambient sounds, a feeling-based recommender.

### 5.2 HR Admin console

- **Analytics-first, not upload-first.** The home screen is graphical:
  - **Organisation Wellbeing** — a 0–100 index **gauge** (Healthy / Watch /
    Strained band) + a **bar chart** of the worst-hit domains + a **Monthly
    deep-dive** bar chart (purpose / home strain / money / future).
  - **Check-in participation** — a **bar chart** of Daily / Weekly / Monthly
    response counts + a **14-day line chart** of daily check-ins.
  - **Cohort risk distribution** — a donut of Low / Moderate / Elevated bands
    from the ML service.
- **Data ingestion** — the *only* way HR data enters: an HR Admin uploads a
  **`.xlsx` / `.csv`** roster. On ingestion every Service ID is **SHA-256
  hashed**; the raw identifier is never stored. There is deliberately **no HRMS
  API/SFTP connector and no manual per-record form**.
- HR Admin sees **aggregate roll-ups only** — never an individual score or name.

### 5.3 Welfare Officer console

- Individual **risk bands** + **factor attributions** (SHAP-style: "elevated
  because of consecutive-duty streak + low leave utilisation + low peer
  support") for welfare casework. Still no raw probability.
- **Active alerts** queue — personnel flagged for a supportive check-in,
  including crisis escalations from Tara.

### 5.4 Commander console — Institutional Resilience

- **Unit-level aggregates only**, with **k-anonymity > 25** and differential
  privacy. Risk-band distribution bar, unit readiness index, leave-parity,
  average consecutive-duty days. A "Request proactive welfare roster rotation"
  action. No individual is ever derivable.

### 5.5 Oversight / Ethics Board console

- **Model card** (version, metrics, training data description), governance
  notes, and (design) the immutable audit log. One-file model rollback.

---

## 6. The ML / analytics engine (the biggest workstream)

**Stack:** Python, FastAPI, XGBoost, scikit-learn, Pandas, NumPy, Pydantic.

**Pipeline:**

1. **Synthetic data generator** — a latent-variable generator produces
   schema-identical synthetic HR records (≈45,000 rows = 500 personnel × 90
   days), wellness assessments, and companion transcripts. Every synthetic row
   is tagged `synthetic: true`. Real anonymised data drops in with **zero code
   change**.
2. **Feature engineering** — 30 / 60 / 90-day rolling windows produce ≈32
   pseudonym-traceable features: consecutive active days, duty-hour load, leave
   utilisation, redeployment frequency, time at current posting, training load,
   plus the six self-report domains.
3. **Behavioral risk model** — a channel-routed **gradient-boosted (XGBoost)
   ensemble** with **isotonic calibration**, producing a calibrated risk
   probability that is **immediately bucketed** into `LOW / MODERATE / ELEVATED`.
   The raw probability never leaves the service.
4. **Explainability** — occlusion / SHAP-style factor attribution so a Welfare
   Officer sees *why* a case is elevated, in plain language.
5. **NLP, two tiers:**
   - *Tier 1* — routine sentiment / stress / fatigue valence tracking.
   - *Tier 2* — a **high-recall crisis classifier** tuned for maximum
     sensitivity to acute despair / burdensomeness / self-harm cues (direct
     *and* indirect phrasing). A hit fires the Tele-MANAS escalation payload.
6. **Governance** — model card generation, versioned checkpoints, one-file
   rollback.

**API (FastAPI, token-auth'd internal service):**
`/api/v1/synthetic/generate` · `/features/transform` · `/models/train` ·
`/score/predict` · `/score/batch` · `/nlp/sentiment` · `/nlp/crisis` ·
`/governance/model-card` · `/governance/rollback` · `/health`

The Flutter client never calls the ML service directly — it goes through
Supabase / the analytics controller, and the app **degrades gracefully** to
on-device heuristics when the service is offline.

---

## 7. Privacy, security & ethics

- **Row-Level Security** on every table — owner-only for personal data;
  ML-service-only for `hr_features`; Welfare-Officer-scoped for risk output;
  Oversight read-only for the audit log.
- **Pseudonymisation** (SHA-256) at ingestion; the **identity-mapping vault** is
  designed as a *separate* Supabase project reachable only through a
  re-identification broker Edge Function that enforces **two-person
  authorisation + audit logging**.
- **Differential privacy / k-anonymity > 25** for anything a Commander sees.
- **DPDP Act 2023** alignment — explicit consent, a consent-audit ledger,
  purpose limitation, and a data-governance explainer in-app.
- **Secrets never ship in the APK** — Supabase and Gemini keys live server-side;
  the Tara relay holds the Gemini key, the phone holds nothing sensitive.
- **Transport & at rest** — TLS 1.3 in transit, AES-256 at rest (Supabase
  managed), immutable append-only audit logging.
- **Crisis handling is non-terminating** — Tara never abandons a distressed
  user; it stabilises and bridges to human help.

---

## 8. Tech stack summary

| Layer | Technology |
|---|---|
| **Mobile + Web client** | Flutter (single codebase, `go_router`, `provider`), Material 3 |
| **Backend / DB / Auth** | Supabase — Postgres + Row-Level Security, Auth, Storage, Edge Functions, Realtime |
| **Analytics / ML** | Python, FastAPI, XGBoost, scikit-learn, Pandas, NumPy, Pydantic, joblib |
| **Voice companion** | Node.js + Express + `ws`, Google **Gemini Live API** (native audio) + Gemini text for chat |
| **Audio** | `audioplayers` (streamed royalty-free ambience) |
| **Key Flutter packages** | `supabase_flutter`, `go_router`, `provider`, `webview_flutter`, `audioplayers`, `permission_handler`, `url_launcher`, `file_picker`, `excel`, `flutter_dotenv`, `shared_preferences`, `crypto`, `google_fonts` |
| **Deploy** | `render.yaml` — Tara service + ML service as Render web services; Flutter APK / web bundle |

---

## 9. What's built vs. simulated (be honest if asked)

**Working end-to-end:**
- Flutter app (personnel + all role consoles) with role-based routing.
- Real Supabase auth (Service ID → synthetic email/password mapping) + RLS schema.
- Assessments write real rows; org-wellbeing roll-up and HR charts compute from them.
- Tara voice + text, multilingual, with live crisis-lexicon escalation → `crisis_alerts`.
- ML microservice: synthetic generation, feature engineering, XGBoost training,
  scoring, NLP, model card — runnable and deployable.
- HR `.xlsx` / `.csv` ingestion with SHA-256 pseudonymisation.
- Mindfulness (breathing, meditation with streamed ambience, mood, doodle, history).

**Simulated / demo-scoped for the hackathon:**
- Some Commander/analytics trend figures use a fixed demo dataset
  (`admin_demo_data.dart`) where the corresponding endpoints aren't wired yet.
- The identity-mapping vault + two-person re-identification broker is designed
  in the architecture, not deployed as a second live project.
- Tele-MANAS integration surfaces a `tel:14416` dialer + escalation record;
  a production API handshake is future scope.
- Wearables (Health Connect / HealthKit) are Phase 3, not built.

---

## 10. Suggested 5-minute demo flow

1. **Sign in as Personnel** → Home. Point out the streak and that there's *no*
   risk score anywhere.
2. **Do a Daily pulse** (4 questions) → show it's private, submitted.
3. **Open Tara** → switch to हिं, say a line in Hindi, switch to EN. Then open
   the **text chat** without a call. (If safe to demo) show a crisis phrase
   triggering the Tele-MANAS sheet.
4. **Meditation → Sleep → "Rain at Night"** → the ambience plays, calm player.
5. **Sign out, sign in as HR Admin** → the **charts**: wellbeing gauge, concern
   bars, participation bar + line chart, cohort risk donut. Upload a sample CSV
   → show the SHA-256 pseudonymisation note.
6. **Sign in as Commander** → only unit aggregates, k-anonymity banner.
7. Close on the **privacy architecture** slide.

---

## 11. Future scope

- Live Tele-MANAS API integration.
- Deploy the separate identity vault + re-identification broker.
- Wearable ingestion (sleep, HRV) via `health`.
- On-device NLP for offline crisis detection.
- Longitudinal trend forecasting per unit.
- Multi-language expansion beyond Hindi/English.
- Federated / on-prem deployment option for classified networks.
