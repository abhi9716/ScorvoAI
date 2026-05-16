import os
import json
import re
import asyncio
import httpx
from pylatexenc.latex2text import LatexNodes2Text

OLLAMA_BASE = os.getenv("OLLAMA_BASE", "http://localhost:11434")
OLLAMA_CLOUD_BASE = "https://ollama.com"
OLLAMA_API_KEY = os.getenv("OLLAMA_API_KEY", "")

# ─── Gemma 4 model — the single source of truth ──────────────────────────
# All generative features in ScorvoAI run on this Google Gemma 4 model.
# See NOTICE for attribution. Override via env var to test variants.
GEMMA_MODEL = os.getenv("GEMMA_MODEL", "gemma4:31b-cloud")

CHAT_SYSTEM_PROMPT = """You are an expert Indian government exam tutor for SSC, UPSC, Banking exams.

You write in Markdown format for a mobile app. Follow these rules EXACTLY:

Supported formatting:
- **bold** for key terms and important points
- *italic* for emphasis
- Bullet lists starting with - for points
- Numbered lists (1. 2. 3.) for steps
- `inline code` for formulas, shortcuts, terms
- ```code blocks``` for longer formulas or examples
- > blockquotes for important exam tips
- # ## ### headings to organize topics
- [text](url) for links when needed
- Tables use pipe syntax with a separator row:
  | Header 1 | Header 2 |
  |----------|----------|
  | Cell 1   | Cell 2   |
  ALWAYS include the separator row (|----|----|) between header and data.
- --- for horizontal rules between sections

MATH RULES (CRITICAL):
- NEVER use $...$ or $$...$$ or any LaTeX delimiters
- NEVER use \frac, \sqrt, \boxed, \sum, \int, \begin, or any LaTeX commands
- Write math in PLAIN TEXT only: 3/4, √16=4, x²=25, 25%, x = (-b ± √(b²-4ac)) / 2a
- Use Unicode symbols: √, ±, ×, ÷, ², ³, α, β, π, θ, Δ
- For fractions use "a/b" format
- For exponents use Unicode superscripts (² ³) or "x^n" notation

Keep answers concise and exam-focused."""

SOLVER_SYSTEM_PROMPT = r"""You are an expert SSC math and reasoning teacher. Solve step-by-step. Show shortcuts.

You write in Markdown format for a mobile app. Follow these rules EXACTLY:

Supported formatting:
- **bold** for the final answer
- Numbered lists (1. 2. 3.) for solving steps
- Bullet lists (-) for key points and shortcuts
- `inline code` for formulas and expressions
- > blockquotes for important tips or memory tricks
- Tables use pipe syntax with a separator row:
  | Header 1 | Header 2 |
  |----------|----------|
  | Cell 1   | Cell 2   |
  ALWAYS include the separator row (|----|----|)

MATH RULES (CRITICAL):
- NEVER use $...$ or $$...$$ or any LaTeX delimiters
- NEVER use \frac, \sqrt, \boxed, \sum, \int, \begin, or any LaTeX commands
- Write math in PLAIN TEXT only: 3/4, √16=4, x²=25, a²+b²=c²
- Use Unicode symbols: √, ±, ×, ÷, ², ³, α, β, π, θ, Δ, ∠, ∥, ⊥
- For fractions use "a/b" or "a ÷ b" format
- For exponents use Unicode superscripts (² ³) or "x^n" notation
- Keep explanations simple for exam preparation"""

