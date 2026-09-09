import os
from pathlib import Path
from pydantic import BaseModel

BASE_DIR = Path(__file__).resolve().parent.parent

class Settings(BaseModel):
    # Service Information
    APP_NAME: str = "ManoFit Analytics & ML Service"
    APP_VERSION: str = "1.0.0"
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "info")
    
    # Network
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    
    # Internal Authentication
    # Required for Edge Function communication
    ML_SERVICE_INTERNAL_TOKEN: str = os.getenv(
        "ML_SERVICE_INTERNAL_TOKEN", 
        "manofit_ml_internal_sec_token_dev_2026"
    )
    
    # Storage Paths
    ARTIFACT_DIR: Path = BASE_DIR / os.getenv("ARTIFACT_DIR", "artifacts")
    DATA_DIR: Path = BASE_DIR / os.getenv("DATA_DIR", "data")
    
    # Supabase Connection (Optional / for direct sync if configured)
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    
    # Clinical Risk Band Thresholds
    RISK_THRESHOLD_MODERATE: float = float(os.getenv("RISK_THRESHOLD_MODERATE", "0.35"))
    RISK_THRESHOLD_ELEVATED: float = float(os.getenv("RISK_THRESHOLD_ELEVATED", "0.65"))
    
    # High-Recall Crisis Detection Threshold (Tuned for maximum sensitivity)
    CRISIS_RECALL_THRESHOLD: float = float(os.getenv("CRISIS_RECALL_THRESHOLD", "0.40"))
    
    # Tele-MANAS National Helpline Number
    TELE_MANAS_HELPLINE: str = "14416"
    
    # Synthetic Generator Defaults
    SYNTHETIC_DATA_MODE: bool = os.getenv("SYNTHETIC_DATA_MODE", "true").lower() == "true"
    DEFAULT_SYNTHETIC_PERSONNEL_COUNT: int = 500

settings = Settings()

# Ensure directories exist
settings.ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
settings.DATA_DIR.mkdir(parents=True, exist_ok=True)
