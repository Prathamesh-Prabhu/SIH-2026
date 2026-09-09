# ManoFit Analytics & ML Microservice (Phase 1 — Part 5)

**Tech Stack**: Python 3.14+, FastAPI, XGBoost, Scikit-learn, Pandas, NumPy, Pydantic.

This microservice constitutes **Part 5: Analytics & ML Layer** of the **ManoFit** personnel stress and welfare monitoring platform, built in strict conformance with `manofit-prd.md` and `manofit-architecture.md`.

---

## 1. Key Architectural Principles Enforced

1. **Strict Pseudonymization & Privacy**:
   - The ML service operates exclusively on pseudonymized tokens (`TOKEN-xxxxxx`), derived rolling features, and private wellness survey scores.
   - It **never** receives names, service/PF numbers, or disciplinary/medical records.
2. **Schema Parity**:
   - Synthetic datasets generated offline match the real production ingestion pipeline 1:1.
   - Every synthetic record carries `synthetic: true`.
   - Swapping real anonymized data for synthetic data requires zero code changes.
3. **No Raw Algorithmic Scores Exposed**:
   - Neither personnel nor commanding officers are shown raw numeric probabilities.
   - Outputs are strictly categorized into clinical **Risk Bands** (`LOW`, `MODERATE`, `ELEVATED`) alongside top contributing factors (SHAP-style explainability) for Welfare Officers.
4. **Two-Tier NLP Architecture**:
   - **Tier 1 (Routine Sentiment)**: Tracks everyday conversational valence, stress, and fatigue indicators.
   - **Tier 2 (High-Recall Crisis Classifier)**: Tuned for maximum sensitivity to detect acute despair, burdensomeness, or self-harm cues (catching both direct and subtle/indirect phrasing). Immediately dispatches the **Tele-MANAS (14416)** escalation payload and guides the AI companion with calm, non-terminating stabilization prompts.
5. **Decoupled Internal Microservice**:
   - Runs independently from the Flutter client.
   - Callable from Supabase Edge Functions over an authenticated internal API using `ML_SERVICE_INTERNAL_TOKEN`.

---

## 2. Directory Structure

```
ml_service/
├── app/
│   ├── config.py                     # App configuration & thresholds
│   ├── schemas.py                    # Strict Pydantic models (data, scoring, NLP, governance)
│   ├── synthetic_generator.py        # Problem statement compliant synthetic dataset generator
│   ├── feature_engineering.py        # 30/60/90-day rolling window pipeline
│   ├── main.py                       # FastAPI app, auth middleware, health check
│   ├── models/
│   │   ├── behavioral_model.py       # XGBoost risk model + factor explainability
│   │   ├── nlp_models.py             # Tier 1 (Sentiment) + Tier 2 (High-Recall Crisis)
│   │   ├── ensemble.py               # Clinical ensemble scoring (Low/Moderate/Elevated)
│   │   └── governance.py             # Model card generation, checkpoints, & rollback
│   └── routers/
│       ├── synthetic.py              # POST /api/v1/synthetic/generate
│       ├── features.py               # POST /api/v1/features/transform
│       ├── train.py                  # POST /api/v1/models/train
│       ├── predict.py                # POST /api/v1/score/predict & /score/batch
│       ├── nlp.py                    # POST /api/v1/nlp/sentiment & /nlp/crisis
│       └── governance.py             # GET /api/v1/governance/model-card & /rollback
├── artifacts/                        # Trained model binaries, scalers, active model card
│   ├── behavioral_model.joblib       # Serialized XGBoost model
│   ├── nlp_sentiment.joblib          # Serialized Tier 1 NLP model
│   ├── nlp_crisis.joblib             # Serialized Tier 2 Crisis model
│   ├── model_card.json               # Active compliant Model Card
│   └── checkpoints/                  # Versioned checkpoints (e.g. v1.0.0/)
├── data/                             # Generated synthetic datasets
│   ├── synthetic_hr_records.csv      # 45,000 operational records (500 personnel x 90 days)
│   ├── synthetic_assessments.csv     # 3,500 periodic wellness check-ins
│   └── synthetic_transcripts.jsonl   # 1,000 simulated companion utterances
├── tests/                            # Comprehensive unit & integration tests
│   ├── test_synthetic.py
│   ├── test_feature_engineering.py
│   ├── test_behavioral_model.py
│   ├── test_nlp_models.py
│   ├── test_ensemble.py
│   └── test_api.py
├── train_pipeline.py                 # End-to-end training & checkpointing script
├── run_server.py                     # Microservice server launcher
├── requirements.txt                  # Python dependencies
└── .env.example                      # Environment template
```

---

## 3. Quick Start & Execution

### Running the Full Test Suite
```bash
# From workspace root
$env:PYTHONPATH="ml_service"
python -m unittest discover -s ml_service/tests -p "test_*.py"
```
*All 16 unit and API integration tests execute and pass.*

### Running the End-to-End Training Pipeline
```bash
python ml_service/train_pipeline.py
```
This generates 500 synthetic personnel profiles, computes 30/60/90-day rolling features, trains the XGBoost behavioral model, trains the two NLP models, outputs the official `model_card.json`, and creates a versioned checkpoint.

### Launching the FastAPI Microservice
```bash
python ml_service/run_server.py
```
The server will bind to `http://0.0.0.0:8000`. Interactive OpenAPI documentation is available at `http://localhost:8000/docs`.

---

## 4. API Endpoints Overview

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/health` | Service health status & model readiness | No |
| `POST` | `/api/v1/synthetic/generate` | Generate schema-matched synthetic data | Yes (`Bearer <TOKEN>`) |
| `POST` | `/api/v1/features/transform` | Compute 30/60/90-day rolling features | Yes |
| `POST` | `/api/v1/models/train` | Retrain models and generate Model Card | Yes |
| `POST` | `/api/v1/score/predict` | Single personnel ensemble risk assessment | Yes |
| `POST` | `/api/v1/score/batch` | Batch assessment for unit dashboards | Yes |
| `POST` | `/api/v1/nlp/sentiment` | Tier 1 routine sentiment & fatigue check | Yes |
| `POST` | `/api/v1/nlp/crisis` | Tier 2 high-recall crisis & Tele-MANAS alert | Yes |
| `GET` | `/api/v1/governance/model-card` | View active Model Card & metrics | Yes |
| `POST` | `/api/v1/governance/rollback` | Rollback to earlier checkpoint version | Yes |
| `POST` | `/api/v1/governance/clinical-sample` | Sample balanced cohort for monthly clinical review | Yes |

---

## 5. Tele-MANAS (14416) Escalation Protocol

When `POST /api/v1/nlp/crisis` identifies direct or indirect crisis patterns:
- Response emits:
  ```json
  {
    "crisis_detected": true,
    "crisis_probability": 0.85,
    "risk_indicators_detected": [
      "Perceived burdensomeness on comrades or family (detected cue: 'better off without me')"
    ],
    "escalation": {
      "trigger": true,
      "helpline": "14416",
      "priority": "IMMEDIATE_ESCALATION",
      "recommended_action": "Notify Tele-MANAS (14416) in parallel; alert unit duty Welfare Officer for immediate supportive human check-in."
    },
    "stabilizing_response_hint": "I hear how heavy this feels right now, and I am right here with you. You don't have to carry this alone..."
  }
  ```
- The companion interface is instructed to remain calm and never abruptly disconnect.
- The risk scoring engine automatically elevates the individual's risk band to `ELEVATED` with top attribution prioritizing the detected crisis cue.
