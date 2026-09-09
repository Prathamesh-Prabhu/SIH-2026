# ManoFit — High-Level Architecture

**Tech Stack (locked):** Flutter (iOS + Android) + Supabase (Postgres, Auth, Storage, Edge Functions, Realtime)

> **🔒 AGENT DIRECTIVE — READ BEFORE DOING ANYTHING**
> This is ManoFit, a fresh build — the earlier "Mindspace" product, repo, and screens are cancelled and are not a reference for anything here. The stack is **Flutter + Supabase only**. Companion files: `manofit-prd.md` (requirements + 3-phase plan) and `manofit-stitch-ui-prompt.md` (UI design brief). Build strictly phase-by-phase per `manofit-prd.md` §9 — this doc's diagrams are labeled by phase.

---

## 1. Design Principles

1. **Data flows strictly downward through a privacy layer** — no role or dashboard ever queries raw HR/personal data directly.
2. **Pseudonymize at the point of entry, isolate re-identification** — the identity-mapping vault is a separate, narrowly-reachable Supabase project, not a table in the main database.
3. **Individuals never see organizational risk output; org roles never see raw individual identity without a two-person, audited exception.**
4. **The ML core is decoupled from any single UI** — callable/testable via API independent of the AI companion or any dashboard. This is why Phase 1 builds it before most personnel-facing screens exist.
5. **Every environment (dev/staging/prod) and the identity vault are physically separate Supabase projects**, not just config flags.

---

## 2. System Context Diagram

```
                         ┌────────────────────────┐
                         │        PERSONNEL         │
                         │      (Flutter app)       │
                         └────────────┬─────────────┘
                                      │ check-ins, companion chat, self-help
                                      ▼
   ┌───────────┐        ┌─────────────────────────────┐
   │  HR ADMIN │──.xlsx/─▶│                             │
   │(Flutter Web)│  .csv    │        MANOFIT              │
   │            │  upload  │        PLATFORM             │
   │            │  ONLY    │                             │
   └───────────┘        │                             │
   ┌────────────────┐   │                             │   ┌─────────────────────┐
   │ WELFARE OFFICER│◀──┤                             ├──▶│   TELE-MANAS (14416)  │
   │ (Flutter Web)  │   │                             │    │ national helpline API │
   └────────────────┘   │                             │    └─────────────────────┘
                         │                             │
   ┌────────────────┐   │                             │
   │   COMMANDER    │◀──┤                             │
   │ (Flutter Web)  │   └─────────────┬───────────────┘
   └────────────────┘                 │
                         ┌────────────▼───────────────┐
                         │  ETHICS / OVERSIGHT BOARD    │
                         │  (Flutter Web — audit & model)│
                         └───────────────────────────────┘
```

**Note on client unification**: since the whole project is Flutter, the HR Admin, Welfare Officer, Commander, and Oversight consoles can all be **the same Flutter codebase compiled for web** (`flutter build web`), with role-based routing/screens — not separate projects. Only the deployed *build target* differs (mobile app vs. web admin bundle).

---

