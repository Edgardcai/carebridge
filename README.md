# CareBridge

CareBridge is a Flutter Android MVP for post-discharge recovery management.
It focuses on recovery reminders, symptom logging, family coordination, and
handoff points for Firebase, OCR, local notifications, photo upload, and
trend charts.

The app includes role A's presentation and state layer, role B's Firebase
repository/storage integration, and role C's ML Kit OCR, local notifications,
and symptom chart.

## Current Status

Completed in this version:

- Flutter Android project scaffold with package id `hk.hku.carebridge`.
- Provider-based state management through `CareStore`.
- Repository abstraction through `CareRepository`.
- Demo in-memory backend through `DemoCareRepository`, so the app can run
  when Firebase project config is not provided.
- **Role B (Firebase):** `FirebaseCareRepository` for Auth, Firestore patient /
  task / symptom / family data, selected-patient persistence, and OCR-to-task
  creation. `FirebaseStoragePort` uploads discharge scans and symptom photos.
- App routes and navigation flow:
  splash, legal disclaimer, auth, patient create/list, home dashboard, task
  list/detail/create-edit, OCR review, symptom log, timeline, family hub, and
  settings.
- Demo data for patients, family members, care tasks, OCR candidates, and
  symptom logs.
- Integration contracts for Firebase, ML Kit OCR, local notifications,
  photo storage, and `fl_chart`.
- Supporting docs for final report, requirement trace, and demo video script.
- **Role C (native / algorithm):** ML Kit text recognition in `MlKitOcrPort`
  (line normalization, keyword classification, simple time parsing) wired on
  `OcrReviewScreen` with camera and gallery via `image_picker`.
- Android local notifications via `LocalNotificationPort` (`flutter_local_notifications`,
  `timezone`, exact idle scheduling) integrated in `CareStore` (permission on load,
  schedule / cancel / reschedule with task and patient changes).
- Symptom **past 7 days** pain trend chart using `fl_chart` in `MiniTrendChart`.
- `LocalStoragePort` keeps picked photos local when Firebase config is absent;
  Firebase mode stores download URLs through `FirebaseStoragePort`.

Not completed yet:

- Production Firebase project files / deployed security rules. The committed
  `lib/firebase_options.dart` is a safe dart-define based template.

## Tech Stack

- Flutter `3.41.9`
- Dart `3.11.5`
- Android target via Flutter's generated Android wrapper
- State management: `provider`
- Current data source: Firebase-first repository with demo fallback

Firebase dependencies are listed in `pubspec.yaml` (`firebase_core`,
`firebase_auth`, `cloud_firestore`, `firebase_storage`). Role C dependencies
are also listed (`google_mlkit_text_recognition`, `flutter_local_notifications`,
`fl_chart`, `image_picker`, `uuid`, `timezone`).

## Run Locally

From a fresh clone:

```bash
git clone https://github.com/Edgardcai/carebridge.git
cd carebridge
flutter pub get
flutter run
```

