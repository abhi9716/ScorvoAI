from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from models.result import ChatRequest
from services.ai_service import get_chat_response, get_chat_response_stream

router = APIRouter(prefix="/chat", tags=["chat"])

@router.post("")
async def chat(request: ChatRequest):
    if not request.question.strip():
        raise HTTPException(status_code=400, detail="Question cannot be empty")
    try:
        response = await get_chat_response(request.question)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/stream")
async def chat_stream(request: ChatRequest):
    if not request.question.strip():
        raise HTTPException(status_code=400, detail="Question cannot be empty")
    
    async def generator():
        try:
            async for chunk in get_chat_response_stream(request.question):
                yield chunk
        except Exception as e:
            yield f"Error: {str(e)}"
    
    return StreamingResponse(generator(), media_type="text/plain")
