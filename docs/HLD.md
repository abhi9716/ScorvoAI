# ScorvoAI — High-Level Design (HLD)

**Version:** 1.0.0
**Owner:** ScorvoAI Team
**Audience:** Engineering, PM, leadership

---

## 1. Product Overview

ScorvoAI is an AI-powered exam-prep platform for Indian government competitive exams (UPSC, SSC, IBPS/SBI, RRB, State PCS). It combines an LLM tutor, adaptive quizzes, AI-generated micro-lessons, a personal notes vault, and a real-time current affairs feed — all personalised to each student's exam, stage, and performance history.

**Target users:** Aspirants preparing for Indian government job exams (≈ 30 M+ candidates per year).

**Core value propositions:**
1. **Personalisation** — every interaction is conditioned on the student's exam stage, weak topics, recent activity.
2. **Real content, not hallucination** — current affairs come from a live web search grounded summarisation, not the model's training cut-off.
3. **Comprehensive coverage** — full syllabus hierarchy (Exam → Stage → Paper → Subject → Chapter) for 12 major exams.

---

## 2. System Context

```
┌─────────────────────┐         ┌───────────────────────────┐         ┌──────────────────┐
│   Flutter Mobile    │ ──HTTP─►│  FastAPI Backend          │ ───────►│  Ollama (local)  │
│   (Android/iOS)     │ ◄──────│  • /chat /quiz /lessons   │ ───────►│  Ollama Cloud    │
│                     │         │  • /current-affairs       │         │  (web_search)    │
└──────────┬──────────┘         │  • /notes /solve          │         └──────────────────┘
           │                    └──────────┬────────────────┘
           │ Firebase SDKs                 │ httpx
           ▼                               ▼
┌─────────────────────┐         ┌───────────────────────────┐
│  Firebase Auth      │         │  SQLite (legacy notes)    │
│  Firestore          │         │  Uploads (image OCR)      │
│  (user data, lessons│         └───────────────────────────┘
│   cache, analytics) │
└─────────────────────┘
```

**Trust boundaries:**
- Mobile ↔ Backend: HTTPS in prod, plain HTTP for local dev (`usesCleartextTraffic` for dev only).
- Backend ↔ Ollama Cloud: Bearer token (`OLLAMA_API_KEY`).
- Mobile ↔ Firebase: Google-managed auth tokens + Firestore security rules.

---

## 3. Major Components

### 3.1 Mobile App (Flutter)
- **5 main tabs:** Home · Learn · Quiz · Notes · Insights
- **Auxiliary screens:** AI Tutor (chat), Question Solver, Profile, Onboarding
- **State management:** Local `setState` per screen + Firestore streams for live data
- **Theme:** Dark + indigo, defined centrally in `lib/theme/app_theme.dart`
- **Persistent FAB:** "Ask AI" floats on every non-home tab

### 3.2 Backend (FastAPI)
| Module                     | Responsibility                                                          |
| -------------------------- | ----------------------------------------------------------------------- |
| `routes/chat`              | Synchronous + streaming LLM chat                                        |
| `routes/solve`             | Step-by-step problem solver                                             |
| `routes/quiz`              | AI-generated MCQs with streaming, multiple subject/chapter/difficulty params |
| `routes/lessons`           | AI-generated 3-min micro-lessons (streaming + non-streaming)            |
| `routes/current_affairs`   | Real news via Ollama web search → LLM extraction → JSON                 |
| `routes/notes`             | Legacy notes endpoints (kept for compatibility)                         |
| `routes/analysis` `/daily` | Legacy stats / daily quiz                                               |
| `services/ai_service`      | All Ollama interaction; system prompts; question validation             |

### 3.3 Data Layer

**Firestore (source of truth for user data):**
- `users/{uid}` — profile (name, email, exam, goals)
- `users/{uid}/quiz_results` — every quiz with per-question outcomes
- `users/{uid}/ai_notes` — saved notes
- `users/{uid}/viewed_lessons` — lessons opened + view count
- `users/{uid}/daily_lessons/{YYYY-MM-DD}` — personalised daily lesson
- `lessons/{subject__chapter__difficulty}` — shared lesson cache
- `current_affairs/{YYYY-MM-DD}` — shared daily news cache

**SQLite (backend, legacy):** notes for users who used the app pre-Firebase. Read-only going forward.