QUIZ_GEN_PROMPT = """You are an expert Indian government exam question setter for SSC, UPSC, and Banking exams.
Generate {count} multiple choice questions for: {topics}
Difficulty level: {difficulty}

Rules:
- Each question must have exactly 4 options
- Only one option is correct
- Vary difficulty within range: {difficulty}
- Make options plausible (not obviously wrong)
- Include topics: {chapters}
- Output ONLY valid JSON, no markdown

Math formatting for questions/explanations:
- Use plain text for math: 3/4, √16=4, x²=25, 25%
- Only use $...$ for inline LaTeX if complex formula needed
- Do NOT use \frac, \sqrt, \boxed, or LaTeX commands

JSON format:
[
  {{
    "question": "Question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correct": 0,
    "explanation": "Brief explanation of why this answer is correct",
    "topic": "Subject name",
    "chapter": "Chapter name",
    "difficulty": "easy" or "medium" or "hard"
  }}
]

"correct" is the 0-based index of the correct option (0, 1, 2, or 3).
"""

NOTE_CLASSIFY_PROMPT = """You are an expert classifier of study notes for Indian government exam preparation (SSC, UPSC, Banking).
Given the following note content, classify it into:
- subject (e.g., "Quantitative Aptitude", "General Knowledge", "Reasoning", "English", "Current Affairs")
- chapter (specific topic within the subject)
- tags (2-4 relevant keywords)

Output ONLY valid JSON:
{{
  "subject": "Subject name",
  "chapter": "Chapter name",
  "tags": ["tag1", "tag2", "tag3"]
}}

Note content:
"""

LESSON_GEN_PROMPT = """You are an expert tutor for Indian government exams (SSC, UPSC, Banking, Railway).
Generate a focused 3-5 minute micro-lesson on the requested chapter at the requested difficulty.

Output structure (in this exact order):
# {chapter}
*{subject} • {difficulty}*

## Why this matters
2-3 sentences explaining why this topic is important for the exam.

## Key Concepts
Bullet list of 4-6 core concepts with one-line explanations. Use **bold** for terms.

## Worked Example
One clear worked example showing the concept in action. Use numbered steps.

## Quick Tips & Tricks
- 3-4 actionable shortcuts, mnemonics, or pattern recognition tips
- Mark them as *tip:*, *trick:* or *remember:* prefixes

## Common Mistakes
2-3 typical errors students make on this topic.

## In Exam
1-line on how this appears in real exam questions (e.g. "Usually 1-2 questions in Tier-1, weight 4-6 marks").

Math rules: plain text only — 3/4, √16=4, x²=25. NO LaTeX commands. Use Unicode (√ ± × ÷ ² ³ π θ).
Length: 350-550 words. Focused, exam-oriented, and friendly tone."""

CURRENT_AFFAIRS_PROMPT = """You are a current affairs editor for Indian government exam aspirants (UPSC, SSC, Banking, Railway).
Given the following REAL news search results, extract the {count} most exam-relevant items.

For each chosen item, produce:
- A short eye-catching headline (under 70 chars)
- 2-3 sentence summary covering Who/What/When/Why-it-matters
- One "exam angle" line: which exam/subject this typically appears in
- A category tag from: Polity, Economy, Sci-Tech, International, Environment, Defence, Sports, Awards
- "source_url": the URL from the search results that backs this item

Rules:
- Use ONLY information present in the search results below — do NOT invent facts
- Prioritize: government schemes, RBI/economic data, key bills/acts, major appointments, India in international relations, awards, science/tech breakthroughs, important reports/indices
- Skip clickbait, opinion pieces, and entertainment news
- If fewer than {count} relevant items exist, return what you have

Output ONLY valid JSON in this exact shape (no markdown):
[
  {{
    "headline": "...",
    "summary": "...",
    "exam_angle": "...",
    "category": "...",
    "source_url": "..."
  }}
]

Search results:
"""

NOTE_FORMAT_PROMPT = """You are an expert note formatter for Indian government exam preparation (SSC, UPSC, Banking).
Given the following raw OCR-extracted text, reformat it into well-structured, clean markdown notes.

Rules:
- Use clear headings (##, ###) for topics
- Use bullet points (-) for key facts
- Use numbered lists (1., 2.) for steps or sequences
- Use `inline code` for formulas, shortcuts, or important terms
- Use **bold** for important terms and final answers
- Use *italic* for emphasis
- Preserve all factual content from the original text
- Remove OCR artifacts, garbage text, or irrelevant fragments
- Keep it concise, exam-focused, and easy to review
- Do NOT add new information not present in the original text
- Format math as plain text: e.g., "3/4", "√16 = 4", "x² = 25"

Return ONLY the formatted markdown text, no explanations.

Raw OCR text:
"""