## 3. Layered Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│  CLIENT LAYER  (single Flutter codebase, multiple build targets)         │
│  • Personnel: Flutter mobile app (iOS + Android)                         │
│  • HR Admin / Welfare Officer / Commander / Oversight: Flutter Web        │
│    (role-scoped routing via go_router + Supabase Auth role claims)       │
└───────────────────────────────┬────────────────────────────────────────┘
                                 │ HTTPS/TLS 1.3, supabase_flutter SDK
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  API / EDGE LAYER  (Supabase Edge Functions, Deno/TypeScript)             │
│  • Auth verification & session issuance   • Upload handlers (.xlsx/.csv)   │
│  • Pseudonymization service                • Alert dispatch (Tele-MANAS,  │
│  • Consent-ledger writes                     Welfare Officer notify)      │
│  • ML-inference trigger/orchestration      • Re-identification broker     │
│    (two-person-auth gated)                                                │
└───────────────────────────────┬────────────────────────────────────────┘
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  DATA LAYER (Supabase Postgres, RLS-enforced)                             │
│  • personnel_app_data (activities, journals, mood — RLS: owner only)     │
│  • assessments (the 6 private check-ins — RLS: owner + ML service)       │
│  • hr_features (pseudonymized, rolling-window features — RLS: ML service │
│    + oversight audit only)                                               │
│  • risk_assessments (bands + explainability, no raw scores — RLS:        │
│    Welfare Officer/Commander per scope)                                  │
│  • audit_log (immutable, append-only — RLS: Oversight Board read-only)   │
│  • consent_ledger                                                         │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ IDENTITY-MAPPING VAULT — SEPARATE SUPABASE PROJECT, own keys,        │ │
│  │ reachable ONLY via the re-identification broker Edge Function,       │ │
│  │ which enforces two-person authorization + audit logging.             │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────┬────────────────────────────────────────┘
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  ANALYTICS / ML LAYER (Python microservice, FastAPI — separate service,   │
│  called from Supabase Edge Functions via authenticated internal API)     │
│  • Feature engineering (30/60/90d, ~32 PS-traceable features)             │
│  • Channel-routed gradient-boosted risk ensemble + isotonic calibration   │
│  • NLP sentiment + high-recall crisis models (companion transcripts)      │
│  • Occlusion (SHAP-style) explainability  • Predictive/forecast surfacing │
│  • Model validation/versioning, model card, one-file rollback            │
│  • Synthetic-data generator (latent-variable, Phase 1, schema-matched)    │
└───────────────────────────────┬────────────────────────────────────────┘
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  INTEGRATION LAYER                                                        │
│  • Tele-MANAS API (crisis auto-notify)                                    │
│  • Health Connect / HealthKit via Flutter `health` package (wearables,    │
│    Phase 3 only)                                                          │
└──────────────────────────────────────────────────────────────────────────┘

Cross-cutting (all layers): RBAC via Supabase Auth + Postgres RLS · TLS 1.3
in transit / AES-256 at rest · immutable audit logging · CI/CD with isolated
dev/staging/prod Supabase projects.
```

---

## 4. Component Responsibility Matrix

| Component | Reads | Writes | Never touches |
|---|---|---|---|
| Personnel app (Flutter) | Own activity/journal/assessment data | Own check-ins, doodles, assessments, companion transcripts (opt-in) | Any risk score/band, any other user's data |
| HR Admin (Flutter Web) | Ingestion status + own upload history; **aggregate/unit-level risk analytics + predictive-engine views** (no identities) | Raw HR file uploads (`.xlsx`/`.csv`) → pseudonymization pipeline | Individual identities, individual risk scores, the identity vault, the Welfare Officer case queue |
| Pseudonymization Edge Function | Raw uploaded HR rows | `hr_features` (pseudonymized) + identity-vault mapping | — |
| ML microservice | `hr_features`, `assessments`, consented companion transcripts, synthetic datasets | `risk_assessments` (band + explainability only) | Raw HR records, real identities, free-text journal content |
| Welfare Officer console (Flutter Web) | `risk_assessments` (individual, post-review), case log | Intervention/case notes | Raw HR data, other units' cases without scope |
| Commander dashboard (Flutter Web) | Aggregated/differentially-private views only | Resource-allocation requests | Any individual-level data or identity |
| Oversight Board view (Flutter Web) | `audit_log`, model cards, validation-loop samples | Model approval/rollback decisions | — |
| Re-identification broker | Identity vault (only on two-person-authorized request) | Audit log entry per lookup | Bulk export of the vault |
| Tele-MANAS integration | Minimum necessary context on crisis trigger | Escalation event log | Any data beyond what's needed for the handoff |

---

## 5. Data Flow — HR Ingestion (Phase 1)

```
HR Admin (Flutter Web) — the ONLY ingestion path
   │ uploads .xlsx / .csv  (no HRMS API/SFTP connector, no manual entry form)
   ▼
Supabase Storage (signed URL, short-lived; .xlsx/.csv only, type-sniffed)
   │
   ▼
Edge Function: parse → validate schema → dedupe
   │
   ▼
Pseudonymization (Service/PF number → rotating token)
   │
 ┌─────────┴─────────┐
 ▼                   ▼
identity-vault write   hr_features (Postgres, RLS-protected)
(isolated project)            │
                               ▼
                  Audit log entry + ingestion status
                  → HR Admin sees accepted/rejected rows;
                    aggregate risk analytics + predictive views
                    update once scoring runs (no individual data)
```

---

## 6. Data Flow — ML Training & Inference (Phase 1)

```
hr_features (real, pseudonymized)         assessments (real)      Synthetic
        │                                        │                generator
        └───────────────┬────────────────────────┴────────────────────┘
                         ▼
                Feature Engineering Pipeline
        (rolling 30/60/90-day windows, schema-identical
         whether the source is real or synthetic)
                         ▼
        ┌────────────────┴───────────────────┐
        ▼                                     ▼
