#!/usr/bin/env node

const projectId = process.env.FIREBASE_PROJECT_ID || 'carebridge7506';
const apiKey =
  process.env.FIREBASE_API_KEY || 'AIzaSyDqjsh5rbwHmTAmK4xDvzzs0bONfDKIYWo';
const email = process.env.DEMO_EMAIL || 'demo.carebridge7506@example.com';
const password = process.env.DEMO_PASSWORD || 'CareBridge123!';

const authBase = 'https://identitytoolkit.googleapis.com/v1';

async function postJson(url, body, token) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? {Authorization: `Bearer ${token}`} : {}),
    },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : {};
  if (!response.ok) {
    const error = new Error(json?.error?.message || text);
    error.status = response.status;
    error.body = json;
    throw error;
  }
  return json;
}

async function authenticate() {
  try {
    return await postJson(`${authBase}/accounts:signUp?key=${apiKey}`, {
      email,
      password,
      returnSecureToken: true,
    });
  } catch (error) {
    if (String(error.message).includes('EMAIL_EXISTS')) {
      return postJson(`${authBase}/accounts:signInWithPassword?key=${apiKey}`, {
        email,
        password,
        returnSecureToken: true,
      });
    }
    throw error;
  }
}

function firestoreValue(value) {
  if (value === null || value === undefined) {
    return {nullValue: 'NULL_VALUE'};
  }
  if (value instanceof Date) {
    return {timestampValue: value.toISOString()};
  }
  if (typeof value === 'string') {
    return {stringValue: value};
  }
  if (typeof value === 'boolean') {
    return {booleanValue: value};
  }
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? {integerValue: String(value)}
      : {doubleValue: value};
  }
  if (Array.isArray(value)) {
    return value.length
      ? {arrayValue: {values: value.map(firestoreValue)}}
      : {arrayValue: {}};
  }
  return {
    mapValue: {
      fields: Object.fromEntries(
        Object.entries(value).map(([key, nestedValue]) => [
          key,
          firestoreValue(nestedValue),
        ]),
      ),
    },
  };
}

function fields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]),
  );
}

function writeDocument(path, data) {
  return {
    update: {
      name: `projects/${projectId}/databases/(default)/documents/${path}`,
      fields: fields(data),
    },
  };
}

function at(dayOffset, hour, minute = 0) {
  const now = new Date();
  return new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate() + dayOffset,
    hour,
    minute,
    0,
    0,
  );
}

