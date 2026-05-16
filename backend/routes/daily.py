from fastapi import APIRouter, HTTPException
from datetime import date
from models.result import DailySubmission
from services.quiz_service import save_daily_result
from services.quiz_data import DAILY_QUESTIONS

router = APIRouter(prefix="/daily", tags=["daily"])

def _get_daily_seed() -> int:
    today = date.today()
    return today.year * 10000 + today.month * 100 + today.day

@router.get("")
async def get_daily():
    seed = _get_daily_seed()
    questions = DAILY_QUESTIONS
    return {
        "seed": seed,
        "questions": questions
    }

@router.post("/submit")
async def submit_daily(submission: DailySubmission):
    if len(submission.answers) != len(DAILY_QUESTIONS):
        raise HTTPException(status_code=400, detail=f"Expected {len(DAILY_QUESTIONS)} answers")
    score = 0
    details = []
    for answer in submission.answers:
        if 0 <= answer.question_index < len(DAILY_QUESTIONS):
            q = DAILY_QUESTIONS[answer.question_index]
            is_correct = q["correct"] == answer.selected_option
            if is_correct:
                score += 1
            details.append({
                "question_index": answer.question_index,
                "correct": is_correct,
                "correct_answer": q["correct"]
            })
    save_daily_result(score, len(submission.answers))
    return {
        "score": score,
        "correct": score,
        "total": len(DAILY_QUESTIONS),
        "details": details
    }
