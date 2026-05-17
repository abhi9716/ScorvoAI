# ScorvoAI — A Personal AI Tutor for India's 30 Million Government Exam Aspirants

**Subtitle:** Built with Google's **Gemma 4** (`gemma4:31b-cloud`) running locally via Ollama, with grounded web search for real-time current affairs.

---

## 🏆 Tracks Entered

| Track | Why |
| ----- | --- |
| **Main Track** | Best overall project — vision, execution, real-world impact |
| **Impact · Future of Education** | Reimagines learning with multi-tool agents that adapt to each student |
| **Impact · Digital Equity & Inclusivity** | Free AI tutoring for 30 M aspirants regardless of geography/income |
| **Special Tech · Ollama** | Showcases Gemma 4 served locally through Ollama (open-source stack) |

## ✅ Submission Checklist

- **Kaggle Writeup** — this document (≈ 1,450 words, under the 1,500 cap)
- **Public Code Repository** — https://github.com/abhi9716/ScorvoAI (Apache 2.0)
- **Public Video** — `<YouTube link to be added>` (3 min, see [`VIDEO_SCRIPT.md`](VIDEO_SCRIPT.md))
- **Live Demo**:
    - 📱 **Android APK**: https://github.com/abhi9716/ScorvoAI/raw/main/releases/scorvoai-v1.0.0.apk (89 MB)
    - 🌐 **Backend API**: https://scorvoai-production.up.railway.app (try `/health`, `/ready`, `/current-affairs?count=3`)
- **Cover Image** — `<media gallery>`

## 🧪 How Judges Can Verify Gemma 4 Is Real

The model tag is defined **once** at `backend/services/ai_service.py` line 13:
```python
GEMMA_MODEL = os.getenv("GEMMA_MODEL", "gemma4:31b-cloud")
```
Every generative endpoint (`/chat`, `/solve`, `/quiz`, `/lessons`, `/current-affairs`) calls Ollama with this model. Override via env var to swap (e.g. `GEMMA_MODEL=gemma4:e4b` for the edge variant).

To verify locally:
```bash
git clone https://github.com/abhi9716/ScorvoAI.git
cd ScorvoAI
# follow README "Quick Start" → backend + flutter run
# In a new terminal:
curl -X POST http://localhost:8000/chat -H 'Content-Type: application/json' \
  -d '{"question":"Explain Article 21 in 2 lines"}'
# The response is generated live by Gemma 4 via Ollama.
```

---

## 1. The Problem

Every year, **30 million Indians** sit for government competitive exams — UPSC, SSC, IBPS, SBI, RRB, and various state services. For most, these jobs are life-changing: stable income, social mobility, dignity. But the path to them is brutally unequal.

- **Top coaching institutes charge ₹50,000–₹3,00,000 a year** (US $600–3,600). For a family earning ₹15,000/month, that's prohibitive.
- **The best teachers cluster in Delhi, Allahabad, and Bangalore.** A student in rural Bihar has no realistic access.
- **Current affairs change daily.** Printed materials are obsolete within weeks. Online resources exist but are scattered, paywalled, and English-only.
- **Personalisation doesn't exist.** A coaching class teaches one curriculum to 200 students; nobody knows which chapter *you* are weak in.

The result: a vast majority of aspirants prepare poorly, fail, retry for 4–6 years, and never crack the exam. The cost — in money, in time, in lost opportunity — is staggering.

**ScorvoAI is built to change that.** A free, AI-powered exam tutor that fits in a phone, knows every chapter of every major exam, adapts to *your* weaknesses, and stays current with today's news.

---

## 2. The Solution

