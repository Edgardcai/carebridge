import '../domain/models.dart';
import 'care_repository.dart';

class DemoCareRepository implements CareRepository {
  DemoCareRepository() : _bundle = _seedBundle();

  CareBundle _bundle;
  String? _selectedPatientId;

  @override
  Future<CareBundle> load() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _bundle;
  }

  @override
  Future<AppUser> signInDemo({
    required String email,
    required String displayName,
  }) async {
    final user = AppUser(
      uid: 'demo_user_1',
      email: email,
      displayName: displayName,
    );
    _bundle = _bundle.copyWith(user: user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _bundle = _bundle.copyWith(clearUser: true);
  }

  @override
  Future<void> selectPatient(String patientId) async {
    _selectedPatientId = patientId;
  }

  String? get selectedPatientId => _selectedPatientId;

  @override
  Future<PatientProfile> upsertPatient(PatientProfile patient) async {
    final now = DateTime.now();
    final normalized = patient.id.isEmpty
        ? patient.copyWith(
            id: _id('patient'),
            createdAt: now,
            updatedAt: now,
          )
        : patient.copyWith(updatedAt: now);

    final next = [..._bundle.patients];
    final index = next.indexWhere((item) => item.id == normalized.id);
    if (index == -1) {
      next.add(normalized);
    } else {
      next[index] = normalized;
    }
    _bundle = _bundle.copyWith(patients: next);
    _selectedPatientId = normalized.id;
    return normalized;
  }

  @override
  Future<CareTask> upsertTask(CareTask task) async {
    final now = DateTime.now();
    final normalized = task.id.isEmpty
        ? task.copyWith(
            id: _id('task'),
            createdAt: now,
            updatedAt: now,
          )
        : task.copyWith(updatedAt: now);

    final next = [..._bundle.tasks];
    final index = next.indexWhere((item) => item.id == normalized.id);
    if (index == -1) {
      next.add(normalized);
    } else {
      next[index] = normalized;
    }
    _bundle = _bundle.copyWith(tasks: next);
    return normalized;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _bundle = _bundle.copyWith(
      tasks: _bundle.tasks.where((task) => task.id != taskId).toList(),
    );
  }

  @override
  Future<CareTask> markTaskStatus(String taskId, TaskStatus status) async {
    final now = DateTime.now();
    final task = _bundle.tasks.firstWhere((item) => item.id == taskId);
    final updated = task.copyWith(
      status: status,
      completedAt: status == TaskStatus.completed ? now : null,
      clearCompletedAt: status != TaskStatus.completed,
      updatedAt: now,
    );
    await upsertTask(updated);
    return updated;
  }

  @override
  Future<SymptomLog> upsertSymptomLog(SymptomLog log) async {
    final now = DateTime.now();
    final normalized = log.id.isEmpty
        ? log.copyWith(
            id: _id('log'),
            createdAt: now,
            updatedAt: now,
          )
        : log.copyWith(updatedAt: now);

    final next = [..._bundle.symptomLogs];
    final index = next.indexWhere(
      (item) =>
          item.id == normalized.id ||
          (item.patientId == normalized.patientId && _sameDay(item.date, normalized.date)),
    );
    if (index == -1) {
      next.add(normalized);
    } else {
      next[index] = normalized;
    }
    _bundle = _bundle.copyWith(symptomLogs: next);
    return normalized;
  }

  @override
  Future<List<CareTask>> createTasksFromOcrCandidates(
    List<OcrCandidate> candidates,
  ) async {
    final now = DateTime.now();
    final selected = candidates.where((item) => item.selected).toList();
    final created = <CareTask>[];
    final byPatient = <String, FamilyMember?>{};

    for (final candidate in selected) {
      final defaultAssignee = byPatient.putIfAbsent(
        candidate.patientId,
        () => _defaultAssigneeFor(candidate.patientId),
      );
      final task = CareTask(
        id: _id('task'),
        patientId: candidate.patientId,
        title: _titleFromCandidate(candidate),
        details: candidate.extractedText,
        type: _typeFromCandidate(candidate.type),
        status: TaskStatus.pending,
        scheduledAt: candidate.scheduledAt ?? DateTime(now.year, now.month, now.day, 9),
        repeatRule: candidate.type == OcrCandidateType.medication
            ? RepeatRule.daily
            : RepeatRule.none,
        remindMinutesBefore: candidate.type == OcrCandidateType.appointment ? 1440 : 0,
        assigneeId: defaultAssignee?.id,
        assigneeName: defaultAssignee?.displayName ?? 'Unassigned',
        sourceLabel: 'Discharge_Instructions_DrSmith.jpg',
        createdAt: now,
        updatedAt: now,
      );
      created.add(task);
    }

    _bundle = _bundle.copyWith(tasks: [..._bundle.tasks, ...created]);
    return created;
  }

  static CareBundle _seedBundle() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime at(int days, int hour, [int minute = 0]) {
      return today.add(Duration(days: days, hours: hour, minutes: minute));
    }

    final patient = PatientProfile(
      id: 'patient_1',
      ownerUid: 'demo_user_1',
      fullName: 'Eleanor Smith',
      age: 65,
      dischargeDate: today.subtract(const Duration(days: 11)),
      conditionCategory: 'Post-op Knee',
      mainDepartment: 'Orthopedics',
      emergencyContact: const EmergencyContact(
        name: 'Sarah Lee',
        relationship: 'Daughter',
        phone: '+852 5555 0101',
      ),
      createdAt: now.subtract(const Duration(days: 12)),
      updatedAt: now,
    );

    final members = [
      const FamilyMember(
        id: 'member_you',
        patientId: 'patient_1',
        displayName: 'You',
        relationship: 'Primary carer',
        role: FamilyRole.primaryCarer,
        readOnly: false,
      ),
      const FamilyMember(
        id: 'member_sarah',
        patientId: 'patient_1',
        displayName: 'Sarah',
        relationship: 'Daughter',
        role: FamilyRole.familyViewer,
      ),
      const FamilyMember(
        id: 'member_mark',
        patientId: 'patient_1',
        displayName: 'Mark',
        relationship: 'Husband',
        role: FamilyRole.familyViewer,
      ),
    ];

    final tasks = [
      CareTask(
        id: 'task_meds_morning',
        patientId: patient.id,
        title: 'Lisinopril 10mg',
        details:
            'Take 1 tablet by mouth once daily in the morning with a full glass of water. May be taken with or without food.',
        type: TaskType.medication,
        status: TaskStatus.pending,
        scheduledAt: at(0, 8),
        repeatRule: RepeatRule.daily,
        assigneeId: 'member_you',
        assigneeName: 'You',
        sourceLabel: 'Discharge_Summary_0412.pdf',
        createdAt: now.subtract(const Duration(days: 9)),
        updatedAt: now,
      ),
      CareTask(
        id: 'task_pt',
        patientId: patient.id,
        title: 'Physical Therapy',
        details: 'Lower body stretching and gentle walking for 15 minutes.',
        type: TaskType.rehab,
        status: TaskStatus.pending,
        scheduledAt: at(0, 10, 30),
        repeatRule: RepeatRule.daily,
        assigneeId: 'member_mark',
        assigneeName: 'Mark',
        createdAt: now.subtract(const Duration(days: 8)),
        updatedAt: now,
      ),
      CareTask(
        id: 'task_nurse',
        patientId: patient.id,
        title: 'Nurse Check-in',
        details: 'Vitals and wound check. Prepare latest symptom notes.',
        type: TaskType.visit,
        status: TaskStatus.pending,
        scheduledAt: at(0, 14),
        assigneeId: 'member_you',
        assigneeName: 'You',
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      ),
      CareTask(
        id: 'task_done_water',
        patientId: patient.id,
        title: 'Hydration check',
        details: 'Drink water with breakfast and update family if appetite is low.',
        type: TaskType.note,
        status: TaskStatus.completed,
        scheduledAt: at(0, 7, 30),
        assigneeId: 'member_sarah',
        assigneeName: 'Sarah',
        completedAt: at(0, 7, 42),
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      ),
      CareTask(
        id: 'task_missed_weight',
        patientId: patient.id,
        title: 'Daily Weight Check',
        details: 'Log fasting weight before breakfast.',
        type: TaskType.note,
        status: TaskStatus.missed,
        scheduledAt: at(-1, 8, 30),
        assigneeId: 'member_you',
        assigneeName: 'You',
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now,
      ),
      CareTask(
        id: 'task_followup',
        patientId: patient.id,
        title: 'Post-op Follow-up',
        details: 'Dr. Sarah Jenkins, Orthopedics. Bring symptom timeline.',
        type: TaskType.visit,
        status: TaskStatus.pending,
        scheduledAt: at(1, 14),
        remindMinutesBefore: 1440,
        assigneeId: 'member_sarah',
        assigneeName: 'Sarah',
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now,
      ),
    ];

    final logs = List.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      final pain = [6, 5, 5, 4, 4, 3, 2][index];
      final temps = [37.8, 37.4, 37.2, 37.2, 37.0, 36.9, 36.8];
      return SymptomLog(
        id: 'log_$index',
        patientId: patient.id,
        date: day,
        painLevel: pain,
        temperatureC: temps[index],
        notes: index == 6
            ? 'Feeling much better this morning. Incision site looks clean.'
            : 'Slight ache after walking. Medication taken as instructed.',
        createdAt: day.add(const Duration(hours: 10)),
        updatedAt: day.add(const Duration(hours: 10)),
      );
    });

    final candidates = [
      OcrCandidate(
        id: 'ocr_1',
        patientId: patient.id,
        type: OcrCandidateType.medication,
        extractedText: 'Lisinopril 10mg, once daily in the morning with food.',
        confidence: 0.93,
        scheduledAt: at(0, 8),
      ),
      OcrCandidate(
        id: 'ocr_2',
        patientId: patient.id,
        type: OcrCandidateType.appointment,
        extractedText: 'Orthopedics follow-up appointment tomorrow 2:00 PM.',
        confidence: 0.88,
        scheduledAt: at(1, 14),
      ),
      OcrCandidate(
        id: 'ocr_3',
        patientId: patient.id,
        type: OcrCandidateType.instruction,
        extractedText: 'Walk 15 minutes daily. Stop and call clinic if severe pain.',
        confidence: 0.72,
        scheduledAt: at(0, 10, 30),
      ),
    ];

    return CareBundle(
      user: null,
      patients: [patient],
      tasks: tasks,
      symptomLogs: logs,
      familyMembers: members,
      ocrCandidates: candidates,
    );
  }

  static String _id(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _titleFromCandidate(OcrCandidate candidate) {
    final parsed = _extractTitleFromText(candidate.extractedText, candidate.type);
    if (parsed != null && parsed.isNotEmpty) {
      return parsed;
    }
    switch (candidate.type) {
      case OcrCandidateType.medication:
        return 'Medication task';
      case OcrCandidateType.appointment:
        return 'Clinic appointment';
      case OcrCandidateType.instruction:
        return 'Recovery instruction';
      case OcrCandidateType.other:
        return 'Scanned note';
    }
  }

  FamilyMember? _defaultAssigneeFor(String patientId) {
    final members = _bundle.familyMembers.where((m) => m.patientId == patientId).toList();
    for (final member in members) {
      if (member.role == FamilyRole.primaryCarer) return member;
    }
    for (final member in members) {
      if (member.role == FamilyRole.patient) return member;
    }
    return members.isEmpty ? null : members.first;
  }

  String? _extractTitleFromText(String raw, OcrCandidateType type) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    switch (type) {
      case OcrCandidateType.medication:
        final med = RegExp(
          r'([A-Za-z][A-Za-z0-9\-]*(?:\s+[A-Za-z][A-Za-z0-9\-]*){0,2}\s+\d+(?:\.\d+)?\s?(?:mg|g|ml))',
          caseSensitive: false,
        ).firstMatch(text);
        if (med != null) return med.group(1);
        final take = RegExp(r'(?:take|medicine|drug)\s+([A-Za-z][A-Za-z0-9\- ]{2,30})', caseSensitive: false)
            .firstMatch(text);
        if (take != null) return take.group(1)?.trim();
        break;
      case OcrCandidateType.appointment:
        final clinic = RegExp(r'(?:appointment|follow[- ]?up)\s+(?:with\s+)?([A-Za-z][A-Za-z .-]{2,40})', caseSensitive: false)
            .firstMatch(text);
        if (clinic != null) return 'Appointment: ${clinic.group(1)!.trim()}';
        break;
      case OcrCandidateType.instruction:
        final verb = RegExp(r'^(walk|exercise|stretch|physio)\b', caseSensitive: false).firstMatch(text);
        if (verb != null) return '${verb.group(1)![0].toUpperCase()}${verb.group(1)!.substring(1)} plan';
        break;
      case OcrCandidateType.other:
        break;
    }

    final sentence = text.split(RegExp(r'[.;,]')).first.trim();
    if (sentence.length <= 48) return sentence;
    return '${sentence.substring(0, 45)}...';
  }

  static TaskType _typeFromCandidate(OcrCandidateType type) {
    switch (type) {
      case OcrCandidateType.medication:
        return TaskType.medication;
      case OcrCandidateType.appointment:
        return TaskType.visit;
      case OcrCandidateType.instruction:
        return TaskType.rehab;
      case OcrCandidateType.other:
        return TaskType.note;
    }
  }
}