### 3.4 AI Layer
- **Local Ollama** at `http://localhost:11434` — model `gemma4:31b-cloud` runs all generative tasks (chat, solve, quiz gen, lesson gen).
- **Ollama Cloud Web Search** at `https://ollama.com/api/web_search` — used by current-affairs only. Returns title/url/content; the LLM then extracts and re-summarises with `source_url` attribution.

---

## 4. Key Flows

### 4.1 Adaptive Quiz Flow
1. Mobile loads `getInsights(uid)` from Firestore → returns `weak_topics`, `avg_score`, `subject/difficulty/chapter` breakdowns.
2. Quiz tab's "Smart Practice" card picks difficulty (`avg≥75 → hard`, `≥50 → medium`, else `easy`) and weak-topic subjects.
3. `ApiService.getQuizStream` calls backend `/quiz/stream` (SSE) with those parameters.
4. Each question arrives, user answers, on submit each question is enriched with `is_correct`/`user_answer` and saved to `users/{uid}/quiz_results`.
5. Insights recompute aggregations next time `getInsights` runs.

### 4.2 Lesson Generation Flow
1. User picks subject + chapter + difficulty in Learn tab.
2. App checks `lessons/{key}` shared cache → returns immediately if hit.
3. Cache miss → calls `/lessons/stream`, streams tokens, displays markdown live.
4. On completion: writes to shared `lessons/{key}` and per-user `users/{uid}/viewed_lessons/{key}`.

### 4.3 Current Affairs Flow
1. Home tab on load checks `current_affairs/{today}` in Firestore.
2. If empty, calls backend `/current-affairs?count=5`.
3. Backend: 6-hour in-memory cache → miss → `ollama_web_search(query)` twice with different queries → de-dupe → LLM extraction with `CURRENT_AFFAIRS_PROMPT` → returns JSON with `source_url`.
4. Mobile writes result to Firestore for shared access by all users that day.

### 4.4 RAG-style Personalised Chat
Before sending each user message to `/chat/stream`, the mobile app builds a `STUDENT CONTEXT` block containing:
- Profile: target exam, study goals
- Quiz performance: total, avg, pass rate, streak
- Strengths/weaknesses + subject + difficulty breakdowns
- **Relevant notes** (smart keyword scoring; full content for matches)
- Recent lessons viewed
- Today's current affairs (full if user is asking about news, brief otherwise)

The context block is prepended to the user's actual question so the LLM answers with full personal context.

---

## 5. Non-Functional Requirements

| Concern         | Approach |
| --------------- | -------- |
| **Latency**     | Streaming everywhere (chat, quiz, lesson). User sees first token in < 2 s. |
| **Availability**| Stateless backend → horizontal scale; Ollama is the bottleneck — pin to dedicated host. |
| **Cost**        | Shared lesson + current-affairs cache amortises generation cost across all users. |
| **Offline**     | Firestore offline persistence handles read-side; writes queue and sync on reconnect. |
| **Privacy**     | Per-user Firestore subcollections; security rules enforce `auth.uid == uid`. |
| **Auth**        | Google Sign-In via Firebase Auth; no passwords stored. |
| **Observability** | Backend stdout logs; Firebase Crashlytics on mobile (to enable). |

---

## 6. Tech Stack Summary

| Layer    | Tech |
| -------- | ---- |
| Mobile   | Flutter 3.x (Dart 3), Material 3, fl_chart, gpt_markdown, image_picker, google_mlkit_text_recognition |
| Auth     | Firebase Auth + Google Sign-In |
| Database | Cloud Firestore (primary), SQLite (legacy backend notes) |
| Backend  | FastAPI 0.115, Uvicorn, httpx |
| AI       | Ollama (local) + Ollama Cloud Web Search |
| OCR      | Google ML Kit (on-device) + Tesseract (legacy backend) |

---

## 7. Future Roadmap

| Phase | Item |
| ----- | ---- |
| v1.1  | Push notifications for daily lesson, weekly progress digest |
| v1.2  | Mock test mode (full-length timed papers) |
| v1.3  | Discussion forum / per-question explanations from community |
| v2.0  | iOS launch + Hindi UI localisation |
| v2.1  | Voice-mode tutor (speech-to-text question + TTS answer) |
