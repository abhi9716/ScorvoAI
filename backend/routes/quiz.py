import json
import random
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
from models.result import QuizSubmission
from services.quiz_service import save_result
from services.quiz_data import QUIZ_QUESTIONS, SUBJECTS
from services.ai_service import generate_quiz_questions, generate_quiz_questions_stream

router = APIRouter(prefix="/quiz", tags=["quiz"])

def _get_static_questions(subjects: list[str] | None = None, chapters: list[str] | None = None, count: int = 5, difficulty: str | None = None) -> list:
    pool = QUIZ_QUESTIONS
    if subjects:
        pool = [q for q in pool if q["subject"] in subjects]
    if chapters:
        pool = [q for q in pool if q["chapter"] in chapters]
    if difficulty and difficulty != "mixed":
        pool = [q for q in pool if q.get("difficulty", "medium") == difficulty]
    if len(pool) <= count:
        return pool
    return random.sample(pool, count)

@router.get("")
async def get_quiz(
    subjects: str | None = Query(None, description="Comma-separated subjects"),
    chapters: str | None = Query(None, description="Comma-separated chapters"),
    count: int = Query(5),
    difficulty: str | None = Query(None, description="easy, medium, hard, or mixed"),
    ai: bool = Query(True, description="Use AI to generate questions")
):
    subj_list = [s.strip() for s in subjects.split(",")] if subjects else None
    chap_list = [c.strip() for c in chapters.split(",")] if chapters else None

    if ai:
        try:
            questions = await generate_quiz_questions(count, subj_list, chap_list, difficulty)
            return {"questions": questions, "ai_generated": True}
        except Exception as e:
            questions = _get_static_questions(subj_list, chap_list, count, difficulty)
            return {"questions": questions, "ai_generated": False, "fallback": str(e)}
    else:
        questions = _get_static_questions(subj_list, chap_list, count, difficulty)
        return {"questions": questions, "ai_generated": False}

@router.get("/stream")
async def get_quiz_stream(
    subjects: str | None = Query(None, description="Comma-separated subjects"),
    chapters: str | None = Query(None, description="Comma-separated chapters"),
    count: int = Query(5),
    difficulty: str | None = Query(None, description="easy, medium, hard, or mixed"),
):
    subj_list = [s.strip() for s in subjects.split(",")] if subjects else None
    chap_list = [c.strip() for c in chapters.split(",")] if chapters else None

    async def event_generator():
        try:
            async for question in generate_quiz_questions_stream(count, subj_list, chap_list, difficulty):
                yield f"data: {json.dumps(question)}\n\n"
        except Exception as e:
            static = _get_static_questions(subj_list, chap_list, count, difficulty)
            for q in static:
                q["ai_generated"] = False
                yield f"data: {json.dumps(q)}\n\n"
        finally:
            yield "event: done\ndata: {}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")

@router.get("/subjects")
async def get_subjects():
    return {"subjects": SUBJECTS}

@router.post("/submit")
async def submit_quiz(submission: QuizSubmission):
    score = 0
    details = []
    for answer in submission.answers:
        q = next((q for q in QUIZ_QUESTIONS if q["id"] == answer.question_index), None)
        if q:
            is_correct = q["correct"] == answer.selected_option
            if is_correct:
                score += 1
            details.append({
                "question_id": answer.question_index,
                "correct": is_correct,
                "correct_answer": q["correct"],
                "subject": q["subject"],
                "chapter": q["chapter"]
            })
        else:
            is_correct = answer.correct_option == answer.selected_option
            if is_correct:
                score += 1
            details.append({
                "question_id": answer.question_index,
                "correct": is_correct,
                "correct_answer": answer.correct_option,
                "subject": "ai",
                "chapter": "ai"
            })
    save_result(score, len(submission.answers), submission.topic)
    return {
        "score": score,
        "correct": score,
        "total": len(submission.answers),
        "details": details
    }