Predictive Behavioral Model         NLP Crisis/Sentiment Model
(XGBoost/LightGBM)                   (routine tier + crisis tier,
                                      trained standalone in Phase 1,
                                      wired to live companion in Phase 2)
        └────────────────┬───────────────────┘
                         ▼
          Ensemble Scoring + SHAP Explainability
                         ▼
        risk_assessments (band + top factors only)
                         ▼
     Welfare Officer review (Phase 2) → Monthly clinical
     validation sample → threshold recalibration/retraining →
     Oversight Board sign-off → new model version deployed
```

---

## 7. Data Flow — Personal Check-in & Crisis Escalation (Phase 2)

```
Personnel app (Flutter)
   │ check-in / companion conversation
   ▼
Edge Function: routine sentiment classifier
   │
   ├── normal → stored as personal activity data (RLS: owner-only)
   │
   └── crisis-pattern detected → dedicated high-recall NLU classifier
              │
              ├──▶ companion stays in-conversation (supportive script, no delay)
              │
              ├──▶ Tele-MANAS API notified (parallel, no wait for confirmation)
              │
              └──▶ Re-identification broker (pre-authorized, imminent-risk case)
                          │
                          ▼
                 Welfare Officer / duty Medical Officer alerted (Realtime push)
                          │
                          ▼
                 Post-incident log (excluded from any disciplinary pipeline)
```

---

## 8. Security & Privacy Architecture

- **RBAC** enforced at the Postgres RLS layer, mapped 1:1 to Supabase Auth roles: `personnel`, `hr_admin`, `welfare_officer`, `commander`, `oversight_board`.
- **Identity-mapping vault isolation**: separate Supabase project, separate keys, reachable only through the re-identification broker Edge Function (two authorized approvers + audit log per lookup) — the *only* path from a pseudonym back to a real identity anywhere in the system.
- **Encryption**: TLS 1.3 in transit; AES-256 at rest via Postgres encryption + `pgsodium`/Vault-managed keys.
- **Differential privacy** on any Commander-facing **and HR-Admin-facing** aggregate/predictive view so small cohorts can't be reverse-engineered. The `hr_admin` role reads aggregate `risk_assessments` rollups only — never an individual row, never an identity (RLS-enforced, same as `commander`).
- **Immutable audit log**: every access to `hr_features`, `risk_assessments`, or the identity vault logged with actor, timestamp, justification — Oversight Board read-only.
- **No cross-system linkage**: no API connection to disciplinary/performance-review systems — enforced architecturally, not just by policy.

---

## 9. Environment & Configuration (`.env` Setup)

**Golden rule: the Supabase `service_role` key, and every other privileged secret, never ships inside the Flutter app bundle — mobile and web clients only ever hold the public `anon` key, protected by RLS.** Privileged operations (pseudonymization, re-identification, ML orchestration, Tele-MANAS calls) live in Edge Functions, whose secrets are stored in Supabase's own secrets manager, not in any client `.env`.

### 9.1 Flutter client environment files

Use Flutter **flavors** (dev/staging/prod) with `--dart-define-from-file`, not `flutter_dotenv` bundled secrets, so nothing sensitive ends up compiled into the app binary. Directory layout:

```
/env
  .env.dev.example
  .env.staging.example
  .env.prod.example
  .env.dev        (gitignored — real values, local/CI only)
  .env.staging    (gitignored)
  .env.prod       (gitignored)
```

`.env.dev.example` (same shape for staging/prod, different values):
```
# Public, safe to expose in a compiled client — protected by Supabase RLS
SUPABASE_URL=https://<dev-project-ref>.supabase.co
SUPABASE_ANON_KEY=<dev-anon-key>

