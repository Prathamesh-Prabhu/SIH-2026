from fastapi import APIRouter, HTTPException, status
from ..models.nlp_models import HighRecallCrisisClassifier, RoutineSentimentClassifier
from ..schemas import (
    NLPCrisisRequest,
    NLPCrisisResponse,
    NLPSentimentRequest,
    NLPSentimentResponse
)

router = APIRouter(prefix="/api/v1/nlp", tags=["Natural Language Processing"])

_sentiment_model = RoutineSentimentClassifier()
_crisis_model = HighRecallCrisisClassifier()
_sentiment_loaded = False
_crisis_loaded = False

def get_sentiment_classifier() -> RoutineSentimentClassifier:
    global _sentiment_model, _sentiment_loaded
    if not _sentiment_loaded:
        _sentiment_model.load()
        _sentiment_loaded = True
    return _sentiment_model

def get_crisis_classifier() -> HighRecallCrisisClassifier:
    global _crisis_model, _crisis_loaded
    if not _crisis_loaded:
        _crisis_model.load()
        _crisis_loaded = True
    return _crisis_model

@router.post(
    "/sentiment", 
    response_model=NLPSentimentResponse, 
    status_code=status.HTTP_200_OK,
    summary="Analyze Routine Sentiment & Fatigue"
)
async def analyze_sentiment(payload: NLPSentimentRequest):
    """
    Tier 1 Routine Sentiment Classification.
    Monitors longitudinal sentiment, stress likelihood, and fatigue indicators in companion dialogue.
    """
    try:
        clf = get_sentiment_classifier()
        return clf.analyze(payload.text)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sentiment analysis failed: {str(e)}"
        )

@router.post(
    "/crisis", 
    response_model=NLPCrisisResponse, 
    status_code=status.HTTP_200_OK,
    summary="Detect High-Recall Crisis & Trigger Tele-MANAS Escalation"
)
async def detect_crisis(payload: NLPCrisisRequest):
    """
    Tier 2 Dedicated High-Recall Crisis Classifier.
    Catches indirect phrasing, despair, and self-harm cues in real-time conversation turns.
    Triggers parallel Tele-MANAS (14416) alert dispatch and outputs stabilizing response directives.
    """
    try:
        clf = get_crisis_classifier()
        return clf.classify_crisis(payload.text, transcript_id=payload.transcript_id)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Crisis classification failed: {str(e)}"
        )