The app can run in demo fallback mode without Firebase config. To use the real
shared backend, set up Firebase with the steps in
[Firebase Setup](#firebase-setup).

Recommended emulator:

```bash
flutter emulators --launch CareBridge_API36
flutter run -d emulator-5556
```

The emulator id can change between launches. If `emulator-5556` is not found,
run:

```bash
flutter devices
```

Then choose the active Android device id shown by Flutter.

If Flutter cannot connect to the debug service, make sure localhost bypasses
the proxy:

```bash
export NO_PROXY="localhost,127.0.0.1,::1"
export no_proxy="$NO_PROXY"
```

## Try on an Android Phone

Install requirements:

- Flutter SDK
- Android Studio
- A real Android phone with Developer options and USB debugging enabled

Run directly on a connected phone:

```bash
cd carebridge
flutter pub get
flutter devices
flutter run -d <device-id>
```

Example:

```bash
flutter run -d 10AE671KEH0047E
```

Build and install a debug APK:

```bash
flutter build apk --debug
flutter install -d <device-id>
```

The debug APK is generated at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

For a simple tester handoff, build a release APK and upload it to GitHub
Releases or send it through a trusted channel:

```bash
flutter build apk --release
```

The release APK is generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

This MVP currently uses the debug signing config for release builds, so the APK
is suitable for coursework/demo testing, not Play Store publication.

## Firebase Setup

The project can run without Firebase, but cloud sync requires a Firebase
project. The Android application id is:

```text
hk.hku.carebridge
```

Recommended setup:

```bash
cd carebridge
npm install -g firebase-tools
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"
firebase login
flutterfire configure --project=<firebase-project-id> --platforms=android
```

For the current project:

```bash
flutterfire configure --project=carebridge7506 --platforms=android
```

Enable these Firebase products in the Firebase Console:

- Authentication: enable Email/Password sign-in.
- Firestore Database: create a database and publish rules.
- Firebase Storage: optional for cloud photo upload; the app falls back to
  local photo paths if Storage is unavailable.

Firebase config notes:

- `lib/firebase_options.dart` is generated by FlutterFire and is safe to keep
  with this coursework project.
- `android/app/google-services.json` is ignored by Git and should stay local.
- `firebase.json` records FlutterFire project mapping and can be committed.

## Team Development

For teammates joining the app development:

```bash
git clone https://github.com/Edgardcai/carebridge.git
cd carebridge
git switch main
flutter pub get
flutter analyze
flutter test
```

Use a personal branch for each task:

```bash
git switch -c <name>/<feature>
```

Before starting work, update from `main`:

```bash
git fetch origin
git rebase origin/main
```

After finishing:

```bash
flutter analyze
flutter test
git status
git add .
git commit -m "Describe the change"
git push -u origin <name>/<feature>
```

Then open a pull request into `main`, or coordinate with the team lead before
pushing directly to `main`.

Do not commit local secrets, device files, or build outputs. In particular,
keep these out of Git:

```text
android/app/google-services.json
build/
.dart_tool/
.idea/
*.iml
```

## Useful Commands

```bash
flutter analyze
flutter test
flutter build apk --debug
```

If Android files are missing after clone:

```bash
flutter create --platforms=android .
```

When Flutter asks whether to overwrite files, keep the existing `lib/`,
`pubspec.yaml`, `README.md`, and `docs/` files.

## Project Structure

```text
lib/
  main.dart
  app.dart
  core/
    routing/app_router.dart
    theme/app_theme.dart
  features/care/
    application/care_store.dart
    data/care_repository.dart
    data/demo_care_repository.dart
    domain/models.dart
    integrations/integration_ports.dart
    presentation/screens.dart

docs/
  backend_integration.md
  native_integration.md
  requirements_trace.md
  final_report_outline.md
  demo_video_script.md

android/
  Flutter Android wrapper and app manifest.
```

Key files:

- `lib/main.dart`: creates `CareStore` and injects the current repository.
- `lib/features/care/application/care_store.dart`: app state and UI actions.
- `lib/features/care/data/care_repository.dart`: role B's main data contract.
- `lib/features/care/data/demo_care_repository.dart`: temporary local data.
- `lib/features/care/domain/models.dart`: shared models and enums.
- `lib/features/care/integrations/integration_ports.dart`: Firebase/native
  feature ports for role B and role C.
- `lib/features/care/presentation/screens.dart`: all MVP UI screens.
- `lib/core/routing/app_router.dart`: route names and navigation mapping.

## Role A Handoff

Role A has already connected the static UI to a state/repository layer. Most
screens call `CareStore` instead of holding isolated dummy state. The app can
therefore keep the current presentation layer while role B replaces storage
and role C replaces native integrations.

Main UI actions already available:

- `CareStore.signInDemo`
- `CareStore.savePatient`
- `CareStore.selectPatient`
- `CareStore.saveTask`
- `CareStore.deleteTask`
- `CareStore.markTaskStatus`
- `CareStore.saveSymptomLog`
- `CareStore.createTasksFromOcr`

## Role B: Firebase Integration

Role B implements Firebase behind `CareRepository` and keeps the UI mostly
unchanged.

Current startup path:

```dart
// lib/main.dart
final backend = await _initializeBackend();
final store = CareStore(backend.repository, storagePort: backend.storagePort)..load();
```

Firebase is enabled when `DefaultFirebaseOptions.currentPlatform` contains real
project values. The recommended setup is `flutterfire configure`; the committed
template also supports dart-defines:

```bash
flutter run \
  --dart-define=FIREBASE_PROJECT_ID=your-project-id \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=1234567890 \
  --dart-define=FIREBASE_ANDROID_API_KEY=your-android-api-key \
  --dart-define=FIREBASE_ANDROID_APP_ID=1:1234567890:android:abcdef \
  --dart-define=FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com
```

Minimum repository methods to implement:

```dart
abstract class CareRepository {
  Future<CareBundle> load();
  Future<AppUser> signInDemo({
    required String email,
    required String displayName,
    String? password,
    bool createAccount = false,
  });
  Future<void> signOut();
  Future<PatientProfile> upsertPatient(PatientProfile patient);
  Future<void> selectPatient(String patientId);
  Future<CareTask> upsertTask(CareTask task);
  Future<void> deleteTask(String taskId);
  Future<CareTask> markTaskStatus(String taskId, TaskStatus status);
  Future<SymptomLog> upsertSymptomLog(SymptomLog log);
  Future<List<CareTask>> createTasksFromOcrCandidates(
    List<OcrCandidate> candidates,
  );
}
```

Implemented Role B path:

1. Firebase packages are in `pubspec.yaml`.
2. Android Firebase initialization uses `DefaultFirebaseOptions`.
3. Firebase implementation lives in
   `lib/features/care/data/firebase_care_repository.dart`.
4. Storage upload lives in
   `lib/features/care/integrations/firebase_storage_port.dart`.
5. `lib/main.dart` chooses Firebase when configured and demo fallback otherwise.
6. Run `flutter analyze`, `flutter test`, and one Android smoke test after
   adding real Firebase project values.

Detailed Firestore schema, storage paths, and security rule intent are in:

```text
docs/backend_integration.md
```

## Role C: OCR, Notifications, Chart, Photos

Role C should implement native and algorithm features behind these ports:

```dart
abstract class OcrPort {
  Future<List<OcrCandidate>> extractTaskCandidates({
    required String patientId,
    required String localImagePath,
  });
}

abstract class NotificationPort {
  Future<void> requestPermission();
  Future<void> scheduleTaskReminder(CareTask task);
  Future<void> cancelTaskReminder(String taskId);
  Future<void> rescheduleAll(List<CareTask> tasks);
}

abstract class StoragePort {
  Future<String> uploadDischargeImage({
    required String patientId,
    required String localPath,
  });

  Future<String> uploadSymptomPhoto({
    required String patientId,
    required DateTime logDate,
    required String localPath,
  });
}
```

Expected integration points:

- ML Kit OCR:
  call `OcrPort.extractTaskCandidates`, show the result on `OcrReviewScreen`,
  then call `CareStore.createTasksFromOcr` only after user confirmation.
- Local notifications:
  schedule after `CareStore.saveTask`, cancel after task completion/delete,
  and reschedule when task time/repeat rule changes.
- Chart:
  `MiniTrendChart` in `lib/features/care/presentation/screens.dart` uses
  `fl_chart`; keep the constructor `MiniTrendChart({required List<SymptomLog> logs})`.
- Photos:
  use `image_picker`, upload with `StoragePort.uploadSymptomPhoto`, save the
  returned URL/path in `SymptomLog.photoUrls`.

Detailed OCR, notification, chart, and photo requirements are in:

```text
docs/native_integration.md
```

Role C handoff for teammates (Chinese, ports, manifest, test steps):

```text
docs/role_c_integration.md
```

## Android Notes

The manifest already declares permissions expected by role C:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

If `flutter_local_notifications`, ML Kit, or Firebase requires extra Android
manifest metadata, receivers, services, or Gradle plugins, add them under
`android/app`.

## Documentation for Submission

- Final report draft outline: `docs/final_report_outline.md`
- Demo video script: `docs/demo_video_script.md`
- Requirement trace: `docs/requirements_trace.md`