async def get_chat_response(question: str) -> str:
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{OLLAMA_BASE}/api/chat",
                json={
                    "model": GEMMA_MODEL,
                    "messages": [
                        {"role": "system", "content": CHAT_SYSTEM_PROMPT},
                        {"role": "user", "content": question}
                    ],
                    "stream": False,
                    "options": {"temperature": 0.7, "num_predict": 2000}
                },
                timeout=120.0
            )
            if response.status_code == 200:
                return response.json()["message"]["content"].strip()
            else:
                raise Exception(f"Ollama error: {response.status_code}")
    except Exception as e:
        raise Exception(f"Ollama API error: {str(e)}")

async def get_chat_response_stream(question: str):
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream(
                "POST",
                f"{OLLAMA_BASE}/api/chat",
                json={
                    "model": GEMMA_MODEL,
                    "messages": [
                        {"role": "system", "content": CHAT_SYSTEM_PROMPT},
                        {"role": "user", "content": question}
                    ],
                    "stream": True,
                    "options": {"temperature": 0.7, "num_predict": 2000}
                }
            ) as response:
                async for line in response.aiter_lines():
                    if line:
                        try:
                            data = json.loads(line)
                            if "message" in data and "content" in data["message"]:
                                content = data["message"]["content"]
                                if content:
                                    yield content
                            elif data.get("done"):
                                break
                        except:
                            pass
    except Exception as e:
        raise Exception(f"Ollama API error: {str(e)}")

async def get_solve_response(question: str) -> str:
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{OLLAMA_BASE}/api/chat",
                json={
                    "model": GEMMA_MODEL,
                    "messages": [
                        {"role": "system", "content": SOLVER_SYSTEM_PROMPT},
                        {"role": "user", "content": question}
                    ],
                    "stream": False,
                    "options": {"temperature": 0.3, "num_predict": 2000}
                },
                timeout=120.0
            )
            if response.status_code == 200:
                raw = response.json()["message"]["content"].strip()
            else:
                raise Exception(f"Ollama error: {response.status_code}")

        converter = LatexNodes2Text()
        try:
            def _safe_convert(text: str) -> str:
                try:
                    return converter.latex_to_text(text)
                except Exception:
                    return text

            raw = re.sub(r'\$\$(.+?)\$\$', lambda m: _safe_convert(m.group(1)), raw, flags=re.DOTALL)
            raw = re.sub(r'(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)', lambda m: _safe_convert(m.group(1)), raw)
            raw = re.sub(r'\\\[(.+?)\\\]', lambda m: _safe_convert(m.group(1)), raw, flags=re.DOTALL)
            raw = re.sub(r'\\\((.+?)\\\)', lambda m: _safe_convert(m.group(1)), raw)
        except Exception:
            pass

        return raw.strip()
    except Exception as e:
        raise Exception(f"Ollama API error: {str(e)}")

def _validate_question(q: dict, subjects, chapters, difficulty) -> dict | None:
    if not isinstance(q, dict) or "question" not in q or "options" not in q or "correct" not in q:
        return None
    return {
        "id": 0,
        "ai_generated": True,
        "question": str(q["question"]),
        "options": [str(o) for o in q["options"][:4]],
        "correct": int(q["correct"]) % 4,
        "explanation": str(q.get("explanation", "")),
        "topic": str(q.get("topic", subjects[0] if subjects else "Mixed")),
        "chapter": str(q.get("chapter", chapters[0] if chapters else "General")),
        "subject": str(q.get("topic", q.get("subject", subjects[0] if subjects else "Mixed"))),
        "difficulty": str(q.get("difficulty", difficulty if difficulty else "mixed")),
    }

