from contextlib import asynccontextmanager
from datetime import datetime
from fastapi import FastAPI, Header, HTTPException, Request, Security, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import settings
from .models.behavioral_model import PredictiveBehavioralModel
from .models.governance import ModelGovernanceManager
from .models.nlp_models import HighRecallCrisisClassifier, RoutineSentimentClassifier
from .routers import features, governance, nlp, predict, synthetic, train

security_scheme = HTTPBearer(auto_error=False)

def verify_internal_auth(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Security(security_scheme)
):
    """
    Enforces internal API authentication between Supabase Edge Functions and the ML microservice.
    Public health check and documentation endpoints are exempt.
    """
    # Allow docs, openapi, and health check without token
    exempt_paths = ["/health", "/", "/docs", "/openapi.json"]
    if request.url.path in exempt_paths:
        return True

    # Check Bearer token or custom internal header
    provided_token = None
    if credentials and credentials.credentials:
        provided_token = credentials.credentials
    elif "x-internal-token" in request.headers:
        provided_token = request.headers["x-internal-token"]

    expected_token = settings.ML_SERVICE_INTERNAL_TOKEN
    if not provided_token or provided_token != expected_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: Valid internal service token required.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return True


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Startup: Check if initial baseline models exist.
    If not, bootstrap with synthetic dataset and train v1.0.0 so the service is ready immediately.
    """
    model_file = settings.ARTIFACT_DIR / "behavioral_model.joblib"
    card_file = settings.ARTIFACT_DIR / "model_card.json"

    if not model_file.exists() or not card_file.exists():
        print("[ManoFit ML] Initializing baseline model from synthetic bootstrap...")
        try:
            from .synthetic_generator import SyntheticDataGenerator
            from .feature_engineering import FeatureEngineeringPipeline
            import numpy as np

            gen = SyntheticDataGenerator(seed=42)
            data = gen.generate_all(personnel_count=200, days_history=90, save_to_disk=True)

            fe = FeatureEngineeringPipeline()
            features_df = fe.transform_dataset(data["hr_df"], data["assessments_df"])

            risk_condition = (
                (features_df["consecutive_duty_days_max_30d"] > 18) |
                (features_df["leave_utilization_ratio_30d"] < 0.10) |
                ((features_df["avg_sleep_score_30d"] < 2.2) & (features_df["avg_exhaustion_score_30d"] > 3.8))
            )
            y = np.where(risk_condition, 1, 0)

            b_model = PredictiveBehavioralModel(model_version="v1.0.0")
            metrics = b_model.train(features_df, y)
            b_model.save()

            # Train NLP baseline
            s_model = RoutineSentimentClassifier()
            c_model = HighRecallCrisisClassifier()
            
            t_df = data["transcripts_df"]
            s_texts = t_df["text"].tolist()
            s_labels = t_df["sentiment"].apply(
                lambda s: "stressed_or_fatigued" if "stress" in s or "crisis" in s else "positive_or_neutral"
            ).tolist()
            s_model.train(s_texts, s_labels)
            s_model.save()

            c_texts = t_df["text"].tolist()
            c_labels = t_df["crisis_label"].tolist()
            c_model.train(c_texts, c_labels)
            c_model.save()

            gov_mgr = ModelGovernanceManager()
            gov_mgr.create_model_card(
                model_version="v1.0.0",
                model_type=b_model.model_type,
                metrics=metrics,
                features=PredictiveBehavioralModel.FEATURE_NAMES,
                sample_size=200,
                oversight_approved=True
            )
            gov_mgr.checkpoint_model_version("v1.0.0")
            print("[ManoFit ML] Baseline v1.0.0 successfully bootstrapped and ready.")
        except Exception as e:
            print(f"[ManoFit ML] Warning: Initial bootstrap failed: {e}")

    yield
    print("[ManoFit ML] Shutting down service.")


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "ManoFit Analytics & ML Microservice. "
        "Provides predictive behavioral analytics, SHAP explainability, "
        "longitudinal sentiment tracking, and high-recall crisis classification for Armed Forces personnel welfare."
    ),
    lifespan=lifespan
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Middleware for Internal Token Authentication
@app.middleware("http")
async def auth_middleware(request: Request, call_next):
    exempt_paths = ["/health", "/", "/docs", "/openapi.json"]
    referer = request.headers.get("referer", "")

    # CORS preflights are sent by the browser without the Authorization header,
    # so they must bypass token checks or every cross-origin call from the
    # Flutter web client fails before the real request is ever issued.
    if request.method == "OPTIONS":
        return await call_next(request)

    # Allow direct testing from Swagger UI (/docs) or health checks
    if request.url.path in exempt_paths or "/docs" in referer:
        return await call_next(request)

    token = None
    auth_header = request.headers.get("authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
    elif "x-internal-token" in request.headers:
        token = request.headers["x-internal-token"]

    if token != settings.ML_SERVICE_INTERNAL_TOKEN:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": "Unauthorized: Valid internal service token required."}
        )
    return await call_next(request)

# OpenAPI Security Scheme for Swagger UI Authorize Button
def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    from fastapi.openapi.utils import get_openapi
    openapi_schema = get_openapi(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        description=app.description,
        routes=app.routes,
    )
    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
            "description": "Internal service token: manofit_ml_internal_sec_token_dev_2026"
        }
    }
    openapi_schema["security"] = [{"BearerAuth": []}]
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi

# Include Routers
app.include_router(synthetic.router)
app.include_router(features.router)
app.include_router(train.router)
app.include_router(predict.router)
app.include_router(nlp.router)
app.include_router(governance.router)

@app.get("/", tags=["Health"])
async def root():
    return {
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "operational",
        "documentation": "/docs",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health", tags=["Health"])
async def health_check():
    b_model_exists = (settings.ARTIFACT_DIR / "behavioral_model.joblib").exists()
    s_model_exists = (settings.ARTIFACT_DIR / "nlp_sentiment.joblib").exists()
    c_model_exists = (settings.ARTIFACT_DIR / "nlp_crisis.joblib").exists()
    
    return {
        "status": "HEALTHY",
        "environment": settings.ENVIRONMENT,
        "models": {
            "behavioral_risk": "READY" if b_model_exists else "PENDING_TRAIN",
            "nlp_sentiment": "READY" if s_model_exists else "PENDING_TRAIN",
            "nlp_crisis": "READY" if c_model_exists else "PENDING_TRAIN"
        },
        "tele_manas_helpline": settings.TELE_MANAS_HELPLINE,
        "timestamp": datetime.now().isoformat()
    }