# Feature flags
ENABLE_WEARABLE_SYNC=false     # true only from Phase 3 onward
ENABLE_COMPANION_LIVE=false    # true only from Phase 2 onward
APP_ENV=dev
```

Run/build with:
```
flutter run --dart-define-from-file=env/.env.dev
flutter build web --dart-define-from-file=env/.env.prod   # admin consoles
flutter build apk --dart-define-from-file=env/.env.prod   # personnel app
```

### 9.2 Supabase Edge Function secrets (server-side only — never in the Flutter env)

Set via the Supabase CLI per project (dev/staging/prod each configured separately):
```
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<...>       --project-ref <ref>
supabase secrets set TELE_MANAS_API_KEY=<...>               --project-ref <ref>
supabase secrets set ML_SERVICE_URL=https://<ml-svc>/       --project-ref <ref>
supabase secrets set ML_SERVICE_INTERNAL_TOKEN=<...>        --project-ref <ref>
supabase secrets set IDENTITY_VAULT_PROJECT_URL=<...>       --project-ref <ref>
supabase secrets set IDENTITY_VAULT_SERVICE_KEY=<...>       --project-ref <ref>
```

### 9.3 Identity-mapping vault project

Its own, entirely separate `.env`/secrets set (own `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`), stored only server-side in the re-identification broker Edge Function's secrets — never referenced from the main project's client or Edge Functions except through that one broker.

### 9.4 ML microservice (FastAPI) environment

```
# .env.example for the ML microservice (own deployment, not Supabase)
SUPABASE_URL=<same as main project, service-role access>
SUPABASE_SERVICE_ROLE_KEY=<...>
MODEL_ARTIFACT_PATH=/models/current
SYNTHETIC_DATA_MODE=true    # true in Phase 1, flip once real data volume is sufficient
LOG_LEVEL=info
```

### 9.5 `.gitignore` (add these immediately in Phase 1, before any real key exists)
```
env/.env.dev
env/.env.staging
env/.env.prod
**/.env
!**/.env.*.example
```

---

## 10. Deployment & Environment Topology

```
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│ manofit-dev      │   │ manofit-staging  │   │ manofit-prod     │
│ (Supabase project)│──▶│ (Supabase project)│──▶│ (Supabase project)│
└─────────────────┘   └─────────────────┘   └─────────────────┘
        ▲                       ▲                       ▲
        └───────────── CI/CD (GitHub Actions) ───────────┘
        Mobile: Flutter build → Play Store / TestFlight internal tracks
        Web (admin consoles): Flutter web build → hosting (e.g. Firebase
        Hosting / Vercel / Supabase-fronted static host)
        Backend: Supabase CLI migrations, environment-scoped secrets (§9)

┌───────────────────────────────────────────────────────┐
│ manofit-identity-vault (separate Supabase project,      │
│ separate environment per dev/staging/prod, own keys,     │
│ never shares a network boundary with the analytics DB)   │
└───────────────────────────────────────────────────────┘

ML microservice: containerized FastAPI, deployed independently, versioned
and rollback-able without touching Supabase.
```

- **Backups/DR**: automated Postgres backups per environment + periodic export to an isolated cold-storage bucket for prod and the identity-vault project.
- **Observability**: Supabase logs/metrics + the audit-log table feed the Oversight Board's access-audit view.

---

## 11. Non-Functional Requirements

| Category | Requirement |
|---|---|
| Availability | The AI companion/crisis-escalation path (Phase 2) has the highest uptime priority in the system — above dashboards or admin tooling. |
| Latency | Crisis classifier → Tele-MANAS notification: sub-second trigger, no UI animation delay on this path. |
| Scalability | Feature-engineering and model inference run as batch/async jobs, never on a user-facing request path. |
| Compliance | DPDP Act 2023 (India), GIGW/CERT-In guidelines. |
| Auditability | Every access to identifiable or near-identifiable data logged and traceable to a named, authorized actor. |
| Portability of ML core | Synthetic-to-real data swap (Phase 1 → later) requires zero pipeline code changes — schema parity is a hard requirement. |

---

## 12. Phase-to-Architecture Map (quick reference)

| Phase (see `manofit-prd.md` §9) | What gets built here |
|---|---|
| **Phase 1** | **ML/analytics layer as the largest slice (§6)** — engine, explainability, synthetic generator, validation/governance, graphical/predictive surfacing; data layer + RLS, identity vault, file-upload ingestion (`.xlsx`/`.csv` only), analytics-first HR Admin console (Flutter Web), Assessments (Flutter mobile) |
| **Phase 2** | Welfare Officer/Commander/Oversight consoles (§8 in PRD), live AI companion + crisis escalation (§7), Home + mood check-in |
| **Phase 3** | Self-Help/doodle, Book, Profile, workshop request, wearable integration (`health` package), motion polish, CI/CD hardening, DR |

---

*See `manofit-prd.md` for full requirements and the copy-pasteable Antigravity prompt. See `manofit-stitch-ui-prompt.md` for the UI design brief.*