async def generate_quiz_questions(count: int, subjects: list[str] | None = None, chapters: list[str] | None = None, difficulty: str | None = None) -> list[dict]:
    try:
        topics_str = ", ".join(subjects) if subjects else "Mixed (Quantitative Aptitude, General Knowledge, Reasoning)"
        chapters_str = ", ".join(chapters) if chapters else "All chapters"
        diff_str = difficulty if difficulty and difficulty != "mixed" else "Mixed (easy, medium, hard)"

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{OLLAMA_BASE}/api/chat",
                json={
                    "model": GEMMA_MODEL,
                    "messages": [
                        {"role": "system", "content": QUIZ_GEN_PROMPT.format(count=count, topics=topics_str, difficulty=diff_str, chapters=chapters_str)},
                        {"role": "user", "content": f"Generate {count} quiz questions."}
                    ],
                    "stream": False,
                    "options": {"temperature": 0.8, "num_predict": 3000}
                },
                timeout=120.0
            )
            if response.status_code == 200:
                raw = response.json()["message"]["content"].strip()
            else:
                raise Exception(f"Ollama error: {response.status_code}")

        if raw.startswith("```"):
            raw = re.sub(r'^```(?:json)?\s*', '', raw)
            raw = re.sub(r'\s*```$', '', raw)
            raw = raw.strip()

        questions = json.loads(raw)

        validated = []
        for q in questions[:count]:
            v = _validate_question(q, subjects, chapters, difficulty)
            if v:
                validated.append(v)
        return validated
    except Exception as e:
        raise Exception(f"Quiz generation failed: {str(e)}")

async def generate_quiz_questions_stream(count: int, subjects: list[str] | None = None, chapters: list[str] | None = None, difficulty: str | None = None):
    topics_str = ", ".join(subjects) if subjects else "Mixed (Quantitative Aptitude, General Knowledge, Reasoning)"
    chapters_str = ", ".join(chapters) if chapters else "All chapters"
    diff_str = difficulty if difficulty and difficulty != "mixed" else "Mixed (easy, medium, hard)"

    buffer = ""
    decoder = json.JSONDecoder()
    pos = 0
    array_started = False
    yielded_count = 0

    async with httpx.AsyncClient(timeout=120.0) as client:
        async with client.stream(
            "POST",
            f"{OLLAMA_BASE}/api/chat",
            json={
                "model": GEMMA_MODEL,
                "messages": [
                    {"role": "system", "content": QUIZ_GEN_PROMPT.format(count=count, topics=topics_str, difficulty=diff_str, chapters=chapters_str)},
                    {"role": "user", "content": f"Generate {count} quiz questions."}
                ],
                "stream": True,
                "options": {"temperature": 0.8, "num_predict": 3000}
            }
        ) as response:
            async for line in response.aiter_lines():
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    if "message" in data and "content" in data["message"]:
                        chunk = data["message"]["content"]
                        if chunk:
                            buffer += chunk
                except Exception:
                    continue

                if not array_started:
                    idx = buffer.find("[")
                    if idx >= 0:
                        array_started = True
                        buffer = buffer[idx + 1:]
                        pos = 0

                if not array_started or yielded_count >= count:
                    continue

                while pos < len(buffer):
                    while pos < len(buffer) and buffer[pos] in " \t\n\r,":
                        pos += 1
                    if pos >= len(buffer):
                        break
                    if buffer[pos] == "]":
                        return

                    try:
                        obj, used = decoder.raw_decode(buffer, pos)
                    except json.JSONDecodeError:
                        break

                    v = _validate_question(obj, subjects, chapters, difficulty)
                    if v:
                        yield v
                        yielded_count += 1
                        if yielded_count >= count:
                            return

                    pos += used

                if pos > 0:
                    buffer = buffer[pos:]
                    pos = 0