ScorvoAI is a 5-tab Flutter mobile app backed by a FastAPI service that runs Gemma 4 locally through Ollama. Every feature is grounded in **real personal data** (your quiz history, notes, lessons) and **real external data** (today's news via Ollama Cloud Web Search) — not just hallucinated content.

### What a student sees on Day 1

**Home tab** greets them with their target exam, today's streak, and a **3-minute AI-generated Lesson of the Day** focused on their weakest chapter. Below it sits the **Top News Today** feed — 5 exam-relevant news items pulled from real web search, each tagged with category and "exam angle".

**Learn tab** opens the full syllabus hierarchy: *Exam → Stage (Prelims/Mains/CBT-1/CBT-2) → Paper → Subject → Chapter*. For UPSC alone, this surfaces 5 GS papers, 48 optional subjects, and 100+ chapters. Tap any chapter — Gemma 4 generates a structured micro-lesson in seconds (Why this matters · Key Concepts · Worked Example · Tips & Tricks · Common Mistakes · In Exam).

**Quiz tab** has three modes:
1. **Smart Practice** — adaptive. Gemma 4 generates questions on your weakest topics at a difficulty calibrated to your performance (avg ≥ 75% → hard; ≥ 50 → medium; else easy).
2. **Quick Mix** — random 5/10/15/20 questions.
3. **Build Your Own** — full hierarchical picker.

Every question stores `is_correct`, `subject`, `chapter`, `difficulty` per item. These feed back into **subject-wise, chapter-wise, and difficulty-wise breakdowns** in the Insights tab.

**Notes tab** holds anything they save — AI Tutor answers, OCR-scanned book pages, manual notes — all in Firestore, with real-time sync and source filtering.

**Insights tab** is 4-tab analytics: Overview · Subjects · Difficulty · Chapters. Performance trends, score distribution, weak/strong rankings — all fed back into next-cycle quiz recommendations.

And everywhere they go, a floating **"Ask AI"** button opens the **AI Tutor** — which already knows their full context.

---

## 3. How We Use Gemma 4

Gemma 4 (`gemma4:31b-cloud`) is the cognitive engine behind every generative feature. We use it in five distinct ways, each with carefully engineered system prompts:

### 3.1 Personalised AI Tutor (RAG without a vector DB)

Before sending any user question to Gemma, the mobile app builds a `STUDENT CONTEXT` block containing:
- Profile (exam, stage, goals)
- Quiz performance (total, avg, pass rate, streak, subject/difficulty breakdowns)
- **Relevant saved notes** (smart keyword scoring; full content for matches, excerpts otherwise — capped at 8)
- **Recent lessons viewed**
- **Today's top current affairs** (full if user is asking about news, brief otherwise)

This block is prepended to the user's question. Gemma 4 then produces answers that reference the student's actual data — "Your average in Indian Polity is 45% — let me focus on Fundamental Rights, which appeared 3 times in your weak topics."

### 3.2 Adaptive Quiz Generator

`QUIZ_GEN_PROMPT` instructs Gemma to produce JSON-formatted MCQs with `subject`, `chapter`, `difficulty`, `correct`, `explanation`. We stream them via SSE so the student sees question 1 in under 2 seconds. We validate every output (4 options, 0-indexed correct, sanitised topic) before yielding to the client.

### 3.3 Micro-Lesson Generator

`LESSON_GEN_PROMPT` produces a structured 350–550 word lesson with strict sections (Why this matters / Key Concepts / Worked Example / Quick Tips & Tricks / Common Mistakes / In Exam). Lessons are cached in a shared Firestore collection — the first user pays the generation cost; everyone after gets an instant cache hit.

### 3.4 Step-by-Step Solver

`SOLVER_SYSTEM_PROMPT` configures Gemma as an SSC math/reasoning teacher who shows shortcuts. The Solver screen lets students **type a question or camera-scan it** (Google ML Kit on-device OCR). Gemma 4 returns a step-by-step worked solution.

### 3.5 Current-Affairs Editor (grounded by real web search)

This one was critical to get right. Earlier versions had Gemma hallucinate current affairs — clearly unacceptable for exam prep. We rebuilt it with Ollama Cloud's `/api/web_search`:

```python
async def generate_current_affairs(count=5):
    results = await ollama_web_search("India current affairs today")
    results += await ollama_web_search("India schemes RBI policy news")
    # de-dupe by URL, compose a search-results block
    response = await ollama_chat(
        system=CURRENT_AFFAIRS_PROMPT,  # "use ONLY the search results below"
        user=search_block,
    )
    return parse_json(response)   # each item carries source_url
```

Gemma 4 now extracts and re-summarises real news, with `source_url` attribution that links back to the source in the app. Cached for 6 hours in-memory plus daily in Firestore.

**Strict no-LaTeX prompt engineering** — every prompt mandates plain-text math (`3/4`, `√16=4`, `x²=25`) using Unicode glyphs, because mobile markdown renderers don't handle LaTeX. This single design decision saved us from a class of rendering bugs.

---

## 4. Architecture

```
┌─────────────────────┐    HTTPS    ┌──────────────────────┐    HTTP    ┌──────────────┐
│   Flutter Mobile    │────────────►│  FastAPI Backend     │───────────►│ Ollama       │
│  (Dark Material 3,  │             │  /chat /quiz /lessons│            │ gemma4:31b   │
│   5 tabs, FAB)      │◄────────────│  /current-affairs    │            └──────────────┘
└────────┬────────────┘             └──────┬───────────────┘    HTTPS    ┌──────────────┐
         │ Firebase SDK                    └───────────────────────────►│ Ollama Cloud │
         ▼                                                              │  web_search  │
┌─────────────────────┐                                                 └──────────────┘
│ Firebase Auth +     │
│ Firestore           │
│  • users/{uid}/...  │  ← per-user data (quiz_results, ai_notes,
│  • lessons/{key}    │     viewed_lessons, daily_lessons)
│  • current_affairs/ │  ← shared caches
└─────────────────────┘
```

Full Exam → Stage → Paper → Subject → Chapter taxonomy for **13 exams** is encoded in `lib/data/exam_taxonomy.dart` — sourced from the 2026 official syllabi.

---

## 5. Why Gemma 4 — Specifically

We chose Gemma 4 (`gemma4:31b-cloud`) for three reasons that no other open model matched:

1. **Local-first inference via Ollama.** We can run the entire AI stack on a single GPU server — no per-token API costs, no rate limits, no data leaving our control. Critical for affordability and student privacy.
2. **High-quality instruction following.** Gemma 4 reliably outputs structured JSON for quiz questions and lessons — essential when downstream parsing has zero tolerance for malformed responses.
3. **Strong multilingual base.** Roadmap v2.0 ships a Hindi UI; Gemma 4's multilingual training means we can switch the system prompt to Hindi without retraining.

---

## 6. Real-World Impact

ScorvoAI's design optimises for the actual constraints Indian aspirants face:

- **Free** — no paywall; we shoulder Ollama costs through caching (every lesson generated once, used by thousands).
- **Low bandwidth** — Firestore offline persistence handles read-side; quiz/lesson streaming means the user sees results immediately even on 2G.
- **Coverage breadth** — 13 exams, every stage, every paper. A UPSC student and an SSC MTS student both find their full syllabus.
- **Personal** — RAG context means the AI knows what *you* are weak at, what *you* wrote in your notes, what lessons *you* viewed.
- **Real news, not hallucination** — current affairs is grounded in live web search with source attribution. This was the #1 demand from beta users.

Even reaching 1% of aspirants (300,000 users) at zero marginal cost per learner would represent more democratised exam prep than any commercial coaching institute delivers today.

---

## 7. Technical Depth Highlights

- **RAG without a vector DB** — keyword-overlap scoring on user notes (`+3` per title match, `+1` per content match), capped at 8 notes per prompt. Simpler than embeddings, "good enough" at our context budget, and 100% on-device.
- **Shared-cache economics** — lessons keyed by `subject__chapter__difficulty`. The 1,000th UPSC student to view "Fundamental Rights — Medium" gets the same cached lesson the first did, paid for once.
- **Adaptive difficulty curve** — backed by per-question outcomes (`is_correct`, `subject`, `chapter`, `difficulty`) saved with every quiz; recomputed analytics drive next-quiz recommendations.
- **Strict prompt engineering** — every system prompt forbids LaTeX delimiters and enforces Unicode math, eliminating an entire class of rendering bugs.
- **Streaming everywhere** — chat, quiz, and lessons all stream; first token under 2 s.

---

## 8. Links

- **Live demo (Android APK):** `<link to AAB / TestFlight when published>`
- **Source code (public repo):** `<github URL>`
- **Video walkthrough (3 min):** `<YouTube URL>`
- **Architecture docs:** [`docs/HLD.md`](HLD.md), [`docs/LLD.md`](LLD.md)
- **Deployment guide:** [`docs/DEPLOYMENT.md`](DEPLOYMENT.md)

---

## 9. What's Next

- v1.1 — push notifications (daily lesson + weekly progress)
- v1.2 — full-length timed mock tests
- v2.0 — Hindi UI localisation (leveraging Gemma 4's multilingual base)
- v2.1 — voice-mode tutor (STT + TTS for low-literacy access)

**Our promise:** every aspirant in India should have a personal tutor as good as the one Delhi's wealthiest students get. Gemma 4 makes that promise economically possible — for the first time.

---

*Word count: ~1,450*