function logId(date) {
  const pad = (value, width = 2) => String(value).padStart(width, '0');
  return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}_${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}_${pad(date.getMilliseconds() * 1000, 6)}`;
}

function task(id, title, details, type, status, scheduledAt, extra = {}) {
  const now = new Date();
  return writeDocument(`patients/demo_patient_elena/tasks/${id}`, {
    patientId: 'demo_patient_elena',
    title,
    details,
    type,
    status,
    scheduledAt,
    repeatRule: 'none',
    repeatDurationDays: 1,
    reminderMinutesOfDay: [],
    remindMinutesBefore: 0,
    assigneeId: 'member_you',
    assigneeName: 'You',
    sourceLabel: null,
    sourceImageUrl: null,
    completedAt: null,
    createdAt: now,
    updatedAt: now,
    ...extra,
  });
}

function symptomLog(date, painLevel, temperatureC, notes) {
  return writeDocument(`patients/demo_patient_elena/symptomLogs/${logId(date)}`, {
    patientId: 'demo_patient_elena',
    date,
    painLevel,
    temperatureC,
    notes,
    photoUrls: [],
    createdAt: date,
    updatedAt: date,
  });
}

function buildWrites(uid) {
  const now = new Date();
  const writes = [
    writeDocument(`users/${uid}`, {
      email,
      displayName: 'Demo Carer',
      selectedPatientId: 'demo_patient_elena',
      createdAt: now,
      updatedAt: now,
    }),
    writeDocument('patients/demo_patient_elena', {
      ownerUid: uid,
      fullName: 'Eleanor Smith',
      age: 65,
      dischargeDate: at(-11, 9),
      conditionCategory: 'Post-op Knee Recovery',
      mainDepartment: 'Orthopedics',
      notes:
        'Discharged after knee replacement. Monitor pain, temperature, wound site, and rehab adherence.',
      emergencyContact: {
        name: 'Sarah Lee',
        relationship: 'Daughter',
        phone: '+852 5555 0101',
      },
      sharedWith: [],
      createdAt: now,
      updatedAt: now,
    }),
    writeDocument('patients/demo_patient_elena/familyMembers/member_you', {
      userUid: uid,
      displayName: 'You',
      relationship: 'Primary carer',
      role: 'primaryCarer',
      readOnly: false,
      createdAt: now,
    }),
    writeDocument('patients/demo_patient_elena/familyMembers/member_sarah', {
      userUid: null,
      displayName: 'Sarah',
      relationship: 'Daughter',
      role: 'familyViewer',
      readOnly: true,
      invitedEmail: 'sarah.demo@example.com',
      createdAt: now,
    }),
    writeDocument('patients/demo_patient_elena/familyMembers/member_mark', {
      userUid: null,
      displayName: 'Mark',
      relationship: 'Husband',
      role: 'familyViewer',
      readOnly: true,
      invitedEmail: 'mark.demo@example.com',
      createdAt: now,
    }),
    task(
      'task_lisinopril_daily',
      'Lisinopril 10mg',
      'Take 1 tablet every morning with water.',
      'medication',
      'pending',
      at(0, 8),
      {
        repeatRule: 'daily',
        repeatDurationDays: 14,
        reminderMinutesOfDay: [480],
        sourceLabel: 'Discharge summary OCR',
      },
    ),
    task(
      'task_amoxicillin_three_times',
      'Amoxicillin 250mg',
      'Take 1 capsule three times daily after meals for 5 days.',
      'medication',
      'pending',
      at(0, 8),
      {
        repeatRule: 'threeTimesDaily',
        repeatDurationDays: 5,
        reminderMinutesOfDay: [480, 780, 1080],
        sourceLabel: 'Discharge summary OCR',
      },
    ),
    task(
      'task_walk_rehab',
      'Walk plan',
      'Walk 15 minutes every other day. Stop if severe pain occurs.',
      'rehab',
      'pending',
      at(0, 9),
      {
        repeatRule: 'everyTwoDays',
        repeatDurationDays: 14,
        reminderMinutesOfDay: [540],
        assigneeId: 'member_mark',
        assigneeName: 'Mark',
        sourceLabel: 'Discharge summary OCR',
      },
    ),
    task(
      'task_followup_clinic',
      'Follow-up clinic appointment',
      'Post-op clinic appointment tomorrow. Bring symptom timeline and medication list.',
      'visit',
      'pending',
      at(1, 14),
      {
        remindMinutesBefore: 1440,
        assigneeId: 'member_sarah',
        assigneeName: 'Sarah',
        sourceLabel: 'Discharge summary OCR',
      },
    ),
    task(
      'task_dressing_every_two',
      'Change dressing',
      'Change wound dressing every 2 days. Keep incision dry and clean.',
      'rehab',
      'pending',
      at(0, 20),
      {
        repeatRule: 'everyTwoDays',
        repeatDurationDays: 10,
        reminderMinutesOfDay: [1200],
        sourceLabel: 'Discharge summary OCR',
      },
    ),
    task(
      'task_call_doctor_fever',
      'Call doctor if fever is above 38 C',
      'Call doctor if temperature is above 38 C, wound redness worsens, or pain suddenly increases.',
      'note',
      'pending',
      at(0, 21),
      {sourceLabel: 'Discharge safety instruction'},
    ),
    task(
      'task_hydration_done',
      'Hydration check',
      'Drink water with breakfast and record appetite.',
      'note',
      'completed',
      at(0, 7, 30),
      {
        repeatRule: 'daily',
        repeatDurationDays: 7,
        reminderMinutesOfDay: [450],
        completedAt: at(0, 7, 45),
        assigneeId: 'member_sarah',
        assigneeName: 'Sarah',
      },
    ),
    task(
      'task_weight_missed',
      'Daily Weight Check',
      'Log fasting weight before breakfast.',
      'note',
      'missed',
      at(-1, 8, 30),
      {
        repeatRule: 'daily',
        repeatDurationDays: 7,
        reminderMinutesOfDay: [510],
      },
    ),
  ];

  const pain = [6, 5, 5, 4, 4, 3, 2];
  const temperatures = [37.8, 37.4, 37.3, 37.2, 37.0, 36.9, 36.8];
  for (let i = 0; i < 7; i += 1) {
    writes.push(
      symptomLog(
        at(-6 + i, 10, 15),
        pain[i],
        temperatures[i],
        i === 6
          ? 'Feeling better. Incision site looks clean.'
          : 'Mild ache after walking. Medication taken.',
      ),
    );
  }
  writes.push(
    symptomLog(
      at(0, 18, 35),
      4,
      37.2,
      'Evening check: slight swelling after walking, improved after rest.',
    ),
  );
  return writes;
}

async function main() {
  const auth = await authenticate();
  const writes = buildWrites(auth.localId);
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:batchWrite`;
  const result = await postJson(url, {writes}, auth.idToken);
  const failed = (result.status || []).filter((status) => status.code);
  if (failed.length) {
    throw new Error(`Firestore writes failed: ${JSON.stringify(failed)}`);
  }

  console.log('Demo account is ready:');
  console.log(`  Email:    ${email}`);
  console.log(`  Password: ${password}`);
  console.log(`  UID:      ${auth.localId}`);
  console.log(`  Writes:   ${writes.length}`);
}

main().catch((error) => {
  console.error('Seed failed:', error.message);
  if (error.body) {
    console.error(JSON.stringify(error.body, null, 2));
  }
  process.exit(1);
});