async def classify_note_content(content: str) -> dict:
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{OLLAMA_BASE}/api/chat",
                json={
                    "model": GEMMA_MODEL,
                    "messages": [
                        {"role": "system", "content": NOTE_CLASSIFY_PROMPT},
                        {"role": "user", "content": content[:2000]}
                    ],
                    "stream": False,
                    "options": {"temperature": 0.3, "num_predict": 200}
                },
                timeout=120.0
            )
            if response.status_code == 200:
                raw = response.json()["message"]["content"].strip()
            else:
                raise Exception(f"Ollama error: {response.status_code}")

        if raw.startswith("```"):
            raw = re.sub(r'^```(?:json)?\s*', '', raw)
            raw = re.sub(r'\s*```$', '', raw)
            raw = raw.strip()

        result = json.loads(raw)
        tags_list = result.get("tags", [])
        tags_str = ", ".join(tags_list) if isinstance(tags_list, list) else str(tags_list)
        return {
            "subject": str(result.get("subject", "General")),
            "chapter": str(result.get("chapter", "General")),
            "tags": tags_str,
        }
    except Exception as e:
        raise Exception(f"Note classification failed: {str(e)}")

async def format_note_content(content: str) -> str:
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{OLLAMA_BASE}/api/chat",
                json={
                    "model": GEMMA_MODEL,
                    "messages": [
                        {"role": "system", "content": NOTE_FORMAT_PROMPT},
                        {"role": "user", "content": content[:4000]}
                    ],
                    "stream": False,
                    "options": {"temperature": 0.3, "num_predict": 2000}
                },
                timeout=120.0
            )
            if response.status_code == 200:
                return response.json()["message"]["content"].strip()
            else:
                raise Exception(f"Ollama error: {response.status_code}")
    except Exception as e:
        raise Exception(f"Note formatting failed: {str(e)}")

async def generate_lesson(subject: str, chapter: str, difficulty: str = "medium", exam: str = "") -> str:
    """Generate an AI-powered micro-lesson for a chapter."""
    try:
        prompt = LESSON_GEN_PROMPT.format(subject=subject, chapter=chapter, difficulty=difficulty)
        user_msg = f"Subject: {subject}\nChapter: {chapter}\nDifficulty: {difficulty}"
        if exam:
            user_msg += f"\nExam context: {exam}"
        user_msg += "\n\nGenerate the lesson now."
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{OLLAMA_BASE}/api/chat",
                json={
                    "model": GEMMA_MODEL,
                    "messages": [
                        {"role": "system", "content": prompt},
                        {"role": "user", "content": user_msg}
                    ],
                    "stream": False,
                    "options": {"temperature": 0.6, "num_predict": 1500}
                },
                timeout=180.0
            )
            if response.status_code == 200:
                return response.json()["message"]["content"].strip()
            raise Exception(f"Ollama error: {response.status_code}")
    except Exception as e:
        raise Exception(f"Lesson generation failed: {str(e)}")

async def generate_lesson_stream(subject: str, chapter: str, difficulty: str = "medium", exam: str = ""):
    """Stream lesson generation token by token."""
    prompt = LESSON_GEN_PROMPT.format(subject=subject, chapter=chapter, difficulty=difficulty)
    user_msg = f"Subject: {subject}\nChapter: {chapter}\nDifficulty: {difficulty}"
    if exam:
        user_msg += f"\nExam context: {exam}"
    user_msg += "\n\nGenerate the lesson now."
    try:
        async with httpx.AsyncClient(timeout=180.0) as client:
            async with client.stream(
                "POST",
                f"{OLLAMA_BASE}/api/chat",
                json={
                    "model": GEMMA_MODEL,
                    "messages": [
                        {"role": "system", "content": prompt},
                        {"role": "user", "content": user_msg}
                    ],
                    "stream": True,
                    "options": {"temperature": 0.6, "num_predict": 1500}
                }
            ) as response:
                async for line in response.aiter_lines():
                    if line:
                        try:
                            data = json.loads(line)
                            if "message" in data and "content" in data["message"]:
                                content = data["message"]["content"]
                                if content:
                                    yield content
                            elif data.get("done"):
                                break
                        except Exception:
                            pass
    except Exception as e:
        raise Exception(f"Lesson stream failed: {str(e)}")

