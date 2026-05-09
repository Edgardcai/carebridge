# Final Report Outline

Use this as the role A writing base for the final deliverable.

## 1. Project overview

CareBridge is a post-discharge recovery assistant that converts discharge
instructions into daily tasks, reminders, symptom logs, and a family view.

## 2. Problem and users

- Patients often receive fragmented paper instructions after discharge.
- Families need shared visibility into task completion and symptom changes.
- Existing medication apps do not cover the whole post-discharge workflow.

## 3. Competitor research

- Medisafe: strong pill reminders, weak discharge workflow.
- MyTherapy: useful logs, limited family coordination.
- CareClinic: comprehensive, but too complex for a focused recovery MVP.

## 4. MVP features

- Patient profile.
- Task CRUD and status changes.
- OCR-assisted document review with mandatory confirmation.
- Symptom log and 7-day trend.
- Family read-only hub.
- Local notification integration point.

## 5. Architecture

```text
Flutter UI
  -> CareStore state management
  -> CareRepository
  -> Demo repository now / Firebase repository later

Native service ports
  -> OCRPort
  -> NotificationPort
  -> StoragePort
```

## 6. Team contribution

- Role A: UI framework, state management, navigation, integration contracts,
  final report/video.
- Role B: Firebase Auth, Firestore, Storage, security rules.
- Role C: ML Kit OCR, local notifications, fl_chart trend chart.

## 7. Limitations

- No diagnosis or treatment recommendation.
- Demo data is not real medical data.
- OCR candidates must be reviewed by the user before becoming tasks.

## 8. Testing plan

- Navigate full onboarding to dashboard.
- Create/edit/complete tasks.
- Confirm OCR candidates create tasks.
- Save symptom log and inspect timeline.
- Verify family hub summary.
- Firebase sharing/security tests after role B integration.
- Notification and OCR device tests after role C integration.
