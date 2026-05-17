# ScorvoAI — Production Deployment Guide

End-to-end checklist for shipping ScorvoAI to the **Google Play Store** with a production backend.

---

## 🚀 Live reference deployment

A working production deploy you can use as a reference (and to verify your local app):

| Resource | URL |
| -------- | --- |
| **Backend** | https://scorvoai-production.up.railway.app |
| **Smoke test** | `curl https://scorvoai-production.up.railway.app/health` → `{"status":"ok"}` |
| **Diagnostics** | `curl https://scorvoai-production.up.railway.app/ready \| jq .` |
| **Android APK** (89 MB, signed debug-release) | https://github.com/abhi9716/ScorvoAI/raw/main/releases/scorvoai-v1.0.0.apk |
| **Run full suite** | `./backend/test_endpoints.sh https://scorvoai-production.up.railway.app` |

This deploy uses **Ollama Cloud directly** (no local Ollama, no separate Ollama service) — see [§2.3](#23-ollama-hosting) for why this is simplest and how it works.

---

## 1. Pre-flight checklist

| Item | Status |
| ---- | ------ |
| Firebase project on the **Blaze** plan (Spark works for low volume but reads/writes are capped) | ☐ |
| Ollama Cloud API key issued at https://ollama.com/settings/keys | ☐ |
| Backend hosted with HTTPS (Cloud Run / Railway / Fly.io / a VPS with nginx + Let's Encrypt) | ☐ |
| Domain configured (e.g. `api.scorvo.ai`) — optional, Railway gives a free `*.up.railway.app` | ☐ |
| Play Console developer account created (USD 25 one-time fee) | ☐ |
| App icon (`1024 × 1024` PNG, no alpha) | ☐ |
| Feature graphic (`1024 × 500`) | ☐ |
| Screenshots: phone (≥ 2, max 8) at 1080 × 1920 or higher | ☐ |
| Privacy policy URL hosted on a public website | ☐ |

---

## 2. Backend — production

### 2.1 Recommended host: Cloud Run / Railway

Example **Dockerfile** for the backend:

```Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
```

Build & deploy (Cloud Run):

```bash
gcloud builds submit --tag gcr.io/<project>/scorvoai-api
gcloud run deploy scorvoai-api \
  --image gcr.io/<project>/scorvoai-api \
  --platform managed --region asia-south1 \
  --set-env-vars "OLLAMA_API_KEY=oa_xxx,CORS_ORIGINS=https://app.scorvo.ai" \
  --allow-unauthenticated
```

### 2.2 Required env vars

```
OLLAMA_API_KEY=oa_xxx           # Required for real current affairs
CORS_ORIGINS=https://...        # Tighten from "*"
OLLAMA_BASE=http://...:11434    # Where to reach Ollama (see 2.2.1)
```

### 2.2.1 ⚠️ Critical: backend in Docker → Ollama on host

When the backend runs in a Docker container but Ollama runs on the host
machine, `http://localhost:11434` inside the container points to the
container itself (not the host) and every Ollama call fails with
`httpx.ConnectError: All connection attempts failed`.

Three ways to fix:

```bash
# Option A (Linux only — simplest): share the host network
docker run --network=host -e OLLAMA_API_KEY scorvoai-api

# Option B (cross-platform): bridge to host
docker run -p 8000:8000 \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_BASE=http://host.docker.internal:11434 \
  -e OLLAMA_API_KEY \
  scorvoai-api

# Option C: point at a remote Ollama server's LAN IP
docker run -p 8000:8000 \
  -e OLLAMA_BASE=http://192.168.1.42:11434 \
  -e OLLAMA_API_KEY \
  scorvoai-api
```

On Cloud Run / Railway / Render, the same applies — Ollama must live at a
URL the container can reach over the network. Most production deploys host
Ollama on a separate GPU VPS and set `OLLAMA_BASE` to its public IP/domain.

### 2.3 Ollama hosting

`gemma4:31b-cloud` is a cloud-served model — compute runs on Ollama's
infrastructure, not yours. ScorvoAI's backend calls `https://ollama.com/api/chat`
directly with `Authorization: Bearer <OLLAMA_API_KEY>` (see
`backend/services/ai_service.py:_ollama_headers`). **No local Ollama is
needed in production.**

Set these two env vars on your host (Railway/Cloud Run/Render/etc.):

```
OLLAMA_BASE=https://ollama.com
OLLAMA_API_KEY=oa_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

That's it — no GPU VPS, no `ollama pull`, no Docker network gymnastics.
Verified working: https://scorvoai-production.up.railway.app/ready
(returns `ready: true` with this setup).

> **When you would need a local Ollama:** only if you want to swap
> `gemma4:31b-cloud` for a self-hosted Gemma variant (e.g. `gemma4:e4b`
> on an edge device). In that case, host Ollama on a GPU VPS and point
> `OLLAMA_BASE` at it.

### 2.4 Railway deployment — step by step

ScorvoAI ships with `backend/railway.json` so Railway knows how to build
and run the backend.

**Step 1.** Spin up Railway CLI:
```bash
npm install -g @railway/cli
railway login
```

**Step 2.** From the repo root, create the project:
```bash
cd backend
railway init                          # creates the project
```

**Step 3.** Set required env vars (point straight at Ollama Cloud — no
second service needed):
```bash
railway variables --set OLLAMA_API_KEY=oa_xxxxxxxx \
                  --set OLLAMA_BASE=https://ollama.com \
                  --set CORS_ORIGINS=*
```

**Step 4.** _(skipped — no separate Ollama service is required;
the backend calls `https://ollama.com/api/chat` directly with the
Bearer token from `OLLAMA_API_KEY`)_

**Step 5.** Deploy the backend:
```bash
railway up                            # pushes + builds + runs
railway domain                        # mints a public HTTPS URL
```

**Step 6.** Verify it's healthy:
```bash
curl https://<your-domain>/health     # should return {"status":"ok"}
curl https://<your-domain>/ready      # should return {"ready":true, ...}
```

If `/ready` returns `ready: false`, the JSON `checks` field tells you
exactly what's wrong (Ollama unreachable / model not pulled / API key
missing).

