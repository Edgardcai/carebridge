# Backend Integration (Firebase)

CareBridge keeps UI and state in `CareStore` / presentation screens unchanged.
All persistence goes through `CareRepository` and `StoragePort`.

## Current runtime behaviour

File: `lib/main.dart`

1. `LocalNotificationPort.initialize()` runs before `runApp` (3 s timeout; failures are logged, app still starts).
2. `_initializeBackend()` calls `Firebase.initializeApp` when `Firebase.apps` is empty (8 s timeout).
3. On success: `FirebaseCareRepository` + `FirebaseStoragePort` (debug: `CareBridge backend: Firebase enabled.`).
4. On failure: `DemoCareRepository` + `LocalStoragePort` (debug: `CareBridge backend: using demo backend.`).

```dart
Future<_CareBackend> _initializeBackend() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
    }
    return _CareBackend(
      repository: FirebaseCareRepository(),
      storagePort: FirebaseStoragePort(),
    );
  } catch (error, stackTrace) {
    // logged; fall through to demo backend
  }
  return _CareBackend(
    repository: DemoCareRepository(),
    storagePort: LocalStoragePort(),
  );
}
```

Implementation files:

- `lib/features/care/data/firebase_care_repository.dart`
- `lib/features/care/integrations/firebase_storage_port.dart`
- `lib/features/care/data/demo_care_repository.dart` (fallback)
- `lib/firebase_options.dart` (FlutterFire Android config; project `carebridge7506`)
- `scripts/seed_demo_account.mjs` (optional Node script to seed Firestore demo data; not used by the app at runtime)

Do not add Firebase calls from presentation code. Extend behaviour via
`CareRepository` and the **active** ports in
`lib/features/care/integrations/integration_ports.dart` (`StoragePort`,
`OcrPort`, `NotificationPort`, `DisposableIntegration`).

**Unused stubs in `integration_ports.dart`:** `AuthPort`, `PatientDataPort`,
`TaskDataPort`, `SymptomDataPort`, and `FamilyDataPort` are early team placeholders.
Auth and Firestore access are implemented inside `FirebaseCareRepository` instead;
do not wire UI to these abstract classes unless you refactor the repository.

## Firebase services

| Service | Use |
| --- | --- |
| Authentication | Email/password sign-in and sign-up (`AuthScreen` → `CareRepository.signInDemo`) |
| Firestore | Patients, tasks, symptom logs, family members, selected patient id on user doc |
| Storage | Discharge scan images (OCR source), symptom photos |

## Firestore structure (as implemented)

Fields below match `FirebaseCareRepository` read/write helpers.

```text
users/{uid}
  email: string
  displayName: string
  selectedPatientId: string|null   # set via selectPatient()
  createdAt: timestamp              # on first create
  updatedAt: timestamp

patients/{patientId}
  ownerUid: string
  fullName: string
  age: number|null
  dischargeDate: timestamp
  conditionCategory: string
  mainDepartment: string
  notes: string
  emergencyContact: map { name, relationship, phone }
  sharedWith: array<uid>            # empty array on create
  createdAt: timestamp
  updatedAt: timestamp

patients/{patientId}/familyMembers/{memberId}
  userUid: string|null
  displayName: string
  relationship: string
  role: string                        # patient | primaryCarer | familyViewer (.name)
  readOnly: boolean
  createdAt: timestamp

patients/{patientId}/tasks/{taskId}
  patientId, title, details, type, status, scheduledAt
  repeatRule, repeatDurationDays, reminderMinutesOfDay, remindMinutesBefore
  assigneeId, assigneeName, sourceLabel, sourceImageUrl
  completedAt, createdAt, updatedAt

patients/{patientId}/symptomLogs/{logId}
  patientId, date, painLevel, temperatureC, notes, photoUrls
  createdAt, updatedAt
```

**Not written by the app today**

| Item | Where it lives |
| --- | --- |
| OCR candidate list after scan | `CareStore` / `CareBundle.ocrCandidates` until user confirms or leaves the flow |
| `familyMembers.invitedEmail` | May appear in manual Console edits or `scripts/seed_demo_account.mjs`; not in `FamilyMember` model or repository serializers |
| Future `ocrImports` subcollection | Optional; not required for MVP |

