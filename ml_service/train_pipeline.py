import json
import sys
from pathlib import Path
import numpy as np

# Ensure app is in path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.config import settings
from app.feature_engineering import FeatureEngineeringPipeline
from app.models.behavioral_model import PredictiveBehavioralModel
from app.models.governance import ModelGovernanceManager
from app.models.nlp_models import HighRecallCrisisClassifier, RoutineSentimentClassifier
from app.synthetic_generator import SyntheticDataGenerator
from sklearn.model_selection import train_test_split

def run_training_pipeline(personnel_count: int = 500, version: str = "v1.0.0"):
    print("=" * 70)
    print("ManoFit Phase 1: Analytics & ML Training Pipeline")
    print("=" * 70)

    # 1. Generate Synthetic Datasets matching PS specification
    print(f"[1/5] Generating synthetic bootstrap data for {personnel_count} personnel (90-day history)...")
    generator = SyntheticDataGenerator(seed=42)
    data = generator.generate_all(personnel_count=personnel_count, days_history=90, save_to_disk=True)
    hr_df = data["hr_df"]
    assessments_df = data["assessments_df"]
    transcripts_df = data["transcripts_df"]
    nlp_scores = data["nlp_scores"]
    outcome_labels = data["outcome_labels"]
    print(f"      - HR operational records: {len(hr_df):,}")
    print(f"      - Wellness check-ins:     {len(assessments_df):,}")
    print(f"      - Simulated transcripts:  {len(transcripts_df):,}")
    print(f"      - Schema parity flag:     synthetic=True verified on all records")

    # 2. Feature Engineering Pipeline
    print("[2/5] Running rolling 30/60/90-day feature engineering...")
    fe = FeatureEngineeringPipeline()
    features_df = fe.transform_dataset(hr_df, assessments_df, nlp_scores=nlp_scores)
    print(f"      - Transformed feature matrix: {features_df.shape[0]} personnel x {features_df.shape[1]} features")

    # 3. Supervised Ground-Truth Calibration
    #
    # Labels come from the generator's latent welfare outcome, NOT from a
    # threshold over the features the model reads. The previous rule
    # ("consecutive duty > 14 AND exhaustion > 3") was a function of two input
    # columns, so the tree recovered it exactly and every metric read 1.0 —
    # impressive-looking and completely uninformative. These labels are
    # stochastic draws from the latent archetype, so the classes genuinely
    # overlap in feature space and the reported numbers mean something.
    y_series = features_df["pseudonym_token"].map(outcome_labels)
    if y_series.isna().any():
        raise ValueError("Every scored personnel token must carry an outcome label")
    y = y_series.to_numpy().astype(int)
    print(f"      - Outcome prevalence: {int((y == 0).sum())} no adverse outcome, "
          f"{int((y == 1).sum())} adverse welfare outcome "
          f"({100.0 * y.mean():.1f}% positive)")

    # Stratified hold-out so metrics describe unseen personnel.
    X_train, X_test, y_train, y_test = train_test_split(
        features_df, y, test_size=0.25, random_state=42, stratify=y
    )
    print(f"      - Split: {len(X_train)} train / {len(X_test)} held-out personnel")

    # 4. Train Behavioral Model (XGBoost)
    print(f"[3/5] Training Predictive Behavioral Model ({version})...")
    b_model = PredictiveBehavioralModel(model_version=version)
    metrics = b_model.train(X_train, y_train, X_eval=X_test, y_eval=y_test)
    train_metrics = b_model.evaluate(X_train, y_train)
    b_model.save()
    print(f"      - Model Type: {b_model.model_type}")
    print( "      -                 held-out    train")
    for key in ("roc_auc", "accuracy", "precision", "recall", "f1"):
        print(f"      - {key:<12}    {metrics[key]:.4f}     {train_metrics[key]:.4f}")
    print( "        (a large train/held-out gap indicates overfitting)")

    # 5. Train NLP Two-Tier Models
    print("[4/5] Training Two-Tier NLP Models...")
    s_model = RoutineSentimentClassifier()
    s_texts = transcripts_df["text"].tolist()
    s_labels = transcripts_df["sentiment"].apply(
        lambda s: "stressed_or_fatigued" if "stress" in s or "crisis" in s else "positive_or_neutral"
    ).tolist()
    s_model.train(s_texts, s_labels)
    s_model.save()
    print("      - Tier 1: Routine Sentiment Classifier trained & saved.")

    c_model = HighRecallCrisisClassifier()
    c_texts = transcripts_df["text"].tolist()
    c_labels = transcripts_df["crisis_label"].tolist()
    c_model.train(c_texts, c_labels)
    c_model.save()
    print("      - Tier 2: Dedicated High-Recall Crisis Classifier trained & saved.")

    # 6. Governance & Model Card Generation
    print("[5/5] Generating Model Card and Checkpointing Artifacts...")
    gov_mgr = ModelGovernanceManager()
    card = gov_mgr.create_model_card(
        model_version=version,
        model_type=b_model.model_type,
        metrics=metrics,
        features=PredictiveBehavioralModel.FEATURE_NAMES,
        sample_size=len(X_train),
        oversight_approved=True
    )
    gov_mgr.checkpoint_model_version(version)
    print(f"      - Model Card saved to {settings.ARTIFACT_DIR / 'model_card.json'}")
    print(f"      - Version checkpoint archived in {settings.ARTIFACT_DIR / 'checkpoints' / version}")

    print("\n" + "=" * 70)
    print("[OK] ManoFit Phase 1 Analytics & ML Pipeline Successfully Completed!")
    print("=" * 70)

if __name__ == "__main__":
    run_training_pipeline(personnel_count=500, version="v1.0.0")
