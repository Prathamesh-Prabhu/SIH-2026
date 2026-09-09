import unittest
from fastapi.testclient import TestClient
from app.main import app
from app.config import settings

class TestAPIEndpoints(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        cls.auth_headers = {
            "Authorization": f"Bearer {settings.ML_SERVICE_INTERNAL_TOKEN}"
        }

    def test_health_check_unauthenticated(self):
        resp = self.client.get("/health")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["status"], "HEALTHY")
        self.assertEqual(data["tele_manas_helpline"], "14416")

    def test_auth_enforcement(self):
        # Protected endpoint without auth token must be rejected
        resp = self.client.post("/api/v1/synthetic/generate", json={"personnel_count": 10})
        self.assertEqual(resp.status_code, 401)

    def test_generate_synthetic_endpoint(self):
        resp = self.client.post(
            "/api/v1/synthetic/generate",
            json={"personnel_count": 25, "days_history": 30, "save_to_disk": False},
            headers=self.auth_headers
        )
        self.assertEqual(resp.status_code, 201)
        data = resp.json()
        self.assertEqual(data["status"], "SUCCESS")
        self.assertEqual(data["personnel_count"], 25)
        self.assertGreater(data["hr_records_count"], 0)

    def test_sentiment_endpoint(self):
        resp = self.client.post(
            "/api/v1/nlp/sentiment",
            json={"text": "Everything went smoothly during the perimeter check. Morale is good."},
            headers=self.auth_headers
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn(data["sentiment_label"], ["Positive", "Neutral"])
        self.assertGreaterEqual(data["valence_score"], 0.0)

    def test_crisis_endpoint(self):
        resp = self.client.post(
            "/api/v1/nlp/crisis",
            json={"text": "I can't take this anymore, everyone would be better off without me."},
            headers=self.auth_headers
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertTrue(data["crisis_detected"])
        self.assertEqual(data["escalation"]["helpline"], "14416")
        self.assertEqual(data["escalation"]["priority"], "IMMEDIATE_ESCALATION")

    def test_scoring_predict_endpoint(self):
        resp = self.client.post(
            "/api/v1/score/predict",
            json={"pseudonym_token": "TOKEN-000001"},
            headers=self.auth_headers
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn(data["risk_band"], ["LOW", "MODERATE", "ELEVATED"])
        self.assertIn("top_factors", data)
        self.assertIn("recommended_support_pathway", data)

    def test_governance_model_card_endpoint(self):
        resp = self.client.get(
            "/api/v1/governance/model-card",
            headers=self.auth_headers
        )
        self.assertIn(resp.status_code, [200, 404])
        if resp.status_code == 200:
            data = resp.json()
            self.assertTrue(data["is_active"])
            self.assertIn("metrics", data)

if __name__ == "__main__":
    unittest.main()
