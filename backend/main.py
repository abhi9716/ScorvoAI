import os
import logging
import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
from models.db import init_db
from routes import chat, solve, quiz, analysis, daily, notes, lessons, current_affairs
from services.ai_service import GEMMA_MODEL, OLLAMA_BASE, OLLAMA_API_KEY

load_dotenv()

logger = logging.getLogger("scorvoai")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")

app = FastAPI(title="ScorvoAI API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup():
    init_db()
    logger.info("─" * 60)
    logger.info("ScorvoAI API starting up")
    logger.info(f"  GEMMA_MODEL:     {GEMMA_MODEL}")
    logger.info(f"  OLLAMA_BASE:     {OLLAMA_BASE}")
    logger.info(f"  OLLAMA_API_KEY:  {'SET (' + str(len(OLLAMA_API_KEY)) + ' chars)' if OLLAMA_API_KEY else 'NOT SET ❌ current-affairs will fail'}")
    logger.info(f"  CORS_ORIGINS:    {os.getenv('CORS_ORIGINS', '*')}")
    logger.info(f"  PORT:            {os.getenv('PORT', '8000')}")
    logger.info("─" * 60)
    if not OLLAMA_API_KEY:
        logger.warning("⚠ OLLAMA_API_KEY not set — /current-affairs endpoint will return 500")


@app.get("/health")
async def health():
    """Liveness probe — returns 200 if the process is up. Cheap, no I/O."""
    return {"status": "ok"}


@app.get("/ready")
async def ready():
    """Readiness probe — actually checks downstream dependencies.

    Use this for deployment readiness (Railway/Render/K8s readinessProbe).
    Use /health for liveness (just checks the process is alive).
    """
    checks = {
        "ollama_base": OLLAMA_BASE,
        "ollama_api_key_set": bool(OLLAMA_API_KEY),
        "ollama_reachable": False,
        "ollama_models_available": False,
        "ollama_error": None,
    }
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{OLLAMA_BASE}/api/tags")
            checks["ollama_reachable"] = r.status_code == 200
            if r.status_code == 200:
                tags = [m.get("name", "") for m in r.json().get("models", [])]
                checks["ollama_models_available"] = GEMMA_MODEL in tags or any(GEMMA_MODEL.split(":")[0] in t for t in tags)
                checks["ollama_models_found"] = tags[:10]
    except Exception as e:
        checks["ollama_error"] = f"{type(e).__name__}: {str(e)[:200]}"

    healthy = checks["ollama_reachable"] and checks["ollama_api_key_set"]
    return {"ready": healthy, "checks": checks}


app.include_router(chat.router)
app.include_router(solve.router)
app.include_router(quiz.router)
app.include_router(analysis.router)
app.include_router(daily.router)
app.include_router(notes.router)
app.include_router(lessons.router)
app.include_router(current_affairs.router)

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")
