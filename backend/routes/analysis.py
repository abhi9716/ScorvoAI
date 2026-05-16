from fastapi import APIRouter
from services.quiz_service import get_analyze, get_stats

router = APIRouter(prefix="/analyze", tags=["analysis"])

@router.get("")
async def analyze():
    return get_analyze()

@router.get("/stats")
async def stats():
    return get_stats()
