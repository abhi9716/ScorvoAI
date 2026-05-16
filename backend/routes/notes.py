from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from models.result import NoteCreate, NoteUpdate
from services.note_service import (
    list_notes, get_note, create_note, update_note, delete_note,
)
from services.ai_service import classify_note_content, format_note_content
import base64
import os
import time

router = APIRouter(prefix="/notes", tags=["notes"])

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

class NoteOCRRequest(BaseModel):
    image_base64: str

class ImageUploadResponse(BaseModel):
    image_path: str

class TextClassificationRequest(BaseModel):
    extracted_text: str

class TextClassificationResponse(BaseModel):
    subject: str
    chapter: str
    tags: str

class NoteFormatRequest(BaseModel):
    raw_text: str

class NoteFormatResponse(BaseModel):
    formatted_text: str

@router.get("")
async def get_notes():
    return {"notes": list_notes()}

@router.get("/{note_id}")
async def get_single_note(note_id: int):
    note = get_note(note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return {"note": note}

@router.post("")
async def create_new_note(note: NoteCreate):
    return {"note": create_note(note)}

@router.put("/{note_id}")
async def update_existing_note(note_id: int, note: NoteUpdate):
    result = update_note(note_id, note)
    if not result:
        raise HTTPException(status_code=404, detail="Note not found")
    return {"note": result}

@router.delete("/{note_id}")
async def delete_existing_note(note_id: int):
    if not delete_note(note_id):
        raise HTTPException(status_code=404, detail="Note not found")
    return {"status": "deleted"}

@router.post("/upload-image", response_model=ImageUploadResponse)
async def upload_image(request: NoteOCRRequest):
    try:
        image_data = base64.b64decode(request.image_base64)
        filename = f"note_{int(time.time())}.png"
        filepath = os.path.join(UPLOAD_DIR, filename)
        with open(filepath, "wb") as f:
            f.write(image_data)
        return {"image_path": f"/uploads/{filename}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image upload failed: {str(e)}")

@router.post("/classify-text", response_model=TextClassificationResponse)
async def classify_text(request: TextClassificationRequest):
    try:
        text = request.extracted_text
        if not text or not text.strip():
            raise HTTPException(status_code=400, detail="No text provided for classification")
        classification = await classify_note_content(text)
        tags_list = classification.get("tags", [])
        tags_str = ", ".join(tags_list) if isinstance(tags_list, list) else str(tags_list)
        return {
            "subject": classification.get("subject", "General"),
            "chapter": classification.get("chapter", "General"),
            "tags": tags_str,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Classification failed: {str(e)}")

@router.post("/format-text", response_model=NoteFormatResponse)
async def format_text(request: NoteFormatRequest):
    try:
        if not request.raw_text.strip():
            raise HTTPException(status_code=400, detail="No text provided for formatting")
        formatted = await format_note_content(request.raw_text)
        return {"formatted_text": formatted}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Formatting failed: {str(e)}")
