# Role B Backend Integration Contract

This app currently runs with `DemoCareRepository`. Role B should replace it
with a Firebase implementation while keeping the UI and `CareStore` unchanged.

## Swap point

File: `lib/main.dart`

```dart
final store = CareStore(DemoCareRepository())..load();
```

Replace with:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
final store = CareStore(FirebaseCareRepository(...ports...))..load();
```

Do not change presentation screens for Firebase work. Keep all backend behavior
behind `CareRepository` and the ports in
`lib/features/care/integrations/integration_ports.dart`.

## Firebase services

- Auth: email/password sign in and sign up.
- Firestore: patients, tasks, symptom logs, family member permissions.
- Storage: discharge images and symptom photos.

## Suggested Firestore structure

```text
users/{uid}
  displayName: string
  email: string
  createdAt: timestamp

patients/{patientId}
  ownerUid: string
  fullName: string
  age: number|null
  dischargeDate: timestamp
  conditionCategory: string
  mainDepartment: string
  notes: string
  emergencyContact: map
  sharedWith: array<uid>
  createdAt: timestamp
  updatedAt: timestamp

patients/{patientId}/familyMembers/{memberId}
  userUid: string|null
  displayName: string
  relationship: string
  role: "patient" | "primaryCarer" | "familyViewer"
  readOnly: boolean
  invitedEmail: string|null
  createdAt: timestamp

patients/{patientId}/tasks/{taskId}
  title: string
  details: string
  type: "medication" | "visit" | "rehab" | "note"
  status: "pending" | "completed" | "missed"
  scheduledAt: timestamp
  repeatRule: "none" | "daily" | "weekly"
  remindMinutesBefore: number
  assigneeId: string|null
  assigneeName: string
  sourceLabel: string|null
  sourceImageUrl: string|null
  completedAt: timestamp|null
  createdAt: timestamp
  updatedAt: timestamp

patients/{patientId}/symptomLogs/{yyyyMMdd}
  date: timestamp
  painLevel: number
  temperatureC: number
  notes: string
  photoUrls: array<string>
  createdAt: timestamp
  updatedAt: timestamp

patients/{patientId}/ocrImports/{scanId}
  imageUrl: string
  rawText: string
  candidates: array<map>
  createdByUid: string
  createdAt: timestamp
```

## Storage paths

```text
patients/{patientId}/discharge_scans/{scanId}.jpg
patients/{patientId}/symptom_photos/{yyyyMMdd}/{photoId}.jpg
```

Store public download URLs only if the rules are locked to authenticated users.
Otherwise store `gs://` paths and resolve URLs in the app.

## Security rule intent

Minimum demo rule behavior:

- Patient owner can read/write the patient and all subcollections.
- Family users in `sharedWith` can read patient summary, tasks, logs, and
  family members.
- Read-only family users cannot edit tasks/logs.
- Primary carers may mark tasks complete if the team chooses to allow it.
- No user can read another patient unless `ownerUid == request.auth.uid` or
  `request.auth.uid in sharedWith`.

Sketch:

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

## Required repository methods

Implement all methods in `CareRepository`:

- `load()`: load current user, patients, selected/default patient data.
- `signInDemo(...)`: can be renamed internally, but keep the app-facing method
  until UI auth is finalized.
- `signOut()`.
- `upsertPatient(...)`.
- `selectPatient(...)`: may persist selected patient id locally.
- `upsertTask(...)`.
- `deleteTask(...)`.
- `markTaskStatus(...)`.
- `upsertSymptomLog(...)`.
- `createTasksFromOcrCandidates(...)`.

## Mapping notes

- Use deterministic symptom log ids like `yyyyMMdd` to make daily upsert easy.
- Store enum values by `name`, for example `TaskStatus.pending.name`.
- Convert Firestore timestamps to local `DateTime`.
- Keep patient profile and task CRUD working offline if Firestore persistence is
  enabled.
- When role C schedules notifications, call `NotificationPort.scheduleTaskReminder`
  after task save/update.

## Acceptance checklist for role B

- Sign up creates Firebase Auth user and `users/{uid}`.
- New patient writes Firestore document and appears after app restart.
- Task create/edit/delete syncs to Firestore.
- Mark completed updates `status` and `completedAt`.
- Symptom log writes to `patients/{patientId}/symptomLogs/{yyyyMMdd}`.
- A second signed-in family user can read shared patient data but cannot edit
  when `readOnly == true`.
- Storage upload returns a path/URL that can be shown from OCR review and log
  photo tiles.