**Step 7.** Update mobile `lib/config.dart`:
```dart
const apiBaseUrl = 'https://<your-railway-domain>';
```
Rebuild the APK and you're live.

### 2.5 Pre-flight check (always run before deploy)

```bash
cd backend
python preflight.py
```

This runs 5 checks in order and tells you exactly what to fix:
1. Required env vars are set
2. Ollama server is reachable
3. Gemma 4 model is pulled
4. Ollama Cloud web-search API key is valid
5. End-to-end inference returns a real response

Exits non-zero if any check fails — perfect for CI gates.

### 2.4 Firewall

Open only:
- TCP **443** (your backend HTTPS)
- Outbound to Firestore + ollama.com

---

## 3. Mobile — release build

### 3.1 Create upload keystore

```bash
keytool -genkey -v -keystore ~/scorvoai-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Store the **passwords + keystore file** somewhere safe and *backed up*. **Losing this means you can't update the app.**

### 3.2 Wire signing config

Create `mobile/android/key.properties` (add to `.gitignore`):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/scorvoai-upload.jks
```

Update `mobile/android/app/build.gradle.kts` — add **above** the `android {}` block:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Inside `android {}`, add:

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
        storePassword = keystoreProperties["storePassword"] as String?
    }
}
```

Replace the existing `release` build type with:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
}
```

### 3.3 Production AndroidManifest

In `mobile/android/app/src/main/AndroidManifest.xml`:

1. **Remove** `android:usesCleartextTraffic="true"` — production must be HTTPS.
2. **Change** `android:label="scorvoai"` → `android:label="ScorvoAI"`.
3. **Remove** `WRITE_EXTERNAL_STORAGE` and `READ_EXTERNAL_STORAGE` — Flutter's `image_picker` uses scoped storage on Android 13+; keep `CAMERA` only.
4. **Add** an `android:exported` value to `MainActivity` (already present in latest scaffold).

Optional — if you must call non-HTTPS endpoints, create `android/app/src/main/res/xml/network_security_config.xml` and reference it via `android:networkSecurityConfig`.

### 3.4 Update version

`mobile/pubspec.yaml`:

```yaml
version: 1.0.0+1   # versionName+versionCode — bump for every release
```

### 3.5 Update API URL

`mobile/lib/config.dart`:

```dart
const apiBaseUrl = 'https://api.scorvo.ai';   // production
```

### 3.6 Update launcher icon

