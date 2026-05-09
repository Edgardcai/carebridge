# CareBridge

CareBridge is a Flutter Android MVP for post-discharge recovery management.
It focuses on recovery reminders, symptom logging, family coordination, and
handoff points for Firebase, OCR, local notifications, photo upload, and
trend charts.

This repository currently contains role A's front-end/business framework.
Role B and role C can work against the interfaces documented below without
rewriting the current UI.

## Current Status

Completed in this version:

- Flutter Android project scaffold with package id `hk.hku.carebridge`.
- Provider-based state management through `CareStore`.
- Repository abstraction through `CareRepository`.
- Demo in-memory backend through `DemoCareRepository`, so the app can run
  before Firebase is ready.
- App routes and navigation flow:
  splash, legal disclaimer, auth, patient create/list, home dashboard, task
  list/detail/create-edit, OCR review, symptom log, timeline, family hub, and
  settings.
- Demo data for patients, family members, care tasks, OCR candidates, and
  symptom logs.
- Integration contracts for Firebase, ML Kit OCR, local notifications,
  photo storage, and `fl_chart`.
- Supporting docs for final report, requirement trace, and demo video script.

Not completed yet:

- Real Firebase Auth/Firestore/Storage implementation.
- Real ML Kit OCR image parsing.
- Real Android local notification scheduling.
- Real image picker/photo upload flow.
- `fl_chart` replacement for the temporary symptom sparkline.

## Tech Stack

- Flutter `3.41.9`
- Dart `3.11.5`
- Android target via Flutter's generated Android wrapper
- State management: `provider`
- Current data source: local demo repository

Role B/C should add plugin dependencies only when implementing their parts:

```yaml
# Role B
firebase_core
firebase_auth
cloud_firestore
firebase_storage

# Role C
google_mlkit_text_recognition
flutter_local_notifications
fl_chart
image_picker
uuid
```

## Run Locally

From a fresh clone:

```bash
git clone https://github.com/Edgardcai/carebridge.git
cd carebridge
flutter pub get
flutter run
```

On Zijian's local machine:

```bash
source ~/.zshenv
cd /Users/zijiancai/Desktop/hkucsfiles/comp7506/group_project/main_work
flutter pub get
flutter devices
flutter run
```

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

Role B should implement Firebase behind `CareRepository` and keep the UI
unchanged.

Current swap point:

```dart
// lib/main.dart
final store = CareStore(DemoCareRepository())..load();
```

Expected replacement:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final repository = FirebaseCareRepository(
    authPort: FirebaseAuthPort(),
    patientDataPort: FirestorePatientDataPort(),
    taskDataPort: FirestoreTaskDataPort(),
    symptomDataPort: FirestoreSymptomDataPort(),
    familyDataPort: FirestoreFamilyDataPort(),
    storagePort: FirebaseStoragePort(),
  );

  final store = CareStore(repository)..load();

  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const CareBridgeApp(),
    ),
  );
}
```

Minimum repository methods to implement:

```dart
abstract class CareRepository {
  Future<CareBundle> load();
  Future<AppUser> signInDemo({required String email, required String displayName});
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

Suggested implementation path:

1. Add Firebase packages to `pubspec.yaml`.
2. Configure Android Firebase app and decide whether Firebase config files
   should be committed. They are currently ignored by `.gitignore`.
3. Create `lib/features/care/data/firebase_care_repository.dart`.
4. Implement Auth, patient CRUD, task CRUD, symptom log CRUD, family sharing,
   and storage upload behind `CareRepository`.
5. Replace `DemoCareRepository` in `lib/main.dart`.
6. Run `flutter analyze`, `flutter test`, and one Android emulator smoke test.

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
  replace internals of `MiniTrendChart` in
  `lib/features/care/presentation/screens.dart` with `fl_chart`; keep the
  constructor `MiniTrendChart({required List<SymptomLog> logs})`.
- Photos:
  use `image_picker`, upload with `StoragePort.uploadSymptomPhoto`, save the
  returned URL/path in `SymptomLog.photoUrls`.

Detailed OCR, notification, chart, and photo requirements are in:

```text
docs/native_integration.md
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

## GitHub Upload

First-time upload:

```bash
git init
git add .
git commit -m "Initial CareBridge Flutter MVP"
git remote add origin https://github.com/Edgardcai/carebridge.git
git branch -M main
git push -u origin main
```

After later changes:

```bash
git add .
git commit -m "Describe the change"
git push
```