**Sharing model:** `patients.sharedWith` lists uids that may read the patient tree.
`familyMembers.readOnly` is stored per member; write enforcement for viewers is
primarily in the app today (Firestore rules should mirror owner vs shared read).

## Storage paths

Implemented in `FirebaseStoragePort`:

```text
patients/{patientId}/discharge_scans/{microsecondsSinceEpoch}.jpg
patients/{patientId}/symptom_photos/{yyyyMMdd}/{microsecondsSinceEpoch}.jpg
```

Store download URLs in task `sourceImageUrl` and `SymptomLog.photoUrls` when
using Firebase Storage. Restrict access with authenticated Storage rules.

## Security rules

**This repository does not include deployed `firestore.rules` or
`storage.rules` files.** The sketch below is the intended policy for coursework
demo; apply equivalent rules in the Firebase Console before shared testing.

```js
function signedIn() {
  return request.auth != null;
}

function patientDoc(patientId) {
  return get(/databases/$(database)/documents/patients/$(patientId));
}

function canReadPatient(patientId) {
  let patient = patientDoc(patientId).data;
  return signedIn() &&
    (patient.ownerUid == request.auth.uid ||
     request.auth.uid in patient.sharedWith);
}

function canWritePatient(patientId) {
  let patient = patientDoc(patientId).data;
  return signedIn() && patient.ownerUid == request.auth.uid;
}
```

Intended behaviour:

- Owner: read/write patient document and all subcollections.
- Users in `sharedWith`: read patient, tasks, logs, family members.
- `readOnly` family members: read-only (enforced in app + rules where configured).
- No access to other owners' patients.

## Repository methods

All methods in `lib/features/care/data/care_repository.dart` are implemented for
Firebase and demo backends:

| Method | Purpose |
| --- | --- |
| `load()` | Current user, patients, tasks, logs, family; restore selected patient |
| `signInDemo(...)` | Sign in or create account (name kept for UI compatibility) |
| `signOut()` | Clear auth session |
| `upsertPatient(...)` | Create/update patient; default primary-carer family row on create |
| `selectPatient(...)` | Persist `selectedPatientId` on `users/{uid}` (Firebase) |
| `upsertTask(...)` | Create/update task |
| `deleteTask(...)` | Remove task |
| `markTaskStatus(...)` | Update status; set/clear `completedAt` when completed |
| `upsertSymptomLog(...)` | Create/update log (deterministic id on new Firebase logs) |
| `createTasksFromOcrCandidates(...)` | Create tasks from user-confirmed OCR rows |

## Mapping notes

- New symptom log document ids: `yyyyMMdd_HHmmss_microseconds` (`_logId` in repository).
- Store enums by `.name` (e.g. `TaskStatus.pending.name`).
- Persist `repeatDurationDays` and `reminderMinutesOfDay` on tasks for notification rescheduling after restart.
- Convert Firestore `Timestamp` to local `DateTime` in the repository layer.
- After task save/update, `CareStore` calls `NotificationPort.scheduleTaskReminder`; no FCM push in MVP.

## Manual verification checklist

| Check | Expected |
| --- | --- |
| Sign up | Firebase Auth user + `users/{uid}` document |
| New patient | Appears in Firestore and after app restart |
| Task CRUD | Documents under `patients/{id}/tasks` stay in sync |
| Mark completed | `status` + `completedAt` updated |
| Symptom log | Written under `symptomLogs` with photos as URLs when Storage works |
| Shared family user | Can read when `sharedWith` contains uid; read-only members cannot edit in app |
| Storage upload | OCR source and symptom images return usable URLs/paths in UI |
| Firebase unavailable | App starts with demo data and local photo paths (no crash) |
| Optional seed script | `node scripts/seed_demo_account.mjs` populates demo Firestore (see script header) |

## Local setup

See root `README.md` — Firebase Setup. Android application id:
`hk.hku.carebridge`. `android/app/google-services.json` is local-only (gitignored).
