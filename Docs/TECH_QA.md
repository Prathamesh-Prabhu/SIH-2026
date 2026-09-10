# ManoFit — Probable Technical Questions & Answers

Prep sheet for the SIH viva / panel. Answers are written to be said out loud in
20–40 seconds each. Know the **bold** line even if you forget the rest.

---

## A. Architecture & system design

**Q. Give me a 30-second architecture overview.**
A single **Flutter** codebase (mobile for personnel, web build for the admin
consoles) talks to **Supabase** — Postgres with Row-Level Security, Auth,
Storage, Edge Functions. Two decoupled services sit behind it: a **Python /
FastAPI ML microservice** for the predictive risk engine, and a **Node relay**
for the Tara voice companion that fronts Google's Gemini Live API. Crisis
signals route out to **Tele-MANAS 14416**. **The design rule is that data only
flows downward through a privacy layer — no console ever queries raw personal
data.**

**Q. Why three separate services instead of one backend?**
Separation of concerns and blast radius. Supabase is the system of record and
does auth + RLS out of the box. The **ML core is deliberately decoupled** because
model depth is our top priority — it has to be independently trainable, testable
and swappable (real anonymised data ↔ synthetic, no code change). The **Tara
relay is separate because the Gemini API key must never be in the APK** — the
phone only speaks to our WebSocket.

**Q. Why Flutter?**
One codebase, five clients. The personnel app (Android/iOS) and all four admin
consoles (`flutter build web`) are the *same* project with role-scoped routing —
we don't maintain a separate React admin app. Native performance, Material 3,
and a mature package ecosystem (`supabase_flutter`, `webview_flutter`,
`audioplayers`).

**Q. Why Supabase over Firebase or a custom backend?**
We needed **relational data with hard row-level access rules** — a soldier's
data, pseudonymised HR features, and risk output all live in one Postgres DB but
must be invisible across roles. Postgres **Row-Level Security** enforces that at
the database, not in app code. Firebase's security rules are far weaker for
relational, multi-role data. A custom backend would be months of auth/RLS
plumbing we'd get wrong.

**Q. How does a request actually flow when a soldier submits a check-in?**
Flutter → `supabase_flutter` SDK → `INSERT` into `assessments` over TLS. RLS
checks `auth.uid() = user_id`. The row also carries the six domain scores as
columns. The HR org-wellbeing roll-up reads only the **anonymised** aggregate of
those columns — never `user_id`. If the ML service is scoring, an Edge Function
passes pseudonym-keyed features to it over an authenticated internal API.

**Q. What happens if the ML service / Tara service is down?**
Graceful degradation. The app falls back to **on-device heuristics** for risk
banding and shows an "offline" state; Tara shows a reconnect panel and the text
chat retries. Nothing crashes, no feature hard-fails.

---

## B. Flutter / frontend

**Q. State management?**
`provider` + `ChangeNotifier` services (`AuthService`, `DbService`,
`SupabaseService`, `MlService`) exposed via `MultiProvider` at the root. Screens
`watch` what they need. It's simple, testable, and enough for this app's scale —
no need for Bloc/Riverpod ceremony.

**Q. Routing and how do you stop an HR Admin opening a personnel screen?**
`go_router` with a global `redirect`. `RoleAccess.routeRoles` maps each route to
the roles allowed to open it; deep-linking anything else bounces the user to
their own console. **This mirrors — never replaces — Postgres RLS; the server is
still the enforcement point.** The client guard just avoids rendering a board the
user shouldn't see.

**Q. How is the app configured — where do secrets live?**
`flutter_dotenv` reads a bundled `.env` for **non-secret** client config
(Supabase URL + anon key, service endpoint URLs). **True secrets — the Gemini
key, the ML internal token — never touch the client**; they live in the Render
services and Supabase. The anon key is safe to ship because RLS gates everything.

**Q. The meditation player streams audio — how, and what about offline?**
`audioplayers` with `ReleaseMode.loop`, streaming royalty-free ambience from
Google's free Sound Library over HTTPS. On failure the session still runs as a
silent guided timer with a small notice. Users can bundle their own tracks under
`assets/audio/` and point a session at them with `assetPath`.

**Q. Tara is a WebView — why not native?**
Gemini Live is audio-to-audio over a WebSocket with Web Audio API capture/
playback. A tiny web UI in the relay does exactly that; embedding it in a
`WebView` reuses one implementation for Android, iOS and web. A JS bridge
(`CrisisChannel`) forwards crisis events to the Flutter host. Mic needs a secure
context (HTTPS or `localhost`), which is why the relay runs over HTTPS on Render.

