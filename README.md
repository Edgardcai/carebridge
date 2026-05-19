# CareBridge

CareBridge is a Flutter Android MVP for **post-discharge recovery management**.
It helps patients and family carers turn discharge instructions into daily tasks,
local reminders, symptom logs, and a read-only family overview.

**Important:** CareBridge is a logging and reminder tool only. It does not
provide medical advice, diagnosis, or treatment recommendations.

## Features

- **Onboarding:** splash, legal disclaimer, email sign-in / sign-up
- **Patient profiles:** create, edit, switch patients; recovery day on dashboard
- **Tasks:** medication, visit, rehab, and note types; CRUD, repeat rules,
  assignee, mark complete; pending / completed views
- **OCR import:** scan discharge documents (camera or gallery); review and edit
  extracted lines before creating tasks (never auto-saved)
- **Symptoms:** daily pain (0–10), temperature, notes, photos; 7-day trend chart;
  recovery timeline
- **Family hub:** read-only summary of progress, responsibilities, and latest log
- **Settings:** large text, notification toggle, local notification self-test,
  sign out

## Architecture

```text
Presentation (screens.dart, app_router.dart)
        ↓
CareStore (Provider / ChangeNotifier)
        ↓
CareRepository                    Integration ports
  ├─ FirebaseCareRepository         ├─ OcrPort → MlKitOcrPort
  └─ DemoCareRepository (fallback)  ├─ NotificationPort → LocalNotificationPort
                                    └─ StoragePort → FirebaseStoragePort | LocalStoragePort
```

**Startup** (`lib/main.dart`):

1. Initialize `LocalNotificationPort` before `runApp`.
2. `_initializeBackend()` tries `Firebase.initializeApp` with
   `DefaultFirebaseOptions.currentPlatform`.
3. On success: `FirebaseCareRepository` + `FirebaseStoragePort`.
4. On failure: `DemoCareRepository` (seeded in-memory data) +
   `LocalStoragePort` (local photo paths).
5. Inject `MlKitOcrPort`, notification port, and storage port into `CareStore`,
   then `load()`.

UI code calls `CareStore` only—not Firebase or ML Kit plugins directly.

## Current status

| Area | Status |
| --- | --- |
| UI, navigation, state | Complete |
| Firebase Auth, Firestore, Storage | Implemented (`firebase_care_repository.dart`) |
| Demo fallback backend | Implemented when Firebase init fails |
| ML Kit OCR (Latin), mandatory review | Implemented |
| Local task notifications | Implemented |
| 7-day symptom chart (`fl_chart`) | Implemented |
| Symptom / discharge photos | Implemented (`image_picker` + `StoragePort`) |

**Known limitations** (see also `docs/requirements_trace.md`):

- Firestore / Storage **security rules are not committed** in this repo; apply
  equivalent rules in the Firebase Console for shared testing.
- OCR uses **Latin script only**; Chinese or handwritten discharge sheets need
  manual editing on the review screen.
- Legal disclaimer acceptance is **not persisted** across app restarts.
- Task status **missed** appears in UI/filters and demo seed data only; users
  cannot mark a task as missed in the app.
- Family **multi-account invite** is limited in UI; Firestore `sharedWith` model
  is ready on the backend side.

## Tech stack

- Flutter `3.41.x` and Dart `3.11.x` (recommended dev environment; `pubspec.yaml`
  allows Dart `>=3.4.0 <4.0.0`)
- Android package `hk.hku.carebridge`
- State: `provider`
- Backend: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`
- Native: `google_mlkit_text_recognition`, `flutter_local_notifications`,
  `timezone`, `fl_chart`, `image_picker`, `uuid`

## Run locally

```bash
git clone https://github.com/Edgardcai/carebridge.git
cd carebridge
flutter pub get
flutter run
```

- With valid Firebase config (committed `lib/firebase_options.dart` for project
  `carebridge7506`), the app uses the cloud backend.
- If initialization fails, the app **falls back to demo mode** automatically
  (check debug console for `CareBridge backend:` messages).

List devices and pick one:

```bash
flutter devices
flutter run -d <device-id>
```

Quality checks:

```bash
flutter analyze
flutter test
```

On Windows, if the debug service cannot attach through a proxy:

```powershell
$env:NO_PROXY = "localhost,127.0.0.1,::1"
```

## Firebase setup

Android application id:

```text
hk.hku.carebridge
```

To reconfigure or use your own project:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-project-id> --platforms=android
```

For this coursework repo:

```bash
flutterfire configure --project=carebridge7506 --platforms=android
```

