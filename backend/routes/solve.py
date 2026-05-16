from fastapi import APIRouter, HTTPException
from models.result import SolveRequest
from services.ai_service import get_solve_response

router = APIRouter(prefix="/solve", tags=["solve"])

@router.post("")
async def solve(request: SolveRequest):
    if not request.question.strip():
        raise HTTPException(status_code=400, detail="Question cannot be empty")
    try:
        response = await get_solve_response(request.question)
        return {"solution": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
