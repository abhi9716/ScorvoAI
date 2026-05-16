from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from services.ai_service import generate_lesson, generate_lesson_stream

router = APIRouter(prefix="/lessons", tags=["lessons"])


class LessonRequest(BaseModel):
    subject: str
    chapter: str
    difficulty: str = "medium"
    exam: str = ""


@router.post("")
async def create_lesson(req: LessonRequest):
    """Generate a single AI-powered micro-lesson (non-streaming)."""
    content = await generate_lesson(req.subject, req.chapter, req.difficulty, req.exam)
    return {
        "subject": req.subject,
        "chapter": req.chapter,
        "difficulty": req.difficulty,
        "exam": req.exam,
        "content": content,
    }


@router.post("/stream")
async def stream_lesson(req: LessonRequest):
    """Stream lesson token-by-token via Server-Sent Events."""
    async def gen():
        try:
            async for chunk in generate_lesson_stream(req.subject, req.chapter, req.difficulty, req.exam):
                yield chunk
        except Exception as e:
            yield f"\n\n[Error generating lesson: {e}]"

    return StreamingResponse(gen(), media_type="text/plain")