In Firebase Console, enable:

- **Authentication** — Email/Password
- **Firestore** — database + security rules (see `docs/backend_integration.md`)
- **Storage** — for cloud photo URLs (optional; app keeps local paths on failure)

Config files:

| File | Notes |
| --- | --- |
| `lib/firebase_options.dart` | FlutterFire Android options (committed) |
| `android/app/google-services.json` | Local only; **gitignored** |
| `firebase.json` | FlutterFire project mapping (committed) |

## Build APK

Debug:

```bash
flutter build apk --debug
# build/app/outputs/flutter-apk/app-debug.apk
```

Release (coursework/demo signing, not Play Store ready):

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

Install on a connected device:

```bash
flutter install -d <device-id>
```

## Project structure

```text
lib/
  main.dart                          # Backend bootstrap, CareStore wiring
  app.dart                           # MaterialApp, theme, routes
  firebase_options.dart
  core/routing/app_router.dart
  core/theme/app_theme.dart
  features/care/
    application/care_store.dart
    data/care_repository.dart
    data/demo_care_repository.dart
    data/firebase_care_repository.dart
    domain/models.dart
    integrations/
      integration_ports.dart
      firebase_storage_port.dart
      local_storage_port.dart
      mlkit_ocr_port.dart
      local_notification_port.dart
    presentation/screens.dart

docs/
  requirements_trace.md              # Requirement ↔ implementation matrix
  backend_integration.md             # Firestore, Storage, fallback behaviour
  native_integration.md              # OCR, notifications, chart, device testing

scripts/
  seed_demo_account.mjs              # Optional Firebase demo data seed (Node)

android/                             # Manifest, permissions, notification receivers
test/widget_test.dart                # Splash smoke test
```

### Moodle submission (not in Git)

Create a local `Submission/` folder at the repo root for coursework upload to
Moodle. **Do not commit this folder** — it is listed in `.gitignore`.

| File | Purpose |
| --- | --- |
| `DocumentFile.pdf` | Final project report |
| `IntroductoryVideo.mp4` | App introduction video |
| `Peer_Review.docs` | Peer review form |

Keep these files on your machine only; submit them through Moodle, not via this
repository.

## Main `CareStore` actions

- `signInDemo`, `signOut`
- `savePatient`, `selectPatient`
- `saveTask`, `deleteTask`, `markTaskStatus`
- `saveSymptomLog`
- `scanOcrCandidatesFromImage`, `createTasksFromOcr`
- `setLargeText`, `setNotificationsEnabled`

Repository contract: `lib/features/care/data/care_repository.dart` (implemented
for both Firebase and demo backends).

## Android notes

Permissions in `android/app/src/main/AndroidManifest.xml`:

- `CAMERA`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `READ_MEDIA_IMAGES`,
  `RECEIVE_BOOT_COMPLETED`

Scheduled notifications also require Flutter Local Notifications receivers
(already registered). If timed reminders fail but instant test notifications
work, see the **Troubleshooting** section in `docs/native_integration.md`.

## Team development

```bash
git clone https://github.com/Edgardcai/carebridge.git
cd carebridge
git switch main
flutter pub get
flutter analyze
flutter test
```

Use feature branches, run `flutter analyze` / `flutter test` before push, and
open PRs to `main`.

Do not commit:

```text
Submission/
android/app/google-services.json
build/
.dart_tool/
.idea/
*.iml
```

If the Android folder is missing after clone:

```bash
flutter create --platforms=android .
```

Keep existing `lib/`, `pubspec.yaml`, `README.md`, and `docs/` when prompted.

## Documentation

| Document | Purpose |
| --- | --- |
| `docs/requirements_trace.md` | MVP requirements mapped to code |
| `docs/backend_integration.md` | Firebase schema, bootstrap, verification |
| `docs/native_integration.md` | OCR, notifications, chart, photos, device testing |

Moodle deliverables (`DocumentFile.pdf`, `IntroductoryVideo.mp4`,
`Peer_Review.docs`) live in a local `Submission/` folder — see
[Moodle submission](#moodle-submission-not-in-git) above.

## App flow (quick reference)

```text
Splash → Legal disclaimer → Auth → Patient (if none) → Home
Bottom nav: Home | Tasks | Log | Family
Home → Scan doc → OCR review → Create tasks
Log → symptom entry, 7-day chart → Timeline
Settings (Home or Log): notifications, large text, sign out
```

For requirement-level notes (e.g. missed tasks, legal persistence), see
`docs/requirements_trace.md`.
