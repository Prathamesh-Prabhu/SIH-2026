import unittest
import pandas as pd
from app.feature_engineering import FeatureEngineeringPipeline
from app.synthetic_generator import SyntheticDataGenerator

class TestFeatureEngineering(unittest.TestCase):
    def setUp(self):
        generator = SyntheticDataGenerator(seed=42)
        data = generator.generate_all(personnel_count=10, days_history=90, save_to_disk=False)
        self.hr_df = data["hr_df"]
        self.assessments_df = data["assessments_df"]
        self.pipeline = FeatureEngineeringPipeline()

    def test_extract_features_for_personnel(self):
        token = self.hr_df["pseudonym_token"].iloc[0]
        fs = self.pipeline.extract_features_for_personnel(
            pseudonym_token=token,
            hr_df=self.hr_df,
            assessments_df=self.assessments_df
        )

        self.assertEqual(fs.pseudonym_token, token)
        self.assertGreaterEqual(fs.consecutive_duty_days_max_30d, 0.0)
        self.assertGreaterEqual(fs.leave_utilization_ratio_30d, 0.0)
        self.assertLessEqual(fs.leave_utilization_ratio_30d, 1.0)
        self.assertGreaterEqual(fs.composite_assessment_score_30d, 1.0)
        self.assertLessEqual(fs.composite_assessment_score_30d, 5.0)
        self.assertTrue(fs.synthetic)

    def test_transform_dataset_parity(self):
        features_df = self.pipeline.transform_dataset(self.hr_df, self.assessments_df)
        self.assertEqual(len(features_df), 10)
        for col in FeatureEngineeringPipeline.FEATURE_COLUMNS:
            self.assertIn(col, features_df.columns, f"Feature column {col} must exist in transformed dataset")

if __name__ == "__main__":
    unittest.main()
