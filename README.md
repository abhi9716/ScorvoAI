# ScorvoAI

> AI-powered exam preparation platform for Indian government competitive exams (UPSC · SSC · IBPS/SBI · RRB · State PCS).

<p align="center">
  <strong>Flutter mobile app (dark + light) · FastAPI backend · Built with Gemma 4 · Firebase</strong>
</p>

<p align="center">
  <a href="https://ai.google.dev/gemma"><img alt="Built with Gemma" src="https://img.shields.io/badge/Built%20with-Gemma%204-6366f1"></a>
  <a href="https://ollama.com"><img alt="Served via Ollama" src="https://img.shields.io/badge/Served%20via-Ollama%20Cloud-000000"></a>
  <a href="LICENSE"><img alt="License: Apache 2.0" src="https://img.shields.io/badge/License-Apache%202.0-blue"></a>
  <a href="https://scorvoai-production.up.railway.app/health"><img alt="Backend live" src="https://img.shields.io/badge/backend-live-success"></a>
</p>

## 📲 Try it now

| Resource | Link |
| -------- | ---- |
| **Android APK** (89 MB, signed) | [Download `scorvoai-v1.0.0.apk`](https://github.com/abhi9716/ScorvoAI/raw/main/releases/scorvoai-v1.0.0.apk) |
| **Live Backend** | https://scorvoai-production.up.railway.app |
| **Health check** | `curl https://scorvoai-production.up.railway.app/health` |
| **Diagnostic** | `curl https://scorvoai-production.up.railway.app/ready \| jq .` |
| **Full E2E test** | `./backend/test_endpoints.sh https://scorvoai-production.up.railway.app` |

> Install the APK on any Android 7+ device. Sign in with Google → pick your exam → done. The app talks to the live backend automatically.

---

## ✨ Features

- **🏠 Smart Home** — personalised greeting, streak/quizzes/avg stats, AI-generated **Lesson of the Day**, and **real Top News Today** (Ollama Cloud Web Search → grounded summarisation with source links).
- **📚 Learn** — pick any chapter from full syllabi for **13 exams**; 3-minute AI micro-lessons (cached and shared across all users).
- **⚡ Quiz** — three modes: **Smart Practice** (AI picks weak topics + adaptive difficulty), **Quick Mix** (random 5/10/15/20 questions), and **Build Your Own** with the full *Exam → Stage → Paper → Subject → Chapter* picker.
- **📝 Notes** — Firestore-backed vault for AI Tutor answers, OCR-scanned text, and manual notes; real-time sync, swipe-delete, multi-source filter.
- **📊 Insights** — 4 tabs: Overview · Subjects · Difficulty · Chapters — fl_chart trend lines, distribution bars, weak/strong rankings.
- **🤖 AI Tutor** — context-aware chat: every answer is grounded in your profile, quiz history, weak topics, saved notes, recent lessons, and today's news (RAG without a vector DB).
- **🧮 Question Solver** — type or **camera-scan** any question; step-by-step worked solution with shortcuts.
- **🌗 Dark + Light themes** — Profile tab → Appearance toggle. Preference persists across launches. Every text colour has been audited for contrast in both modes.
- **🔐 Google Sign-In** — Firebase Auth, all user data stored in Firestore.

---

## 🏗️ Tech Stack

| Layer    | Tech                                                          |
| -------- | ------------------------------------------------------------- |
| Mobile   | Flutter 3.x (Dart 3), Material 3, dark+light theme, fl_chart, gpt_markdown, image_picker, google_mlkit_text_recognition |
| Auth     | Firebase Auth + Google Sign-In                                |
| Database | Cloud Firestore                                               |
| Backend  | FastAPI · Uvicorn · httpx                                     |
| LLM      | **Gemma 4** (`gemma4:31b-cloud`) via **Ollama Cloud** (no local Ollama required) |
| Search   | Ollama Cloud `/api/web_search`                                |
| OCR      | Google ML Kit (on-device)                                     |
| Hosting  | Railway (backend Dockerfile) · GitHub (APK & docs)            |

See [`docs/HLD.md`](docs/HLD.md) for architecture and [`docs/LLD.md`](docs/LLD.md) for implementation details.

---

## 🚀 Quick Start

### Prerequisites

- **Flutter** 3.10+ ([install](https://docs.flutter.dev/get-started/install))
- **Python** 3.10+ with `pip`
- **Firebase project** with Authentication (Google) and Firestore enabled
- **Ollama Cloud API key** (free at https://ollama.com/settings/keys) — used for both `/api/chat` and `/api/web_search`

> 💡 **You do NOT need to install Ollama locally.** ScorvoAI hits Ollama Cloud directly with a Bearer token. See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) §2.3.

### 1. Clone & install

```bash
git clone git@github.com:abhi9716/ScorvoAI.git
cd ScorvoAI
```

### 2. Backend

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

**Create `backend/.env`** (gitignored):

```bash
OLLAMA_API_KEY=oa_xxxxxxxxxxxxxxxxxxxxxxxx     # https://ollama.com/settings/keys
OLLAMA_BASE=https://ollama.com                  # cloud-direct (recommended)
CORS_ORIGINS=*                                  # tighten in production
# GEMMA_MODEL=gemma4:31b-cloud                  # override only if you know what you're doing
```

Run a pre-deploy sanity check (verifies env vars, Ollama reachability, model availability, end-to-end inference):

```bash
python preflight.py
# → ✓ All checks passed — safe to deploy
```

Start the server:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
curl http://localhost:8000/health      # → {"status":"ok"}
curl http://localhost:8000/ready       # → {"ready":true, "checks":{...}}
```

Run the full smoke suite:

```bash
./test_endpoints.sh                     # tests local backend (11 endpoints)
./test_endpoints.sh https://scorvoai-production.up.railway.app   # or test prod
```

### 3. Firebase (auth + Firestore)

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli

cd mobile
firebase login
flutterfire configure --project=your-firebase-project-id
```

This **auto-generates two gitignored secret files**:

| File                                            | Purpose                                  |
| ----------------------------------------------- | ---------------------------------------- |
| `mobile/lib/firebase_options.dart`              | Firebase SDK config for Flutter          |
| `mobile/android/app/google-services.json`       | Firebase config for Android (gms plugin) |

In the Firebase Console:
1. **Authentication → Sign-in method** → enable Google
2. **Firestore Database** → create (production mode) → paste the rules from [`docs/LLD.md`](docs/LLD.md) §3.4
3. **Project settings → Android app** → add **SHA-1 and SHA-256** fingerprints:
   ```bash
   cd mobile/android && ./gradlew signingReport
   ```

### 4. Configure API base URL

Edit `mobile/lib/config.dart`. The default points at the live Railway backend so you can run immediately:

```dart
const String apiBaseUrl = 'https://scorvoai-production.up.railway.app';

// Or for local backend dev:
// const apiBaseUrl = 'http://10.0.2.2:8000';     // Android emulator → host
// const apiBaseUrl = 'http://<LAN-IP>:8000';     // physical device on Wi-Fi
```

### 5. Run the app

```bash
cd mobile
flutter pub get
flutter run
```

Toggle dark/light via **Profile tab → Appearance switch**.

---

## 🔐 Required Secret Files (Reference)

All gitignored — generate or create each one before building.

| # | File / Var | Where it goes | How to obtain | Required for |
| - | ---------- | ------------- | ------------- | ------------ |
| 1 | `OLLAMA_API_KEY` | `backend/.env` *(env var)* | https://ollama.com/settings/keys (free) | All AI endpoints + web search |
| 2 | `backend/.env` | `backend/.env` | Create from template above | Backend runtime config |
| 3 | `mobile/lib/firebase_options.dart` | `mobile/lib/` | `flutterfire configure --project=<id>` | Firebase init in Flutter |
| 4 | `mobile/android/app/google-services.json` | Android app module | `flutterfire configure` generates it | Firebase on Android |
| 5 | `mobile/ios/Runner/GoogleService-Info.plist` | iOS Runner *(future)* | `flutterfire configure` generates it | Firebase on iOS |
| 6 | `mobile/android/key.properties` | Android root | Manually — see template | Release signing |
| 7 | Upload keystore `.jks` | Anywhere safe | `keytool -genkey ...` | Release signing |
| 8 | SHA-1 + SHA-256 fingerprints | Firebase Console → Android app | `cd mobile/android && ./gradlew signingReport` | Google Sign-In to work |

### Template: `backend/.env`

```bash
OLLAMA_API_KEY=oa_xxxxxxxxxxxxxxxxxxxxxxxx
OLLAMA_BASE=https://ollama.com
CORS_ORIGINS=*
```

### Template: `mobile/android/key.properties` (for release builds)

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/absolute/path/to/scorvoai-upload.jks
```

### Pre-push leak check

```bash
git status --porcelain | grep -iE 'google-services\.json|firebase_options\.dart|\.env$|key\.properties|\.jks$|\.keystore$'
# Should print nothing — if it does, those files would be committed.
```

---

## 📦 Production Deployment

Full guide → [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)

### Backend → Railway (current live deploy)

```bash
cd backend
railway login
railway init
railway variables --set OLLAMA_API_KEY=oa_xxx \
                  --set OLLAMA_BASE=https://ollama.com \
                  --set CORS_ORIGINS=*
railway up                                 # builds Dockerfile + deploys
railway domain                             # mints HTTPS URL
```

Live reference: https://scorvoai-production.up.railway.app

### Mobile → Google Play Store

1. Create an upload keystore (`keytool -genkey ...`)
2. Create `mobile/android/key.properties`
3. Wire signing config in `android/app/build.gradle.kts` (see Deployment doc)
4. Update `apiBaseUrl` in `lib/config.dart` to your HTTPS URL
5. Build & upload:
   ```bash
   flutter build appbundle --release
   # upload build/app/outputs/bundle/release/app-release.aab to Play Console
   ```

---

## 🗂️ Repository Structure

```
ScorvoAI/
├── backend/                # FastAPI service (Dockerfile, runs on Railway)
│   ├── main.py             # app + router includes + startup logging
│   ├── routes/             # chat, solve, quiz, lessons, current_affairs, notes
│   ├── services/
│   │   └── ai_service.py   # Ollama Cloud client; GEMMA_MODEL constant; all prompts
│   ├── preflight.py        # pre-deploy sanity check (5 checks)
│   ├── test_endpoints.sh   # E2E smoke test (11 endpoints, pass/fail)
│   ├── Dockerfile          # production image, runs as non-root, healthcheck
│   └── railway.json        # Railway deploy config
├── mobile/                 # Flutter app
│   ├── lib/
│   │   ├── theme/          # AppTheme.dark / .light + ThemeController
│   │   ├── data/           # exam_taxonomy (13 exams, full hierarchy)
│   │   ├── models/         # UserProfile
│   │   ├── services/       # api, firestore, auth
│   │   └── screens/        # main_shell + 11 screens
│   └── android/            # signing config goes in key.properties
├── docs/
│   ├── HLD.md              # high-level design
│   ├── LLD.md              # low-level design + API contracts
│   ├── DEPLOYMENT.md       # production deployment guide
│   ├── SUBMISSION.md       # Kaggle Gemma 4 Impact Challenge writeup
│   └── VIDEO_SCRIPT.md     # 3-min video pitch script
├── releases/
│   └── scorvoai-v1.0.0.apk # published Android build
├── LICENSE                 # Apache 2.0
├── NOTICE                  # third-party attribution
└── README.md
```

---

## 🔌 API Reference (summary)

| Method | Endpoint                       | Description |
| ------ | ------------------------------ | ----------- |
| GET    | `/health`                      | Liveness probe (cheap, always returns 200 if process is up) |
| GET    | `/ready`                       | Readiness probe — checks Ollama reachability, API key, model availability |
| POST   | `/chat` / `/chat/stream`       | AI tutor chat (Gemma 4) |
| POST   | `/solve`                       | Step-by-step problem solver |
| GET    | `/quiz` / `/quiz/stream`       | Generate AI quiz questions (streaming SSE) |
| POST   | `/quiz/submit`                 | Submit answers, get scored result |
| GET    | `/quiz/subjects`               | Legacy seed subject list |
| POST   | `/lessons` / `/lessons/stream` | AI-generated 3-min micro-lessons |
| GET    | `/current-affairs`             | Today's top news (real, sourced from Ollama Cloud web search) |
| GET    | `/analyze` / `/analyze/stats`  | Legacy SQL-backed stats |
| GET    | `/daily`, POST `/daily/submit` | Legacy daily challenge |
| `/notes/*`                     | Legacy SQLite notes (mobile uses Firestore now) |

Full request/response shapes → [`docs/LLD.md`](docs/LLD.md) §3.2.

---

## 🧪 Local Testing

```bash
# Backend pre-deploy gate
cd backend && python preflight.py

# Full E2E API suite (local or prod)
./backend/test_endpoints.sh
./backend/test_endpoints.sh https://scorvoai-production.up.railway.app

# Mobile static analysis
cd mobile && flutter analyze

# Mobile debug build
flutter build apk --debug

# Hot reload on connected device
flutter run
```

---

## 🛡️ Security & Privacy

- Per-user Firestore subcollections; security rules enforce `request.auth.uid == uid`
- No passwords stored (Google Sign-In only)
- OCR is on-device (Google ML Kit) — text never leaves the phone
- Notes / quiz data / lessons-viewed are all per-user under `users/{uid}/…`
- Shared caches (`lessons/*`, `current_affairs/*`) contain no user-identifying data
- Backend talks to Ollama Cloud over HTTPS with Bearer auth
- Mobile config defaults to HTTPS prod URL; local dev URLs are commented out

---

## 📜 License

ScorvoAI source code is licensed under the **Apache License 2.0** — see [`LICENSE`](LICENSE).

Use of the **Gemma 4** model is separately governed by the **Gemma Terms of Use** — https://ai.google.dev/gemma/terms. ScorvoAI does not bundle or redistribute the Gemma weights; the backend calls Ollama Cloud's hosted endpoint at runtime.

Third-party attributions are listed in [`NOTICE`](NOTICE).

---

## 🤖 Built with Gemma

This project is built on Google's open **Gemma 4** family of models (`gemma4:31b-cloud`), accessed via **Ollama Cloud**'s `/api/chat` endpoint with Bearer authentication. The model tag is centralised in `backend/services/ai_service.py` (constant `GEMMA_MODEL`) so it can be overridden via the `GEMMA_MODEL` env var. All generative features — AI Tutor, quiz generation, micro-lessons, solver, current-affairs extraction — invoke Gemma 4 through this single constant.

Submitted to the **Gemma 4 Impact Challenge** (May 2026). See [`docs/SUBMISSION.md`](docs/SUBMISSION.md) for the competition writeup.

> **Gemma is a trademark of Google LLC.** ScorvoAI is neither endorsed by nor affiliated with Google. We use Gemma in accordance with the [Gemma Terms of Use](https://ai.google.dev/gemma/terms).

---

## 🙏 Acknowledgements

Syllabus references: [UPSC](https://upsc.gov.in), [SSC](https://ssc.gov.in), [IBPS](https://ibps.in), [SBI Careers](https://sbi.co.in/careers), [RRB](https://rrbcdg.gov.in). LLM: [Gemma 4](https://ai.google.dev/gemma) via [Ollama Cloud](https://ollama.com). Charts: [fl_chart](https://pub.dev/packages/fl_chart). Markdown: [gpt_markdown](https://pub.dev/packages/gpt_markdown). Full third-party list in [`NOTICE`](NOTICE).
