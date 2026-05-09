# Requirements Trace

Source material used:

- `group20_pre_ppt.pptx`
- `ppt_history/Copy of CareBridge_Project_Document.docx`
- `stitch_carebridge_recovery_assistant/design_interface.md`
- `stitch_carebridge_recovery_assistant/carebridge_design_system/DESIGN.md`

## MVP scope mapped to implementation

| Requirement | Implementation |
| --- | --- |
| Legal disclaimer | `LegalScreen`, settings disclaimer dialog |
| Sign in / sign up | `AuthScreen`, demo sign-in through `CareStore` |
| Patient profile | `PatientListScreen`, `PatientFormScreen`, `PatientProfile` |
| Dashboard | `HomeScreen`, metrics, up next, appointment, quick actions |
| Task CRUD | `TasksScreen`, `TaskDetailScreen`, `TaskFormScreen`, repository methods |
| Task status | Pending/completed/missed filters and mark-complete action |
| OCR-assisted import | `OcrReviewScreen`, `OcrCandidate`, `OcrPort` |
| Mandatory OCR review | OCR candidates are editable and selectable before task creation |
| Symptom log | `SymptomLogScreen`, `SymptomLog`, daily upsert logic |
| 7-day recovery trend | `MiniTrendChart`, ready to replace with `fl_chart` |
| Recovery timeline | `TimelineScreen`, 7-day summary |
| Family read-only view | `FamilyHubScreen`, `FamilyMember`, Firebase rule contract |
| Local notifications | `NotificationPort`, Android permissions, settings toggles |
| Firebase backend | `CareRepository` abstraction and role B docs |

## Role A deliverables covered

- State management connecting static UI to a data repository.
- Global navigation and screen-to-screen flow.
- Interaction polishing: empty states, snackbars, mandatory OCR review, status
  chips, quick actions, bottom navigation.
- Backend and native integration contracts for roles B and C.
- Final report outline and 1-2 minute demo script.
