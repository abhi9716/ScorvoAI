from datetime import datetime
from models.db import get_db
from models.result import NoteCreate, NoteUpdate
import asyncio
import services.ai_service as ai

def list_notes() -> list:
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM notes ORDER BY updated_at DESC").fetchall()
        return [dict(r) for r in rows]

def get_note(note_id: int) -> dict | None:
    with get_db() as conn:
        row = conn.execute("SELECT * FROM notes WHERE id = ?", (note_id,)).fetchone()
        return dict(row) if row else None

def create_note(data: NoteCreate) -> dict:
    now = datetime.now().isoformat()
    with get_db() as conn:
        cursor = conn.execute(
            "INSERT INTO notes (title, content, subject, chapter, tags, image_path, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (data.title, data.content, data.subject, data.chapter, data.tags, data.image_path, now, now)
        )
        return {"id": cursor.lastrowid, **data.model_dump(), "created_at": now, "updated_at": now}

def update_note(note_id: int, data: NoteUpdate) -> dict | None:
    now = datetime.now().isoformat()
    existing = get_note(note_id)
    if not existing:
        return None

    updates = {}
    if data.title is not None: updates["title"] = data.title
    if data.content is not None: updates["content"] = data.content
    if data.subject is not None: updates["subject"] = data.subject
    if data.chapter is not None: updates["chapter"] = data.chapter
    if data.tags is not None: updates["tags"] = data.tags
    updates["updated_at"] = now

    if updates:
        set_clause = ", ".join(f"{k} = ?" for k in updates.keys())
        values = list(updates.values()) + [note_id]
        with get_db() as conn:
            conn.execute(f"UPDATE notes SET {set_clause} WHERE id = ?", values)

    return get_note(note_id)

def delete_note(note_id: int) -> bool:
    with get_db() as conn:
        cursor = conn.execute("DELETE FROM notes WHERE id = ?", (note_id,))
        return cursor.rowcount > 0
