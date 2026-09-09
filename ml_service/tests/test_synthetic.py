import unittest
import pandas as pd
from app.synthetic_generator import SyntheticDataGenerator

class TestSyntheticGenerator(unittest.TestCase):
    def setUp(self):
        self.generator = SyntheticDataGenerator(seed=123)

    def test_generate_all(self):
        res = self.generator.generate_all(personnel_count=20, days_history=30, save_to_disk=False)
        hr_df = res["hr_df"]
        assessments_df = res["assessments_df"]
        transcripts_df = res["transcripts_df"]

        # 1. Row counts
        self.assertGreater(len(hr_df), 0)
        self.assertGreater(len(assessments_df), 0)
        self.assertGreater(len(transcripts_df), 0)

        # 2. Hard requirement: Every synthetic record carries synthetic == True
        self.assertTrue((hr_df["synthetic"] == True).all(), "All HR records must carry synthetic: True")
        self.assertTrue((assessments_df["synthetic"] == True).all(), "All assessments must carry synthetic: True")
        self.assertTrue((transcripts_df["synthetic"] == True).all(), "All transcripts must carry synthetic: True")

        # 3. Check 6 wellness check-in dimensions
        required_assessment_cols = [
            "workload_perception", "mood_rating", "manager_relationship",
            "sleep_quality", "physical_exhaustion", "peer_social_support"
        ]
        for col in required_assessment_cols:
            self.assertIn(col, assessments_df.columns)
            self.assertTrue((assessments_df[col] >= 1).all() and (assessments_df[col] <= 5).all(), f"Values for {col} must be in range 1..5")

        # 4. Check HR operational fields
        required_hr_cols = [
            "pseudonym_token", "record_date", "unit_code", "location_tier",
            "shift_hours", "is_rest_day", "leave_taken_days", "leave_balance_days",
            "consecutive_active_days", "transfer_count_last_12m", "training_load_hours"
        ]
        for col in required_hr_cols:
            self.assertIn(col, hr_df.columns)

if __name__ == "__main__":
    unittest.main()
