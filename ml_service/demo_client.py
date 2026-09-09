"""
ManoFit ML Interactive Demo Tester
Run this script in your terminal to interactively test the ML microservice!
"""
import json
import urllib.request
import urllib.error

BASE_URL = "http://localhost:8000"
TOKEN = "manofit_ml_internal_sec_token_dev_2026"

def call_api(endpoint: str, method: str = "GET", payload: dict = None):
    url = f"{BASE_URL}{endpoint}"
    headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json"
    }
    data = json.dumps(payload).encode("utf-8") if payload else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return {"error": e.code, "detail": e.read().decode("utf-8")}
    except Exception as e:
        return {"error": str(e)}

def banner():
    print("=" * 65)
    print("  ManoFit Analytics & ML Interactive Console")
    print("  Armed Forces Personnel Stress & Crisis Detection System")
    print("=" * 65)

def test_health():
    print("\n[1] Checking Microservice Health...")
    res = call_api("/health")
    print(json.dumps(res, indent=2))

def test_crisis():
    print("\n" + "-" * 65)
    print("[2] Test Tier 2 High-Recall Crisis Detection (Tele-MANAS 14416)")
    print("-" * 65)
    default_text = "I can't take this anymore, everyone would be better off without me."
    user_input = input(f"Enter statement to test [Press ENTER for default: '{default_text}']:\n> ").strip()
    text = user_input if user_input else default_text
    
    print("\nAnalyzing utterance...")
    res = call_api("/api/v1/nlp/crisis", method="POST", payload={"text": text})
    print("\n--- Tele-MANAS Classifier Output ---")
    print(f"Crisis Detected:          {res.get('crisis_detected')}")
    print(f"Confidence / Probability: {res.get('crisis_probability', 0):.2%}")
    print(f"Risk Indicators:          {res.get('risk_indicators_detected')}")
    print(f"Helpline Dispatched:      {res.get('escalation', {}).get('helpline')}")
    print(f"Escalation Priority:      {res.get('escalation', {}).get('priority')}")
    print(f"Stabilizing Script Hint:  {res.get('stabilizing_response_hint')}")

def test_sentiment():
    print("\n" + "-" * 65)
    print("[3] Test Tier 1 Routine Sentiment & Fatigue Tracking")
    print("-" * 65)
    default_text = "Third night shift this week. Severe headache and body fatigue."
    user_input = input(f"Enter check-in text [Press ENTER for default: '{default_text}']:\n> ").strip()
    text = user_input if user_input else default_text
    
    res = call_api("/api/v1/nlp/sentiment", method="POST", payload={"text": text})
    print("\n--- Sentiment Output ---")
    print(f"Sentiment Label:    {res.get('sentiment_label')}")
    print(f"Valence Score:      {res.get('valence_score')}")
    print(f"Stress Probability: {res.get('stress_probability', 0):.2%}")
    print(f"Fatigue Cues:       {res.get('fatigue_indicators')}")

def test_personnel_scoring():
    print("\n" + "-" * 65)
    print("[4] Test Personnel Stress Risk Scoring & SHAP Explainability")
    print("-" * 65)
    token = input("Enter Pseudonym Token [Press ENTER for default: 'TOKEN-000042']:\n> ").strip()
    token = token if token else "TOKEN-000042"

    payload = {
        "pseudonym_token": token,
        "recent_hr_records": [
            {
                "pseudonym_token": token,
                "record_date": "2026-09-08",
                "unit_code": "BN-08",
                "location_tier": "CI_OPS",
                "shift_hours": 14.5,
                "is_rest_day": False,
                "leave_taken_days": 0.0,
                "leave_balance_days": 28.0,
                "consecutive_active_days": 24,
                "transfer_count_last_12m": 2,
                "training_load_hours": 4.0,
                "synthetic": True
            }
        ],
        "recent_assessments": [
            {
                "pseudonym_token": token,
                "assessment_date": "2026-09-08",
                "workload_perception": 5,
                "mood_rating": 1,
                "manager_relationship": 2,
                "sleep_quality": 1,
                "physical_exhaustion": 5,
                "peer_social_support": 1,
                "synthetic": True
            }
        ]
    }

    res = call_api("/api/v1/score/predict", method="POST", payload=payload)
    print("\n--- Welfare Risk Assessment Output ---")
    print(f"Token:               {res.get('pseudonym_token')}")
    print(f"Clinical Risk Band:  {res.get('risk_band')} (Never raw scores)")
    print(f"Confidence Band:     {res.get('confidence', 0):.2%}")
    print(f"Support Pathway:     {res.get('recommended_support_pathway')}")
    print("\nTop Contributing Factors (SHAP Explainability for Welfare Officer):")
    for idx, factor in enumerate(res.get("top_factors", []), 1):
        print(f"  {idx}. {factor.get('display_title')} ({factor.get('direction')})")
        print(f"     -> {factor.get('context_detail')}")

def main():
    banner()
    while True:
        print("\nChoose an option to test:")
        print("  1. Health Check")
        print("  2. Test High-Recall Crisis Classifier (Tele-MANAS 14416)")
        print("  3. Test Routine Sentiment & Fatigue Classifier")
        print("  4. Test Personnel Stress Risk Scoring (XGBoost + SHAP)")
        print("  5. View Active Model Card")
        print("  0. Exit")
        choice = input("\nEnter choice [0-5]: ").strip()
        
        if choice == "1":
            test_health()
        elif choice == "2":
            test_crisis()
        elif choice == "3":
            test_sentiment()
        elif choice == "4":
            test_personnel_scoring()
        elif choice == "5":
            res = call_api("/api/v1/governance/model-card")
            print(json.dumps(res, indent=2))
        elif choice == "0":
            print("\nExiting. Server remains active.")
            break
        else:
            print("Invalid choice, please select 0-5.")

if __name__ == "__main__":
    main()