```bash
# add to dev_dependencies in pubspec.yaml:
#   flutter_launcher_icons: ^0.13.1
# add at root of pubspec.yaml:
#   flutter_launcher_icons:
#     android: true
#     image_path: "assets/icon.png"
dart run flutter_launcher_icons
```

### 3.7 Build the App Bundle

```bash
cd mobile
flutter clean
flutter pub get
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

Verify the AAB:

```bash
bundletool build-apks --bundle=app-release.aab --output=test.apks
bundletool install-apks --apks=test.apks
```

---

## 4. Play Store listing

### 4.1 Required assets

| Asset            | Spec                                        |
| ---------------- | ------------------------------------------- |
| App icon         | 512 × 512 PNG, no transparency, no rounding |
| Feature graphic  | 1024 × 500 PNG/JPG                          |
| Phone screenshots| 2–8 images, 1080 × 1920 (min)               |
| Short description| ≤ 80 chars                                  |
| Full description | ≤ 4000 chars                                |
| Privacy policy   | Public URL                                  |

### 4.2 Suggested copy

**Short description (80 chars):**
> AI-powered exam prep for UPSC, SSC, Banking, Railway with adaptive quizzes.

**Full description outline:**
- Hook (1-2 lines)
- "What you get" bullet list
- How it adapts to you (Smart Practice, RAG-powered AI tutor)
- Coverage (12 exams, full syllabi)
- Privacy
- Contact / support email

### 4.3 Content rating

Use Play Console's IARC questionnaire. ScorvoAI is **Everyone (E)** — no violence, no gambling.

### 4.4 Data safety

Declare in Play Console:
- **Collected:** Name, email, photo (Google account); App activity (quiz scores, notes content).
- **Shared:** None with third parties.
- **Purpose:** Account management + app functionality.
- **Encrypted in transit:** Yes.
- **User can request deletion:** Yes (via in-app Sign out + email support).

### 4.5 Release tracks

Recommended rollout:

1. **Internal testing** (your team) → smoke test
2. **Closed testing** (100 trusted users) → 1-2 weeks
3. **Open testing** (public beta) → 1-2 weeks
4. **Production** → 10 % → 25 % → 50 % → 100 % staged rollout

---

## 5. Firestore — production rules

Paste into Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    match /lessons/{key} {
      allow read, write: if request.auth != null;
    }
    match /current_affairs/{date} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Recommended indexes** (Firestore creates them on first query, or add manually):
- `users/{uid}/quiz_results` — composite (`timestamp` desc)
- `users/{uid}/ai_notes` — composite (`created_at` desc)
- `users/{uid}/viewed_lessons` — composite (`last_viewed` desc)

---

## 6. Post-launch monitoring

| Tool                | What for |
| ------------------- | -------- |
| **Firebase Crashlytics** | Mobile crashes (enable in `pubspec.yaml` + `main.dart`) |
| **Cloud Run logs**       | Backend errors |
| **Firebase Auth dashboard** | Sign-up funnel |
| **Firestore usage dashboard** | Read/write costs |
| **Play Console vitals** | ANRs, crash rate |

---

## 7. Update workflow

```bash
# 1. Bump version in pubspec.yaml (1.0.0+1 → 1.0.1+2)
# 2. Build
flutter build appbundle --release
# 3. Upload AAB in Play Console → Production → Create new release
# 4. Staged rollout starting at 10%
```

Backend deploys via your CI/CD (Cloud Build / GitHub Actions / Railway auto-deploy on push).

---

## 8. Rollback

- **Mobile:** Play Console → "Halt rollout" if crash rate spikes; revert to previous release.
- **Backend:** Cloud Run keeps revisions — `gcloud run services update-traffic scorvoai-api --to-revisions=<prev>=100`.
- **Firestore rules:** Version-controlled in console.

---

## 9. Known gotchas

| Issue | Fix |
| ----- | --- |
| Google Sign-In returns null on release build | Add **SHA-256** (not just SHA-1) of your **upload** key to Firebase project |
| `MissingPluginException` after build | `flutter clean && flutter pub get && flutter build appbundle --release` |
| Black screen on launch | Check `firebase_options.dart` is committed and the project ID matches |
| Slow first chat reply | Pre-warm Ollama with a dummy request on backend startup |
| Current affairs failing | Check `OLLAMA_API_KEY` is set in backend env |
