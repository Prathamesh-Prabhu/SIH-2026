import unittest
import pandas as pd
from app.feature_engineering import FeatureEngineeringPipeline
from app.models.behavioral_model import PredictiveBehavioralModel
from app.models.ensemble import WelfareEnsembleEngine
from app.models.nlp_models import HighRecallCrisisClassifier, RoutineSentimentClassifier
from app.schemas import FeatureSet, RiskBand, ScorePredictionRequest

class TestEnsemble(unittest.TestCase):
    def setUp(self):
        self.b_model = PredictiveBehavioralModel()
        self.s_model = RoutineSentimentClassifier()
        self.c_model = HighRecallCrisisClassifier()
        self.engine = WelfareEnsembleEngine(self.b_model, self.s_model, self.c_model)

    def test_risk_band_mapping(self):
        fe = FeatureEngineeringPipeline()
        fs_resilient = fe.extract_features_for_personnel(
            pseudonym_token="TEST-001",
            hr_df=pd.DataFrame(),
            assessments_df=pd.DataFrame(),
            nlp_sentiment_score=0.1
        )
        req = ScorePredictionRequest(pseudonym_token="TEST-001", features=fs_resilient)
        resp = self.engine.evaluate_personnel(req, fs_resilient)
        
        # Risk band must be one of LOW, MODERATE, ELEVATED
        self.assertIn(resp.risk_band, [RiskBand.LOW, RiskBand.MODERATE, RiskBand.ELEVATED])
        self.assertGreaterEqual(resp.confidence, 0.5)
        self.assertGreater(len(resp.recommended_support_pathway), 10)

    def test_crisis_override_elevation(self):
        fe = FeatureEngineeringPipeline()
        fs = fe.extract_features_for_personnel("TEST-CRISIS", pd.DataFrame(), pd.DataFrame())
        req = ScorePredictionRequest(
            pseudonym_token="TEST-CRISIS", 
            features=fs,
            recent_crisis_cue_detected=True
        )
        resp = self.engine.evaluate_personnel(req, fs)
        self.assertEqual(resp.risk_band, RiskBand.ELEVATED)
        self.assertEqual(resp.top_factors[0].factor_name, "crisis_cue_detected")

if __name__ == "__main__":
    unittest.main()
