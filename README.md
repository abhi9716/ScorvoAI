# ScorvoAI

> AI-powered exam preparation platform for Indian government competitive exams (UPSC · SSC · IBPS/SBI · RRB · State PCS).

<p align="center">
  <strong>Dark-themed Flutter mobile app · FastAPI backend · Ollama LLM · Firebase</strong>
</p>

---

## ✨ Features

- **🏠 Smart Home** — personalised greeting, streak/quizzes/avg stats, AI-generated **Lesson of the Day**, and **real Top News Today** (powered by Ollama Cloud Web Search).
- **📚 Learn** — pick any chapter from full syllabi for 12 exams; 3-minute AI micro-lessons (cached and shared across all users).
- **⚡ Quiz** — three modes: **Smart Practice** (AI picks weak topics + adaptive difficulty), **Quick Mix** (random 5/10/15/20 questions), and **Build Your Own** with the full Exam → Stage → Paper → Subject → Chapter picker.
- **📝 Notes** — Firestore-backed vault for AI Tutor answers, OCR-scanned text, and manual notes; real-time sync, swipe-delete, multi-source filter.
- **📊 Insights** — 4 tabs: Overview · Subjects · Difficulty · Chapters — fl_chart trend lines, distribution bars, weak/strong rankings.
- **🤖 AI Tutor** — context-aware chat: every answer is grounded in your profile, quiz history, weak topics, saved notes, recent lessons, and today's news (RAG without a vector DB).
- **🧮 Question Solver** — type or **camera-scan** any question; step-by-step worked solution with shortcuts.
- **🔐 Google Sign-In** — Firebase Auth, all user data stored in Firestore.

---

## 🏗️ Tech Stack

| Layer    | Tech                                                          |
| -------- | ------------------------------------------------------------- |
| Mobile   | Flutter 3.x (Dart 3), Material 3, fl_chart, gpt_markdown, image_picker, google_mlkit_text_recognition |
| Auth     | Firebase Auth + Google Sign-In                                |
| Database | Cloud Firestore                                               |
| Backend  | FastAPI · Uvicorn · httpx                                     |
| LLM      | Ollama (`gemma4:31b-cloud`)                                   |
| Search   | Ollama Cloud Web Search                                       |
| OCR      | Google ML Kit (on-device)                                     |

See [`docs/HLD.md`](docs/HLD.md) for architecture and [`docs/LLD.md`](docs/LLD.md) for implementation details.

---

## 🚀 Quick Start

### Prerequisites

