# Role C Native/OCR/Chart Integration Contract

Role C should keep UI calls stable and implement native features behind ports in
`lib/features/care/integrations/integration_ports.dart`.

## 1. ML Kit OCR

Implement `OcrPort.extractTaskCandidates`.

Input:

```dart
Future<List<OcrCandidate>> extractTaskCandidates({
  required String patientId,
  required String localImagePath,
});
```

Output rules:

- Return candidate rows only. Do not auto-create tasks.
- Each candidate must be editable and user-confirmed on `OcrReviewScreen`.
- Use `confidence` from 0.0 to 1.0 when possible. If ML Kit does not provide
  reliable confidence, use parser confidence.
- Parse only safe operational data: medication title, appointment date/time,
  rehab instruction, or general note.
- Do not generate medical advice.

Suggested cleaning pipeline:

```text
image -> ML Kit text blocks -> normalize whitespace -> split lines
-> classify lines by keyword/time/date -> build candidates
-> user review -> CareStore.createTasksFromOcr
```

Useful parsing hints:

- Medication: line contains `mg`, `tablet`, `daily`, `after meal`, `bid`, `tid`.
- Appointment: line contains date/time, `follow-up`, `clinic`, `doctor`, dept.
- Rehab: line contains `walk`, `exercise`, `physio`, `stretch`, `range of motion`.
- Note: dietary restrictions, wound care, observation reminders.

## 2. Local notifications

Implement `NotificationPort`.

Required behavior:

- Request Android 13+ `POST_NOTIFICATIONS` permission.
- Schedule reminders for pending tasks only.
- Cancel notification when task is deleted or completed.
- Reschedule after task edit, repeat rule change, or patient switch.
- Keep notifications local. Do not depend on server push for MVP.

Task fields already available:

```dart
task.id
task.title
task.details
task.scheduledAt
task.repeatRule
task.remindMinutesBefore
task.patientId
```

Suggested notification id:

```dart
task.id.hashCode & 0x7fffffff
```

Android manifest already reserves:

- `CAMERA`
- `POST_NOTIFICATIONS`
- `SCHEDULE_EXACT_ALARM`
- `READ_MEDIA_IMAGES`

Scheduled local notifications require receivers in
`android/app/src/main/AndroidManifest.xml` (already added in this repo):

- `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`
- `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver`
  (with `BOOT_COMPLETED` / `MY_PACKAGE_REPLACED` intent filters)
- `com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver`
- Permission `RECEIVE_BOOT_COMPLETED`

See `docs/role_c_integration.md` for Role A/B handoff and test steps.

## 3. fl_chart trend chart

`MiniTrendChart` uses `fl_chart` (`LineChart`) for the last seven days of pain
levels. Keep this public constructor stable for any future styling tweaks:

```dart
class MiniTrendChart extends StatelessWidget {
  const MiniTrendChart({required this.logs, super.key});
  final List<SymptomLog> logs;
}
```

Expected chart:

- Last 7 days, oldest to newest.
- Pain line: 0 to 10 y-axis (left).
- Temperature shown as a second line mapped to the same vertical space with a
  right-axis style label (see implementation in `MiniTrendChart`).
- Empty state remains visible when `logs.isEmpty`.

## 4. Photo picking and upload

UI currently shows photo placeholders on `SymptomLogScreen`. Integration path:

1. Use `image_picker` to choose/take photo.
2. Upload with role B `StoragePort.uploadSymptomPhoto`.
3. Save returned URL/path in `SymptomLog.photoUrls`.
4. Show thumbnail, retry, and remove actions.

## Acceptance checklist for role C

- OCR runs on-device and returns candidates from a real image.
- OCR review screen still requires explicit user confirmation.
- Local notification permission flow works on Android.
- A task saved for the next minute triggers a local notification.
- Completed/deleted task notifications are cancelled.
- 7-day symptom chart renders with `fl_chart` and does not overlap labels.
- Symptom photo add/upload failure is visible and retryable.
