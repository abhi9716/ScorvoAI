import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
from models.db import init_db
from routes import chat, solve, quiz, analysis, daily, notes, lessons, current_affairs

load_dotenv()

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

@app.get("/health")
async def health():
    return {"status": "ok"}

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