- **Flutter** 3.10+ ([install](https://docs.flutter.dev/get-started/install))
- **Python** 3.10+ with `pip`
- **Ollama** running locally with `gemma4:31b-cloud` model pulled
- **Firebase project** with Authentication (Google) and Firestore enabled
- **Ollama Cloud API key** for real-time news (free at https://ollama.com/settings/keys)

### 1. Clone & install

```bash
git clone https://github.com/<your-org>/ScorvoAI.git
cd ScorvoAI
```

### 2. Backend

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
export OLLAMA_API_KEY=oa_xxx                # required for live current affairs
export CORS_ORIGINS="*"                     # tighten in production
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Verify: `curl http://localhost:8000/health` → `{"status":"ok"}`

### 3. Firebase

```bash
# install once
npm install -g firebase-tools
dart pub global activate flutterfire_cli

cd mobile
firebase login
flutterfire configure --project=your-firebase-project-id
# generates lib/firebase_options.dart and android/app/google-services.json
```

In the Firebase Console:
1. **Authentication → Sign-in method** → enable Google
2. **Firestore Database** → create (production mode) → paste the rules from [`docs/LLD.md`](docs/LLD.md) §3.4
3. **Project settings → Android app** → add **SHA-1 and SHA-256** fingerprints
   ```bash
   cd mobile/android && ./gradlew signingReport
   ```

### 4. Configure API base URL

Edit `mobile/lib/config.dart`:

```dart
const apiBaseUrl = 'http://10.0.2.2:8000';   // Android emulator → host
// const apiBaseUrl = 'http://<LAN-IP>:8000'; // Physical device
// const apiBaseUrl = 'https://api.scorvo.ai'; // Production
```

### 5. Run the app

```bash
cd mobile
flutter pub get
flutter run
```

---

## 📦 Production Deployment (Play Store)

Full guide → [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)

**TL;DR:**

1. Create an upload keystore:
   ```bash
   keytool -genkey -v -keystore ~/scorvoai-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `mobile/android/key.properties` (gitignored):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/absolute/path/to/scorvoai-upload.jks
   ```
3. Wire signing config in `android/app/build.gradle.kts` (see Deployment doc).
4. Update `apiBaseUrl` in `lib/config.dart` to your **HTTPS** production URL.
5. Remove `android:usesCleartextTraffic="true"` from `AndroidManifest.xml` for production.
6. Build:
   ```bash
   flutter build appbundle --release
   ```
7. Upload `build/app/outputs/bundle/release/app-release.aab` to Google Play Console.

---

## 🗂️ Repository Structure

```
ScorvoAI/
├── backend/                # FastAPI service
│   ├── main.py             # app + router includes
│   ├── routes/             # chat, solve, quiz, lessons, current_affairs, ...
│   ├── services/           # ai_service (Ollama), quiz_service, ...
│   └── models/             # SQLite (legacy)
├── mobile/                 # Flutter app
│   ├── lib/
│   │   ├── theme/          # dark + indigo design system
│   │   ├── data/           # exam_taxonomy (full hierarchy)
│   │   ├── models/         # UserProfile
│   │   ├── services/       # api, firestore, auth
│   │   └── screens/        # main_shell + 11 screens
│   └── android/            # Android scaffold
└── docs/                   # HLD, LLD, DEPLOYMENT
```

---

## 🔌 API Reference (summary)

| Method | Endpoint                  | Description |
| ------ | ------------------------- | ----------- |
| GET    | `/health`                 | Health check |
| POST   | `/chat` / `/chat/stream`  | AI tutor chat |
| POST   | `/solve`                  | Step-by-step solver |
| GET    | `/quiz` / `/quiz/stream`  | Generate quiz questions |
| POST   | `/quiz/submit`            | Submit answers |
| POST   | `/lessons` / `/lessons/stream` | AI-generated micro-lessons |
| GET    | `/current-affairs`        | Today's top news (Ollama Cloud web search) |
| GET    | `/analyze` / `/analyze/stats` | Legacy stats |
| GET    | `/daily` / POST `/daily/submit` | Legacy daily challenge |
| `/notes/*`                | Legacy SQLite notes |

Full request/response shapes → [`docs/LLD.md`](docs/LLD.md) §3.2.

---

## 🧪 Local Testing

```bash
# Static analysis
cd mobile && flutter analyze

# Debug build
flutter build apk --debug

# Hot reload on connected device
flutter run
```

---

## 🛡️ Security & Privacy

- Per-user Firestore subcollections; security rules enforce `request.auth.uid == uid`.
- No passwords stored (Google Sign-In only).
- OCR is on-device (Google ML Kit).
- Notes / quiz data / lessons-viewed are all per-user under `users/{uid}/…`.
- Shared caches (`lessons/*`, `current_affairs/*`) contain no user-identifying data.

---

## 📜 License

Proprietary — © 2026 ScorvoAI. All rights reserved.

---

## 🙏 Acknowledgements

Syllabus references: [UPSC](https://upsc.gov.in), [SSC](https://ssc.gov.in), [IBPS](https://ibps.in), [SBI Careers](https://sbi.co.in/careers), [RRB](https://rrbcdg.gov.in). LLM: [Ollama](https://ollama.com). Charts: [fl_chart](https://pub.dev/packages/fl_chart). Markdown: [gpt_markdown](https://pub.dev/packages/gpt_markdown).
