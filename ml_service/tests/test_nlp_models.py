import unittest
from app.models.nlp_models import HighRecallCrisisClassifier, RoutineSentimentClassifier

class TestNLPModels(unittest.TestCase):
    def setUp(self):
        self.sentiment_model = RoutineSentimentClassifier()
        self.crisis_model = HighRecallCrisisClassifier()

    def test_routine_sentiment(self):
        pos_text = "Good shift today, unit morale is solid and looking forward to rest."
        res_pos = self.sentiment_model.analyze(pos_text)
        self.assertEqual(res_pos.sentiment_label, "Positive")
        self.assertGreater(res_pos.valence_score, 0.0)

        fatigued_text = "Night shift was exhausting, severe headache and fatigue all morning."
        res_fatigue = self.sentiment_model.analyze(fatigued_text)
        self.assertIn(res_fatigue.sentiment_label, ["Fatigued", "Stressed"])
        self.assertLess(res_fatigue.valence_score, 0.0)
        self.assertIn("fatigue", res_fatigue.fatigue_indicators)

    def test_high_recall_crisis_detection(self):
        crisis_samples = [
            "I can't take this anymore, there is no way out for me.",
            "Everyone in the unit would be better off without me.",
            "I'm giving away my watch and personal gear tonight, won't need them.",
            "I feel like pulling the trigger and ending this suffering."
        ]

        for text in crisis_samples:
            res = self.crisis_model.classify_crisis(text)
            self.assertTrue(res.crisis_detected, f"Failed to detect crisis in: {text}")
            self.assertGreaterEqual(res.crisis_probability, 0.40)
            self.assertTrue(res.escalation.trigger)
            self.assertEqual(res.escalation.helpline, "14416")
            self.assertEqual(res.escalation.priority, "IMMEDIATE_ESCALATION")
            self.assertIn("Tele-MANAS", res.escalation.recommended_action)
            self.assertIn("slow breath", res.stabilizing_response_hint)

    def test_routine_non_crisis(self):
        normal_text = "Finished route reconnaissance. Radios checked out fine."
        res = self.crisis_model.classify_crisis(normal_text)
        self.assertFalse(res.crisis_detected)
        self.assertFalse(res.escalation.trigger)
        self.assertEqual(res.escalation.priority, "NONE")

if __name__ == "__main__":
    unittest.main()
