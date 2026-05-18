## 1. The Problem

Every year, more than **30 million Indians** prepare for government exams — UPSC, SSC, IBPS, SBI, RRB, and various State PCS. For most families, clearing one of these exams completely changes their future: a stable salary, financial security, and a better life for the next generation.

But access to good preparation is still deeply unfair.

The best coaching institutes charge between **₹50,000 and ₹3,00,000 a year**, and the top teachers cluster in a few neighbourhoods — Mukherjee Nagar, Allahabad, Bangalore. Students in small towns and villages study from outdated PDFs, scattered YouTube videos, or photocopied notes. Current affairs change every day, books become obsolete within weeks, and most learning platforms still treat every student the same.

A student struggling with reasoning gets the same content as someone weak in history. Personal guidance is almost nonexistent unless you can afford expensive coaching.

---

## 2. What We Built

**ScorvoAI** is a free AI-powered Android app that gives every government exam aspirant their own personal tutor.

The app is built with **Flutter** on the frontend and **FastAPI** on the backend, deployed on Railway. Every intelligent feature is powered by **Google's Gemma 4 (`gemma4:31b-cloud`)** through **Ollama Cloud**.

Instead of stitching together a different AI service for every feature, we designed ScorvoAI around a **single unified `GEMMA_MODEL`** that powers the entire learning experience — quizzes, lessons, the tutor, the solver, and current affairs. One model, five carefully engineered prompts, one consistent personality across the whole app.

---

## 3. What ScorvoAI Can Do

### 🎯 Adaptive AI Quizzes
ScorvoAI learns how a student performs over time. If someone struggles with polity but performs well in quantitative aptitude, the app automatically rebalances practice questions and difficulty (avg ≥ 75 % → hard, ≥ 50 % → medium, else easy). Questions are streamed fresh from Gemma 4 every time, so practice never feels repetitive.

### 📚 AI Micro-Lessons
Students can pick any chapter from the syllabus of **13 major government exams** and instantly get a 350–550 word AI-generated lesson designed for quick learning. Every lesson follows the same structure — **Why this matters → Key Concepts → Worked Example → Tips & Tricks → Common Mistakes → In Exam**. Lessons are cached in Firestore, so the 1000th user reads the same lesson the first user paid to generate.

### 🤖 Personalised AI Tutor
The tutor remembers context from the student's entire learning journey — quiz history, weak topics, saved notes, recently viewed chapters, and today's current affairs. Instead of generic chatbot answers, students get responses tailored to their preparation level and goals.

> *"Your average in Indian Polity is 45 % — let me focus on Fundamental Rights, which appeared in 3 of your weak topics."*

### 📰 Real-Time Current Affairs
Current affairs are the hardest part of government exam preparation because the information changes every day. ScorvoAI uses **Ollama Cloud's Web Search API** to fetch live news, and Gemma 4 extracts only the exam-relevant points **with source attribution**. Students no longer have to scroll through news apps for hours.

### 📊 AI Insights & Performance Tracking
Most students only know whether they passed or failed a mock test — not whether they are actually improving. ScorvoAI analyses accuracy, revision consistency, weak topics, and quiz patterns to generate personalised insights: subjects needing urgent revision, strongest scoring areas, consistency trends, readiness indicators. Preparation becomes data-driven instead of guess-driven.

### 🔍 Question Solver
Students can solve doubts instantly — type a question or **scan it with the camera** using Google ML Kit on-device OCR. ScorvoAI returns a step-by-step worked solution for aptitude, reasoning, GK, and other exam questions in plain, simple language. Perfect for printed questions from books, newspapers, or coaching material.

---

## 4. How We Use Gemma 4

Gemma 4 is the cognitive engine behind every generative feature. Five system prompts, one model:

1. **`AI_TUTOR_PROMPT`** — receives a `STUDENT CONTEXT` block (profile, quiz stats, top-matched notes, viewed lessons, today's news) prepended to the user's question. This is RAG without a vector DB.
2. **`QUIZ_GEN_PROMPT`** — produces JSON-formatted MCQs with `subject`, `chapter`, `difficulty`, `correct`, `explanation`. Streamed via SSE; the student sees question 1 in under 2 seconds.
3. **`LESSON_GEN_PROMPT`** — produces structured 350–550 word micro-lessons. Cached in Firestore by `subject__chapter__difficulty`.
4. **`SOLVER_SYSTEM_PROMPT`** — configures Gemma as an SSC math/reasoning teacher who explains shortcuts step-by-step.
5. **`CURRENT_AFFAIRS_PROMPT`** — receives a block of real web-search results and is instructed to *use ONLY those results*. Output is JSON with `source_url` attribution. **No more hallucinated news.**

**Strict no-LaTeX prompt engineering** — every prompt mandates plain-text math (`3/4`, `√16=4`, `x²=25`) using Unicode glyphs, because mobile markdown renderers don't handle LaTeX. One design rule, one entire class of rendering bugs eliminated.

---

## 5. How Judges Can Verify Gemma 4 Is Real

The model tag is defined **once** in `backend/services/ai_service.py:13`:
```python
GEMMA_MODEL = os.getenv("GEMMA_MODEL", "gemma4:31b-cloud")
```
Every generative endpoint (`/chat`, `/solve`, `/quiz`, `/lessons`, `/current-affairs`) routes through it. Override via env var (`GEMMA_MODEL=gemma4:e4b`) to swap to the edge variant.

```bash
git clone https://github.com/abhi9716/ScorvoAI.git
cd ScorvoAI   # follow README "Quick Start"
curl -X POST http://localhost:8000/chat \
     -H 'Content-Type: application/json' \
     -d '{"question":"Explain Article 21 in 2 lines"}'
# Response is generated live by Gemma 4 via Ollama.
```

---

## 6. Architecture

```
┌─────────────────────┐    HTTPS    ┌──────────────────────┐    HTTP    ┌──────────────┐
│   Flutter Mobile    │────────────►│  FastAPI Backend     │───────────►│  Ollama      │
│  (Dark M3, 5 tabs)  │             │  /chat /quiz /lessons│            │ gemma4:31b   │
└────────┬────────────┘             │  /current-affairs    │            └──────────────┘
         │ Firebase SDK             └──────┬───────────────┘    HTTPS    ┌──────────────┐
         ▼                                 └───────────────────────────►│ Ollama Cloud │
┌─────────────────────┐                                                 │  web_search  │
│ Firebase Auth +     │                                                 └──────────────┘
│ Firestore           │
│  • users/{uid}/...  │  ← per-user data (quiz_results, ai_notes, viewed_lessons)
│  • lessons/{key}    │  ← shared lesson cache
│  • current_affairs/ │  ← daily news cache
└─────────────────────┘
```

The full **Exam → Stage → Paper → Subject → Chapter** taxonomy for 13 exams lives in `lib/data/exam_taxonomy.dart` — sourced from official 2026 syllabi.

---

## 7. Technical Depth Highlights

- **RAG without a vector DB** — keyword-overlap scoring on user notes (+3 per title match, +1 per content match), capped at 8 notes per prompt. Simpler than embeddings, "good enough" at our context budget, 100 % on-device.
- **Shared-cache economics** — lessons keyed by `subject__chapter__difficulty`. The 1,000th UPSC student to view "Fundamental Rights — Medium" reads the same cached lesson the first did, paid for once. This is how the app stays free.
- **Adaptive difficulty curve** — per-question outcomes (`is_correct`, `subject`, `chapter`, `difficulty`) feed back into the next-quiz prompt.
- **Streaming everywhere** — chat, quiz, and lesson generation all stream via SSE; first token in under 2 seconds even on 2G.
- **Camera OCR** — Google ML Kit's on-device text recognition lets students point their phone at a printed question and get a solution.

---

## 8. Why Gemma 4 — Specifically

1. **Cost-controllable inference via Ollama Cloud.** No per-token surprises, no rate-limit panic. We can absorb the cost and keep the app free.
2. **High-quality structured output.** Gemma 4 reliably emits valid JSON for quizzes and lessons — non-negotiable when downstream parsing has zero tolerance for malformed responses.
3. **Strong multilingual base.** Roadmap v2.0 ships a Hindi UI; Gemma 4's multilingual training means we swap the system prompt to Hindi without retraining.

---

## 9. Why It Matters

ScorvoAI was built for the students who are usually invisible to edtech.

A girl studying in rural Bihar, a student living in a Mumbai chawl, a working mother preparing after office hours in Coimbatore — they should have access to the same quality of guidance as someone paying lakhs for coaching in Delhi.

The app is **free**, **mobile-first**, **low-bandwidth friendly**, and built specifically for Indian government exams. Firestore offline persistence handles flaky 2G; lesson caching means our marginal cost per learner trends toward zero.

If ScorvoAI reaches even **1 % of India's aspirants** — around 300,000 students — that's 300,000 first-generation learners getting personalised AI tutoring that simply did not exist for them yesterday.

Open models like **Gemma 4** and affordable hosted inference through **Ollama Cloud** are what made this possible. For the first time, building a truly scalable and accessible AI tutor for India feels achievable.

---

## 10. What's Next

- **v1.1** — push notifications (daily lesson + weekly progress)
- **v1.2** — full-length timed mock tests
- **v2.0** — Hindi UI localisation (leveraging Gemma 4's multilingual base)
- **v2.1** — voice-mode tutor (STT + TTS for low-literacy access)

---

## 11. Attribution

ScorvoAI is built on Google's open **Gemma 4** family of models, accessed at runtime via Ollama Cloud. We do not bundle, retrain, or redistribute the Gemma weights.

**Gemma is a trademark of Google LLC.** ScorvoAI is neither endorsed by nor affiliated with Google. Use of Gemma is governed by the [Gemma Terms of Use](https://ai.google.dev/gemma/terms).

---

**Our promise:** every aspirant in India should have a personal tutor as good as the one Delhi's wealthiest students get. Gemma 4 makes that promise economically possible — for the first time.