**Q. How do you handle the streak so Home and Profile agree?**
One source of truth: `DbService.currentStreak()` counts the run of **consecutive
days** (ending today, or yesterday if nothing's logged yet) with any mood /
mindfulness / check-in entry, with the server's stored streak as a floor. Both
screens call the same method.

---

## C. Database & backend

**Q. Walk me through the schema.**
Personal: `profiles`, `mood_logs`, `assessments`, `mindfulness_logs`,
`mindfulness_moods`, `self_help_logs`, `counseling_sessions`. Organisational:
`hr_ingestion_logs`, `hr_features` (pseudonymised). Risk & safety:
`crisis_alerts`, `audit_logs`. Ops: `system_config` (dynamic service
endpoints). Every table has RLS policies scoped to the role that legitimately
needs it.

**Q. Show me a Row-Level Security example.**
`assessments`: `FOR SELECT USING (auth.uid() = user_id)` and
`FOR INSERT WITH CHECK (auth.uid() = user_id)` — a soldier only ever sees their
own rows. `hr_features` is readable only by the ML service role and the
Oversight audit role. `crisis_alerts` is Welfare-Officer-only. `audit_logs` is
append-only, Oversight read-only.

**Q. How does authentication work with "Service ID" instead of email?**
We map a Service/PF number to a deterministic synthetic email
(`<slug>@manofit.app`) and use Supabase email/password auth under the hood, so
we get real JWT sessions, refresh, and `auth.uid()` for RLS — without asking a
soldier for an email.

**Q. Assessments have per-cadence question banks now — how is that stored
without breaking the ML contract?**
The **six core domains** are fixed columns (`workload_perception`,
`sleep_quality`, `physical_exhaustion`, `mood_rating`, `manager_relationship`,
`peer_social_support`) — that's the ML contract and it's untouched. Daily uses a
subset, weekly all six, monthly all six **plus four reflective domains** that
ride along in the `answers` JSONB blob only. The org roll-up reads the six
columns; the HR "monthly deep-dive" reads the blob.

**Q. Why file upload only for HR data — no API connector?**
Deliberate, per the problem statement. CAPF HRMS systems are on isolated
networks; a live connector is an integration and a security surface we can't
own. A **one-way `.xlsx` / `.csv` upload** that pseudonymises on arrival keeps
the platform's threat model simple and auditable.

---

## D. Machine learning / analytics

**Q. What model, and why?**
A **channel-routed gradient-boosted ensemble (XGBoost)** with **isotonic
calibration**. Gradient boosting handles heterogeneous tabular features
(counts, rates, ordinals) with non-linear interactions well, trains fast, and is
**explainable** with SHAP — which matters because a Welfare Officer must see
*why* a case is flagged. Calibration makes the probability trustworthy before we
bucket it.

**Q. You train on synthetic data — isn't the model meaningless?**
The synthetic generator is a **latent-variable model**: a hidden "true stress"
variable drives both the operational signals (consecutive duty days, low leave,
frequent redeployment) and the self-reports, with realistic noise. So the model
learns the *relationships the domain says exist*. Critically, **the synthetic
schema is 1:1 with the real ingestion pipeline** — the moment a real anonymised
roster is available, it drops in with zero code change and retrains. Synthetic
data is a scaffold for the pipeline and the demo, not the final model.

**Q. What are the features?**
≈32 pseudonym-traceable features over **30 / 60 / 90-day rolling windows**:
consecutive active days, weekly duty hours, leave balance and utilisation,
redeployment frequency, time at current posting, training load, rest-day
cadence, plus the six self-report domains. No names, no PF numbers, no
medical/disciplinary data ever reach the model.

**Q. Why never show the raw score?**
Two reasons. **Clinical**: a probability like 0.62 invites amateur triage and
stigma. **Ethical / PRD**: personnel see nothing about themselves; a Welfare
Officer sees a **band** (Low / Moderate / Elevated) + factors, which is
actionable without being a label. Commanders see only unit aggregates.

**Q. How does crisis detection work and what's the false-positive stance?**
Two-tier NLP. Tier 1 tracks routine sentiment. **Tier 2 is a high-recall crisis
classifier** — tuned for sensitivity over precision on purpose, because a missed
crisis is catastrophic and a false alarm is cheap (a supportive check-in). In
the live Tara path we also run a fast **regex lexicon** (English + romanised and
Devanagari Hindi) on the speech transcript for instant escalation. A hit writes
a `crisis_alerts` row and surfaces Tele-MANAS 14416.

**Q. How is the model governed?**
A generated **model card** (version, metrics, training-data description),
versioned checkpoints, and **one-file rollback**. The Oversight Board console is
the read surface for this.

**Q. Differential privacy for commanders — concretely?**
A Commander view only renders a metric if the contributing cohort is **> 25
personnel** (k-anonymity), and figures are unit-level aggregates. No drill-down
to an individual exists in that console, and no combination of visible numbers
re-identifies one.

---

## E. Generative AI / Tara

**Q. Which model, and how is the key protected?**
Google **Gemini Live** (native audio-to-audio) for voice, Gemini text model for
chat. The key lives only in the **Node relay** on Render. The phone opens a
WebSocket to the relay; the relay holds the single Gemini session. The APK
contains no Gemini credentials.

**Q. How is multilingual handled — does the model auto-detect?**
Native-audio Gemini models auto-detect language, so for **Auto** mode we don't
force a language code and the system instruction says "mirror the user, Hindi /
English / Hinglish". For **pinned** EN/HI we also pass a BCP-47
`languageCode` (`en-IN` / `hi-IN`) for half-cascade compatibility. The persona
is one language-neutral block with a per-conversation language rule prepended.

**Q. What stops Tara from giving harmful/clinical advice?**
The system instruction makes it explicitly **non-clinical** — a companion, not a
therapist — and mandates a calm, **non-terminating** bridge to Tele-MANAS or a
Welfare Officer on any self-harm cue. The server-side crisis scan is independent
of the model, so escalation doesn't depend on the LLM behaving.

**Q. Latency / cost concerns with a live voice model?**
The relay measures response latency per turn. Cost is bounded by session length;
the client auto-hangs-up on backgrounding and after ~90s of silence so calls
don't run unattended. Text chat uses the cheaper non-Live model.

---

## F. Privacy, security & ethics

**Q. What's the single biggest privacy risk and how do you mitigate it?**
**Re-identification** — linking a pseudonymised risk flag back to a person. The
identity map is designed as a **separate Supabase project** reachable only
through a broker Edge Function that enforces **two-person authorisation + audit
logging**. The analytics DB physically cannot join to a name.

**Q. Is it DPDP Act 2023 compliant?**
It's built to align: explicit consent with a **consent-audit ledger**, purpose
limitation (data is only for welfare), data minimisation (no medical/
disciplinary fields), an in-app data-governance explainer, and role-scoped
access. Full compliance is an organisational/legal process, not just code.

**Q. The anon Supabase key is in the app — isn't that a leak?**
No. The anon key only grants what **RLS policies** allow — which for an
unauthenticated caller is nothing sensitive, and for an authenticated soldier is
only their own rows. That's the intended Supabase model. Real secrets are
server-side.

**Q. Could a commander pressure a soldier using this data?**
By design, no: a Commander console has **no individual data and no drill-down**.
Welfare casework is a separate, licensed role. Nothing a soldier logs reaches
the chain of command — that's the product's core promise and it's enforced by
RLS, not policy.

**Q. Audit logging?**
`audit_logs` is append-only, Oversight-Board read-only. Sensitive actions —
re-identification requests, model rollbacks, alert dispatch — are designed to
write immutable entries.

---

## G. Scalability, deployment, DevOps

**Q. How does this scale to lakhs of personnel?**
Supabase/Postgres scales vertically and with read replicas; the heavy tables
(`assessments`, `mindfulness_logs`) are append-mostly and indexed by
`(user_id, created_at)`. The ML service is **stateless** and horizontally
scalable behind a load balancer; scoring is batched
(`/score/batch`). Tara sessions are independent WebSocket connections — scale
the relay horizontally.

**Q. How is it deployed?**
`render.yaml` defines the Tara service (Node) and ML service (Python) as Render
web services. The Flutter app builds to an APK / web bundle. Architecture calls
for **isolated dev / staging / prod Supabase projects** — separate projects, not
config flags.

**Q. CI/CD?**
`flutter analyze` gates every change (it's clean); the ML service has a unit +
integration test suite (`pytest`) covering synthetic generation, feature
engineering, the behavioral model, NLP, ensemble and the API.

**Q. Offline support on the mobile app?**
Personal writes are cached locally (`shared_preferences`) and the UI updates
optimistically; rows sync when the connection returns. The HR cohort and
ingestion history persist locally so each upload *adds* rather than replaces.

---

## H. Testing & quality

**Q. How do you test the ML pipeline?**
`ml_service/tests/` — `test_synthetic.py`, `test_feature_engineering.py`,
`test_behavioral_model.py`, `test_nlp_models.py`, `test_ensemble.py`,
`test_api.py`. Synthetic determinism, feature-window correctness, band
thresholds, crisis-recall, and endpoint contracts.

**Q. How do you validate crisis detection quality?**
Recall-first: the transcript test set includes **indirect** phrasing
("I'm a burden", "everyone's better off without me"), not just explicit
statements, and the bar is catching those. Precision is secondary by design.

---

## I. Likely "gotcha" questions

**Q. What's *not* finished?**
Honest answer: some Commander trend figures use a fixed demo dataset where the
endpoint isn't wired; the separate identity vault + re-identification broker is
architected but not deployed as a second live project; Tele-MANAS is a dialer +
escalation record, not a production API handshake; wearables are Phase 3. The
**core loop — check-ins → pseudonymised analytics → banded risk → Welfare
Officer / Tele-MANAS, plus Tara and mindfulness — works end to end.**

**Q. If you had one more week, what would you build?**
Deploy the identity vault + two-person re-identification broker, and wire the
Commander trend endpoints to real aggregates so nothing on screen is demo data.

**Q. Why should a soldier trust this?**
Because the guarantee is **structural, not a promise**: RLS makes their data
unreadable to command; the analytics DB has no path to their name; and they see
zero risk output about themselves. The architecture is the trust.

**Q. Biggest technical risk in production?**
Getting RLS policies exactly right across every table and every role — one
over-permissive policy breaks the whole privacy model. It needs a dedicated
security review and policy tests before any real data.

**Q. What did you learn / what was hardest?**
Designing the **privacy layer as the primary constraint** — every feature had to
be checked against "can this leak an individual to the wrong role?" — and
building an ML pipeline that's genuinely swappable between synthetic and real
data.
