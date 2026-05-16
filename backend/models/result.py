from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class QuizAnswer(BaseModel):
    question_index: int
    selected_option: int
    correct_option: int

class QuizSubmission(BaseModel):
    answers: List[QuizAnswer]
    topic: str = "mixed"

class ChatRequest(BaseModel):
    question: str

class SolveRequest(BaseModel):
    question: str

class DailySubmission(BaseModel):
    answers: List[QuizAnswer]

class QuizResult(BaseModel):
    score: int
    correct: int
    total: int
    details: List[dict]

class NoteCreate(BaseModel):
    title: str = ""
    content: str
    subject: str = ""
    chapter: str = ""
    tags: str = ""
    image_path: str = ""

class NoteUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    subject: Optional[str] = None
    chapter: Optional[str] = None
    tags: Optional[str] = None
