# Requirements Traceability

This matrix maps MVP requirements to the current CareBridge implementation.
Requirement sources: course project brief, team design documents, and UI
specifications (final report: local `Submission/DocumentFile.pdf` for Moodle — not in Git; see root `README.md`).

## MVP scope mapped to implementation

| Requirement | Implementation | Notes |
| --- | --- | --- |
| Legal disclaimer | `LegalScreen`, disclaimer dialog in `SettingsScreen` | Acceptance is in-memory only; app shows legal screen again after restart |
| Sign in / sign up | `AuthScreen`, `CareStore.signInDemo` → `CareRepository.signInDemo` | Firebase Email/Password when backend is Firebase; demo credentials work in fallback mode |
| App launch and navigation | `SplashScreen` → legal → auth → patient/home; `CareShell` bottom nav (Home / Tasks / Log / Family) | Route table in `lib/core/routing/app_router.dart` |
| Patient profile | `PatientListScreen`, `PatientFormScreen`, `PatientProfile` | Create, edit, switch selected patient |
| Dashboard | `HomeScreen` | Recovery day, today pending/done, next visit, quick actions including Scan doc |
| Task CRUD | `TasksScreen`, `TaskDetailScreen`, `TaskFormScreen`, repository `upsertTask` / `deleteTask` | Types: medication, visit, rehab, note; repeat rules and assignee supported |
| Task status | Pending / completed filters; mark complete on detail and list | **Missed**: UI filter and display exist; only demo seed includes `missed` — no user action to mark missed |
| OCR-assisted import | `OcrReviewScreen`, `OcrCandidate`, `MlKitOcrPort` | Camera and gallery via `image_picker`; Latin script only |
| Mandatory OCR review | Editable lines, type dropdown, per-row selection before `CareStore.createTasksFromOcr` | Tasks are never created automatically from OCR |
| Symptom log | `SymptomLogScreen`, `SymptomLog`, `CareStore.saveSymptomLog` | Daily pain (0–10), temperature, notes |
| Symptom photos | `SymptomLogScreen` gallery pick; `StoragePort.uploadSymptomPhoto` | Firebase URL or local path fallback |
| 7-day recovery trend | `MiniTrendChart` (`fl_chart`), `CareStore.lastSevenLogs` | Pain and temperature lines on Log tab |
| Recovery timeline | `TimelineScreen` | Seven-day summary for follow-up context |
| Family read-only view | `FamilyHubScreen`, `FamilyMember`, Firestore `sharedWith` / `readOnly` in `FirebaseCareRepository` | Multi-account family invite flow is limited in UI; backend model supports sharing |
| Local notifications | `LocalNotificationPort`, `NotificationPort`, Android permissions, `SettingsScreen` toggles and test pings | Schedules pending tasks; cancel on complete/delete |
| Settings | `SettingsScreen` | Large text, notifications on/off, sign out, notification self-test |
| Firebase backend | `FirebaseCareRepository`, `FirebaseStoragePort`, `lib/firebase_options.dart` | **Fallback**: `DemoCareRepository` + `LocalStoragePort` if Firebase init fails |
| Backend bootstrap | `lib/main.dart` → `_initializeBackend()` | Tries Firebase first; logs and falls back to demo on error |

## Repository contract (all backends)

Implemented on both `DemoCareRepository` and `FirebaseCareRepository`:

- `load`, `signInDemo`, `signOut`
- `upsertPatient`, `selectPatient`
- `upsertTask`, `deleteTask`, `markTaskStatus`
- `upsertSymptomLog`, `createTasksFromOcrCandidates`

See `docs/backend_integration.md` for Firestore layout and
`docs/native_integration.md` for OCR, notifications, and chart details.
