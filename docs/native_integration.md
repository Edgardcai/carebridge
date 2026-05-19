# Native Integration (OCR, Notifications, Chart, Photos)

On-device and platform features are implemented behind ports in
`lib/features/care/integrations/integration_ports.dart`. UI calls `CareStore`
only, not plugins directly.

| Port / lifecycle | Implementation | Injected in |
| --- | --- | --- |
| `OcrPort` | `MlKitOcrPort` | `lib/main.dart` → `CareStore` |
| `NotificationPort` | `LocalNotificationPort` | `lib/main.dart` → `CareStore` |
| `StoragePort` | `FirebaseStoragePort` or `LocalStoragePort` | Chosen with repository in `_initializeBackend()` |
| `DisposableIntegration` | `MlKitOcrPort` | Released in `CareStore.dispose()` |

Firebase data layer: `docs/backend_integration.md`. Requirement mapping:
`docs/requirements_trace.md`.

## 1. ML Kit OCR

**File:** `lib/features/care/integrations/mlkit_ocr_port.dart`

**User flow:** Home → Scan doc → camera or gallery → `OcrReviewScreen` → edit
lines / types / selection → Create tasks → `CareStore.createTasksFromOcr` →
active `CareRepository.createTasksFromOcrCandidates` (Firebase or demo).

**Pipeline:**

```text
image → ML Kit (Latin script) → line normalize → keyword/time classify
→ List<OcrCandidate> → user review → repository creates CareTask rows
```

**Rules:**

- Return candidates only; never auto-create tasks.
- Candidates are editable on `OcrReviewScreen` (text + Detected type).
- `confidence` 0.0–1.0 from parser when ML Kit does not supply scores.
- Extract operational text only (meds, appointments, rehab, notes); no medical advice.

**Script:** `TextRecognitionScript.latin` only. Do not enable Chinese OCR
without adding the matching ML Kit dependency (crash risk on some devices,
including Huawei builds without GMS).

**Parsing hints:**

- Medication: `mg`, `tablet`, `daily`, `after meal`, `bid`, `tid`
- Appointment: dates/times, `follow-up`, `clinic`, `doctor`
- Rehab: `walk`, `exercise`, `physio`, `stretch`, `range of motion`
- Note: diet, wound care, observation reminders

**Assignee when creating tasks from OCR** (demo and Firebase backends): prefer
`primaryCarer`, else patient / first family member, else `Unassigned`. The task
list label “Anyone” means no specific assignee was set.

## 2. Local notifications

**File:** `lib/features/care/integrations/local_notification_port.dart`

**Initialization:** `main.dart` calls `await notificationPort.initialize()` before `runApp`.

**Behaviour:**

- Request `POST_NOTIFICATIONS` and exact-alarm permission on Android.
- Schedule reminders for **pending** tasks only.
- Cancel on task delete or completion; reschedule on edit, patient switch, or settings toggle.
- Local only — no FCM push in MVP.
- Uses `zonedSchedule` with UTC mapping; falls back from `exactAllowWhileIdle` to
  `inexactAllowWhileIdle` if exact scheduling fails.
- Debug log prefix: `CareBridge notifications:`.

**CareStore hooks:** `load`, `selectPatient`, `saveTask`, `deleteTask`,
`markTaskStatus`, `setNotificationsEnabled`, `createTasksFromOcr`.

**Android manifest** (`android/app/src/main/AndroidManifest.xml`) must include:

- Permissions: `CAMERA`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`,
  `READ_MEDIA_IMAGES`, `RECEIVE_BOOT_COMPLETED`
- Receivers: `ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`
  (with `BOOT_COMPLETED`), `ActionBroadcastReceiver`

If receivers are missing, **instant test notifications may work while scheduled
task reminders do not**.

**Settings self-test:** `SettingsScreen` — instant notification and ~5 s delayed
test (use the delayed test in the background to distinguish from business reminders).

## 3. Symptom trend chart (fl_chart)

**File:** `lib/features/care/presentation/screens.dart` → `MiniTrendChart`

**Data:** `CareStore.lastSevenLogs` (past 7 calendar days, oldest → newest).

```dart
class MiniTrendChart extends StatelessWidget {
  const MiniTrendChart({required this.logs, super.key});
  final List<SymptomLog> logs;
}
```

- Pain: Y axis 0–10 (left).
- Temperature: second line with right-side style labels.
- Empty state when `logs.isEmpty`.

## 4. Symptom and discharge photos

**Symptom log:** `SymptomLogScreen` uses `image_picker` (gallery). New paths are
uploaded in `CareStore.saveSymptomLog` via `StoragePort.uploadSymptomPhoto`;
URLs or local paths stored in `SymptomLog.photoUrls`. Thumbnails support remove.

**Discharge / OCR source:** `CareStore.scanOcrCandidatesFromImage` uploads via
`StoragePort.uploadDischargeImage` when Storage is available.

**Fallback:** If Firebase Storage fails or demo backend is active, local file
paths are kept so the UI still shows images on device.

## Device testing procedure

Suggested order on a physical Android device:

1. `flutter pub get` → `flutter run -d <device-id>` (after Manifest changes, run
   `flutter clean` then reinstall).
2. **Notifications:** Settings → instant test → ~5 s delayed test (optionally
   send app to background).
3. **OCR:** Home → Scan doc → camera or gallery → edit selection → Create tasks
   → verify tasks on Tasks tab.
4. **Chart:** Log tab → confirm 7-day trend renders.
5. **Firebase (optional):** sign in with cloud backend; restart app and confirm
   data persists; if init fails, app should fall back to demo mode without crashing.

## Manual verification checklist

| Check | Expected |
| --- | --- |
| OCR from real image | Candidates appear on review screen |
| OCR confirmation | Tasks created only after user taps Create tasks |
| Notification permission | Android 13+ prompt; settings test pings work |
| Task reminder | Pending task near future time fires notification |
| Complete/delete task | Scheduled notification cancelled |
| 7-day chart | Renders on Log tab without label overlap |
| Symptom photo | Pick, save, thumbnail visible; survives save when upload OK |

## Troubleshooting

| Symptom | Likely cause | Action |
| --- | --- | --- |
| Instant notification works; scheduled reminders do not | Missing notification receivers or exact-alarm permission | Verify Manifest receivers; grant alarms/notifications on Android 12+ |
| Reminders unreliable after reboot | OEM battery restrictions | Allow background activity / disable battery optimization for the app |
| OCR crash on some devices | Chinese script enabled without ML Kit Chinese module | Keep `TextRecognitionScript.latin` until dependency is added |
| Poor OCR on handwritten or Chinese sheets | Latin model + rule parser limits | Edit lines on `OcrReviewScreen` before creating tasks |
| Photo missing in cloud mode | Storage upload failed | Check debug log; local path fallback should still show on device |

## Known limitations

- OCR: English/Latin print; handwriting and Chinese discharge sheets need manual entry.
- Notifications: Some OEMs restrict background alarms; user may need battery/background exemptions.
- Photos: Upload retry UI is minimal; failed upload falls back to local path with debug log.
- Chinese OCR: requires the ML Kit Chinese module on Android plus a deliberate script
  change and fallback strategy; not enabled in the coursework MVP.
