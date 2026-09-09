import unittest
import numpy as np
import pandas as pd
from app.feature_engineering import FeatureEngineeringPipeline
from app.models.behavioral_model import PredictiveBehavioralModel
from app.synthetic_generator import SyntheticDataGenerator

class TestBehavioralModel(unittest.TestCase):
    def setUp(self):
        generator = SyntheticDataGenerator(seed=42)
        data = generator.generate_all(personnel_count=60, days_history=90, save_to_disk=False)
        fe = FeatureEngineeringPipeline()
        self.features_df = fe.transform_dataset(data["hr_df"], data["assessments_df"])
        
        # Synthetic risk condition for testing (elevated duty + high exhaustion)
        risk_condition = (
            (self.features_df["consecutive_duty_days_max_30d"] > 14) &
            (self.features_df["avg_exhaustion_score_30d"] > 3.0)
        )
        self.y = np.where(risk_condition, 1, 0)
        # Ensure at least both classes exist for classifier
        if len(np.unique(self.y)) < 2:
            self.y[0] = 0
            self.y[-1] = 1
        self.model = PredictiveBehavioralModel(model_version="test-v1")

    def test_train_and_predict(self):
        metrics = self.model.train(self.features_df, self.y)
        self.assertIn("accuracy", metrics)
        self.assertIn("roc_auc", metrics)
        self.assertGreater(metrics["roc_auc"], 0.70)

        # Predict single feature set
        first_row = self.features_df.iloc[0]
        fe = FeatureEngineeringPipeline()
        fs = fe.extract_features_for_personnel(
            pseudonym_token=first_row["pseudonym_token"],
            hr_df=pd.DataFrame(),
            assessments_df=pd.DataFrame()
        )
        # Update fs with row values
        fs_dict = fs.model_dump()
        for col in PredictiveBehavioralModel.FEATURE_NAMES:
            fs_dict[col] = float(first_row[col])
        from app.schemas import FeatureSet
        fs_updated = FeatureSet(**fs_dict)

        prob, factors = self.model.predict_risk_probability(fs_updated)
        self.assertGreaterEqual(prob, 0.0)
        self.assertLessEqual(prob, 1.0)
        self.assertGreater(len(factors), 0)
        self.assertLessEqual(len(factors), 5)
        self.assertIn(factors[0].direction, ["risk_increasing", "protective"])

if __name__ == "__main__":
    unittest.main()
