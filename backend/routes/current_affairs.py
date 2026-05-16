from datetime import datetime, timedelta
from fastapi import APIRouter
from services.ai_service import generate_current_affairs

router = APIRouter(prefix="/current-affairs", tags=["current_affairs"])

# Simple in-memory cache: regenerate once every 6 hours
_cache: dict = {"date": None, "items": [], "generated_at": None}


@router.get("")
async def get_current_affairs(count: int = 5, refresh: bool = False):
    """Return today's top current affairs items. Cached for 6 hours."""
    now = datetime.now()
    fresh = (
        _cache["generated_at"] is not None
        and (now - _cache["generated_at"]) < timedelta(hours=6)
        and len(_cache["items"]) >= count
    )
    if fresh and not refresh:
        return {"items": _cache["items"][:count], "generated_at": _cache["generated_at"].isoformat(), "cached": True}

    items = await generate_current_affairs(count)
    _cache["items"] = items
    _cache["generated_at"] = now
    _cache["date"] = now.date().isoformat()
    return {"items": items, "generated_at": now.isoformat(), "cached": False}