async def ollama_web_search(query: str, max_results: int = 10) -> list[dict]:
    """Real web search via Ollama Cloud Web Search API.

    Returns list of {title, url, content} dicts. Requires OLLAMA_API_KEY env var.
    Docs: https://docs.ollama.com/capabilities/web-search
    """
    if not OLLAMA_API_KEY:
        raise Exception("OLLAMA_API_KEY not set — cannot perform real web search")
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{OLLAMA_CLOUD_BASE}/api/web_search",
            headers={"Authorization": f"Bearer {OLLAMA_API_KEY}"},
            json={"query": query, "max_results": max_results},
        )
        if response.status_code != 200:
            raise Exception(f"Web search error {response.status_code}: {response.text[:200]}")
        data = response.json()
        results = data.get("results", []) if isinstance(data, dict) else data
        return [{"title": r.get("title", ""), "url": r.get("url", ""), "content": r.get("content", "")} for r in results]


async def generate_current_affairs(count: int = 5) -> list[dict]:
    """Fetch real news via web search, then have the LLM extract the top exam-relevant items."""
    # 1) Fetch real news from the web
    today = json.dumps(__import__("datetime").date.today().isoformat()).strip('"')
    queries = [
        f"India current affairs today {today} UPSC SSC",
        f"India government schemes RBI policy news {today}",
    ]
    all_results: list[dict] = []
    try:
        for q in queries:
            try:
                results = await ollama_web_search(q, max_results=8)
                all_results.extend(results)
            except Exception:
                continue
    except Exception as e:
        raise Exception(f"Web search failed: {str(e)}")

    if not all_results:
        raise Exception("No news results from web search")

    # De-duplicate by URL
    seen = set()
    unique: list[dict] = []
    for r in all_results:
        url = r.get("url", "")
        if url and url not in seen:
            seen.add(url)
            unique.append(r)

    # 2) Compose a compact search-results block (truncate each content)
    block_parts = []
    for i, r in enumerate(unique[:15]):
        snippet = (r.get("content") or "")[:600]
        block_parts.append(f"[{i+1}] {r.get('title','')}\nURL: {r.get('url','')}\n{snippet}\n")
    search_block = "\n".join(block_parts)

    # 3) Ask the LLM to extract exam-relevant items grounded in the real results
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{OLLAMA_BASE}/api/chat",
                json={
                    "model": GEMMA_MODEL,
                    "messages": [
                        {"role": "system", "content": CURRENT_AFFAIRS_PROMPT.format(count=count)},
                        {"role": "user", "content": search_block}
                    ],
                    "stream": False,
                    "options": {"temperature": 0.4, "num_predict": 2200}
                },
                timeout=180.0
            )
            if response.status_code != 200:
                raise Exception(f"Ollama error: {response.status_code}")
            raw = response.json()["message"]["content"].strip()

        if raw.startswith("```"):
            raw = re.sub(r'^```(?:json)?\s*', '', raw)
            raw = re.sub(r'\s*```$', '', raw)
            raw = raw.strip()

        items = json.loads(raw)
        out = []
        for item in items[:count]:
            if not isinstance(item, dict):
                continue
            out.append({
                "headline": str(item.get("headline", ""))[:120],
                "summary": str(item.get("summary", "")),
                "exam_angle": str(item.get("exam_angle", "")),
                "category": str(item.get("category", "General")),
                "source_url": str(item.get("source_url", "")),
            })
        return out
    except Exception as e:
        raise Exception(f"Current affairs generation failed: {str(e)}")
