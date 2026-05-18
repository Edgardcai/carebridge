# CareBridge Demo Recording Flow

Use this account for the prepared demo data:

```text
Email: demo.carebridge7506@example.com
Password: CareBridge123!
```

If the account has not been seeded yet, run this command on a network that can
reach Firebase / Google APIs:

```bash
node scripts/seed_demo_account.mjs
```

The script creates one patient, family members, medication tasks, rehab tasks,
a follow-up visit, a missed task, a completed task, and symptom logs for chart
demo.

## Suggested Recording Order

1. Open the app.
2. Accept the legal disclaimer.
3. Log in with the demo account.
4. Show Home:
   - Patient name and recovery day.
   - Today's pending / done counters.
   - Up next cards.
   - Quick actions.
5. Open Tasks:
   - Show Pending / Completed / Missed tabs.
   - Show Meds / Visit / Rehab / Note filters.
   - Open one medication task and one visit task.
   - Mark one pending task completed and show the counter update.
6. Add a task manually:
   - Create a medication task.
   - Show repeat rules: Daily, Every 2 days, Every 3 days, Twice daily,
     Three times daily.
   - Save and confirm it appears in Pending.
7. OCR demo:
   - Open Scan doc.
   - Use camera/gallery with the OCR sample below.
   - Review candidates.
   - Untick one item.
   - Create tasks.
   - Return to Tasks and show the generated tasks.
8. Log demo:
   - Open Log.
   - Enter pain level, temperature, notes.
   - Save entry.
   - Show the 7-day chart and timeline.
9. Family demo:
   - Show overall progress.
   - Show Needs attention.
   - Show team members and progress bars.
10. Settings demo:
    - Toggle Large text.
    - Toggle Notifications.
    - Show Sign out confirmation.
11. Close and reopen the app:
    - Show that Firebase data persists.

## OCR Sample

Use this text as a screenshot, printed note, or handwritten/typed note:

```text
Take Lisinopril 10mg every morning at 8am for 7 days.
Amoxicillin 250mg three times daily for 5 days.
Follow-up clinic appointment tomorrow 2pm.
Walk 15 minutes every other day for 14 days.
Change dressing every 2 days.
Call doctor if fever is above 38 C.
```

## Key Points To Mention In The Video

- Firebase Auth supports real login and account persistence.
- Firestore stores patients, tasks, symptom logs, and family data.
- OCR converts discharge instructions into editable task candidates.
- Repeat reminders support daily, weekly, every 2/3 days, twice daily, and
  three times daily.
- Local notifications remind users about pending recovery tasks.
- Symptom chart supports multiple records in the same day.
- Family dashboard summarizes progress and missed tasks.
