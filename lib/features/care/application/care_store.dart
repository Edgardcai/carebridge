import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/care_repository.dart';
import '../domain/models.dart';
import '../integrations/integration_ports.dart';
import '../integrations/local_notification_port.dart';

class CareStore extends ChangeNotifier {
  CareStore(
    this._repository, {
    OcrPort? ocrPort,
    NotificationPort? notificationPort,
    StoragePort? storagePort,
  })  : _ocrPort = ocrPort,
        _notificationPort = notificationPort,
        _storagePort = storagePort;

  final CareRepository _repository;
  final OcrPort? _ocrPort;
  final NotificationPort? _notificationPort;
  final StoragePort? _storagePort;

  CareBundle _bundle = const CareBundle(
    user: null,
    patients: [],
    tasks: [],
    symptomLogs: [],
    familyMembers: [],
    ocrCandidates: [],
  );

  bool _isLoading = true;
  bool _legalAccepted = false;
  bool _largeText = false;
  bool _notificationsEnabled = true;
  String? _selectedPatientId;
  String? _lastError;

  bool get isLoading => _isLoading;
  bool get legalAccepted => _legalAccepted;
  bool get isSignedIn => _bundle.user != null;
  bool get largeText => _largeText;
  bool get notificationsEnabled => _notificationsEnabled;
  String? get lastError => _lastError;
  AppUser? get user => _bundle.user;

  List<PatientProfile> get patients => [..._bundle.patients];

  PatientProfile? get selectedPatient {
    if (_bundle.patients.isEmpty) {
      return null;
    }
    return _bundle.patients.firstWhere(
      (patient) => patient.id == _selectedPatientId,
      orElse: () => _bundle.patients.first,
    );
  }

  List<FamilyMember> get familyMembers {
    final patient = selectedPatient;
    if (patient == null) {
      return [];
    }
    return _bundle.familyMembers
        .where((member) => member.patientId == patient.id)
        .toList(growable: false);
  }

  List<CareTask> get tasks {
    final patient = selectedPatient;
    if (patient == null) {
      return [];
    }
    final next =
        _bundle.tasks.where((task) => task.patientId == patient.id).toList();
    next.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return next;
  }

  List<CareTask> get todayTasks {
    final now = DateTime.now();
    return tasks.where((task) => task.isOnDate(now)).toList(growable: false);
  }

  List<CareTask> get pendingTasks => tasks
      .where((task) => task.status == TaskStatus.pending)
      .toList(growable: false);

  List<CareTask> get completedTasks => tasks
      .where((task) => task.status == TaskStatus.completed)
      .toList(growable: false);

  List<CareTask> get missedTasks => tasks
      .where((task) => task.status == TaskStatus.missed)
      .toList(growable: false);

  List<CareTask> get todayPending => todayTasks
      .where((task) => task.status == TaskStatus.pending)
      .toList(growable: false);

  List<CareTask> get todayDone {
    final now = DateTime.now();
    return tasks.where((task) {
      if (task.status != TaskStatus.completed) {
        return false;
      }
      final completedAt = task.completedAt;
      if (completedAt != null) {
        return _sameDay(completedAt, now);
      }
      return task.isOnDate(now);
    }).toList(growable: false);
  }

  List<CareTask> get needsAttentionTasks => missedTasks;

  CareTask? get nextAppointment {
    final now = DateTime.now();
    final visits = tasks
        .where(
          (task) =>
              task.type == TaskType.visit &&
              task.status == TaskStatus.pending &&
              task.scheduledAt
                  .isAfter(now.subtract(const Duration(minutes: 1))),
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return visits.isEmpty ? null : visits.first;
  }

  List<SymptomLog> get symptomLogs {
    final patient = selectedPatient;
    if (patient == null) {
      return [];
    }
    final next = _bundle.symptomLogs
        .where((log) => log.patientId == patient.id)
        .toList();
    next.sort((a, b) => b.date.compareTo(a.date));
    return next;
  }

  SymptomLog? get todayLog {
    final now = DateTime.now();
    for (final log in symptomLogs) {
      if (_sameDay(log.date, now)) {
        return log;
      }
    }
    return null;
  }

  List<SymptomLog> get lastSevenLogs {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final next = symptomLogs.where((log) => !log.date.isBefore(start)).toList();
    next.sort((a, b) => a.date.compareTo(b.date));
    return next;
  }

  List<OcrCandidate> get ocrCandidates {
    final patient = selectedPatient;
    if (patient == null) {
      return [];
    }
    return _bundle.ocrCandidates
        .where((candidate) => candidate.patientId == patient.id)
        .toList(growable: false);
  }

  /// Optional: verify local notifications on-device (Settings).
  Future<bool> scheduleTestLocalNotification() async {
    final port = _notificationPort;
    if (port is LocalNotificationPort) {
      await port.scheduleTestPingIn(const Duration(seconds: 5));
      return true;
    }
    return false;
  }

  Future<bool> showInstantTestLocalNotification() async {
    final port = _notificationPort;
    if (port is LocalNotificationPort) {
      await port.showInstantTest();
      return true;
    }
    return false;
  }

  Future<void> load() async {
    _setLoading(true);
    try {
      _bundle = await _repository.load();
      _selectedPatientId =
          _bundle.patients.isEmpty ? null : _bundle.patients.first.id;
      if (_notificationPort != null) {
        await _notificationPort.requestPermission();
        await _notificationPort
            .rescheduleAll(_pendingTasksForSelectedPatient());
      }
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _setLoading(false);
    }
  }

  void acceptLegal() {
    _legalAccepted = true;
    notifyListeners();
  }

  Future<void> signInDemo({
    required String email,
    String? password,
    bool createAccount = false,
  }) async {
    final safeEmail =
        email.trim().isEmpty ? 'demo@carebridge.local' : email.trim();
    final displayName = safeEmail.split('@').first;
    final user = await _repository.signInDemo(
      email: safeEmail,
      displayName: displayName,
      password: password,
      createAccount: createAccount,
    );
    try {
      _bundle = await _repository.load();
      _selectedPatientId =
          _bundle.patients.isEmpty ? null : _bundle.patients.first.id;
      if (_notificationPort != null) {
        await _notificationPort
            .rescheduleAll(_pendingTasksForSelectedPatient());
      }
      _lastError = null;
    } catch (error) {
      _bundle = _bundle.copyWith(user: user);
      _lastError = error.toString();
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _bundle = _bundle.copyWith(clearUser: true);
    notifyListeners();
  }

  Future<void> selectPatient(String patientId) async {
    _selectedPatientId = patientId;
    await _repository.selectPatient(patientId);
    if (_notificationPort != null) {
      await _notificationPort.rescheduleAll(_pendingTasksForSelectedPatient());
    }
    notifyListeners();
  }

  Future<void> savePatient(PatientProfile patient) async {
    final saved = await _repository.upsertPatient(patient);
    final next = [..._bundle.patients];
    final index = next.indexWhere((item) => item.id == saved.id);
    if (index == -1) {
      next.add(saved);
    } else {
      next[index] = saved;
    }
    _bundle = _bundle.copyWith(patients: next);
    _selectedPatientId = saved.id;
    notifyListeners();
  }

  Future<void> saveTask(CareTask task) async {
    final saved = await _repository.upsertTask(task);
    final next = [..._bundle.tasks];
    final index = next.indexWhere((item) => item.id == saved.id);
    if (index == -1) {
      next.add(saved);
    } else {
      next[index] = saved;
    }
    _bundle = _bundle.copyWith(tasks: next);
    notifyListeners();
    if (_notificationPort != null && _notificationsEnabled) {
      unawaited(_syncReminderForTask(saved));
    }
  }

  Future<void> deleteTask(String taskId) async {
    await _repository.deleteTask(taskId);
    _bundle = _bundle.copyWith(
      tasks: _bundle.tasks.where((task) => task.id != taskId).toList(),
    );
    notifyListeners();
    if (_notificationPort != null) {
      unawaited(_cancelReminder(taskId));
    }
  }

  Future<void> markTaskStatus(String taskId, TaskStatus status) async {
    final saved = await _repository.markTaskStatus(taskId, status);
    final next = [..._bundle.tasks];
    final index = next.indexWhere((item) => item.id == saved.id);
    if (index != -1) {
      next[index] = saved;
    }
    _bundle = _bundle.copyWith(tasks: next);
    notifyListeners();
    if (_notificationPort != null) {
      unawaited(_syncReminderForTask(saved));
    }
  }

  Future<void> _syncReminderForTask(CareTask task) async {
    final port = _notificationPort;
    if (port == null) {
      return;
    }
    try {
      if (task.status == TaskStatus.pending && _notificationsEnabled) {
        await port.scheduleTaskReminder(task);
      } else {
        await port.cancelTaskReminder(task.id);
      }
    } catch (error) {
      debugPrint('CareBridge notifications: task reminder sync failed: $error');
    }
  }

  Future<void> _cancelReminder(String taskId) async {
    try {
      await _notificationPort?.cancelTaskReminder(taskId);
    } catch (error) {
      debugPrint('CareBridge notifications: reminder cancel failed: $error');
    }
  }

  Future<void> saveSymptomLog({
    required DateTime date,
    required int painLevel,
    required double temperatureC,
    required String notes,
    List<String> preservedPhotoUrls = const [],
    List<String> localPhotoPaths = const [],
  }) async {
    final patient = selectedPatient;
    if (patient == null) {
      return;
    }

    final uploadedUrls = <String>[];
    for (final localPath in localPhotoPaths) {
      if (_storagePort == null) {
        uploadedUrls.add(localPath);
        continue;
      }
      final uploaded = await _storagePort
          .uploadSymptomPhoto(
        patientId: patient.id,
        logDate: date,
        localPath: localPath,
      )
          .catchError((Object error) {
        debugPrint('CareBridge storage: symptom upload failed: $error');
        return localPath;
      });
      uploadedUrls.add(uploaded);
    }
    final now = DateTime.now();
    final logMoment = DateTime(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
    final log = SymptomLog(
      id: '',
      patientId: patient.id,
      date: logMoment,
      painLevel: painLevel,
      temperatureC: temperatureC,
      notes: notes,
      photoUrls: [...preservedPhotoUrls, ...uploadedUrls],
      createdAt: now,
      updatedAt: now,
    );

    final saved = await _repository.upsertSymptomLog(log);
    final next = [..._bundle.symptomLogs];
    final index = next.indexWhere((item) => item.id == saved.id);
    if (index == -1) {
      next.add(saved);
    } else {
      next[index] = saved;
    }
    _bundle = _bundle.copyWith(symptomLogs: next);
    notifyListeners();
  }

  Future<int> createTasksFromOcr(List<OcrCandidate> candidates) async {
    final created = await _repository.createTasksFromOcrCandidates(candidates);
    final patient = selectedPatient;
    _bundle = _bundle.copyWith(
      tasks: _mergeTasks(_bundle.tasks, created),
      ocrCandidates: patient == null
          ? _bundle.ocrCandidates
          : _bundle.ocrCandidates
              .where((candidate) => candidate.patientId != patient.id)
              .toList(growable: false),
    );
    notifyListeners();
    if (_notificationPort != null && _notificationsEnabled) {
      unawaited(_scheduleCreatedTaskReminders(created));
    }
    return created.length;
  }

  Future<void> _scheduleCreatedTaskReminders(List<CareTask> created) async {
    final port = _notificationPort;
    if (port == null) {
      return;
    }
    for (final task in created) {
      if (task.status == TaskStatus.pending) {
        try {
          await port.scheduleTaskReminder(task);
        } catch (error) {
          debugPrint(
              'CareBridge notifications: OCR task schedule failed: $error');
        }
      }
    }
  }

  List<CareTask> _mergeTasks(List<CareTask> current, List<CareTask> incoming) {
    final next = [...current];
    final seen = current.map(_taskFingerprint).toSet();
    for (final task in incoming) {
      final key = _taskFingerprint(task);
      if (seen.add(key)) {
        next.add(task);
      }
    }
    return next;
  }

  String _taskFingerprint(CareTask task) {
    final normalizedDetails = task.details
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final normalizedTitle =
        task.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return [
      task.patientId,
      task.type.name,
      normalizedDetails.isEmpty ? normalizedTitle : normalizedDetails,
    ].join('|');
  }

  Future<int> scanOcrCandidatesFromImage(String localImagePath) async {
    final patient = selectedPatient;
    if (patient == null) return 0;
    if (_ocrPort == null) {
      throw Exception('OCR service is not configured.');
    }
    final candidates = await _ocrPort.extractTaskCandidates(
      patientId: patient.id,
      localImagePath: localImagePath,
    );
    String? sourceImageUrl;
    if (_storagePort != null) {
      try {
        sourceImageUrl = await _storagePort.uploadDischargeImage(
          patientId: patient.id,
          localPath: localImagePath,
        );
      } catch (error) {
        debugPrint('CareBridge storage: discharge upload failed: $error');
        sourceImageUrl = localImagePath;
      }
    }
    final sourcedCandidates = sourceImageUrl == null
        ? candidates
        : candidates
            .map((candidate) =>
                candidate.copyWith(sourceImageUrl: sourceImageUrl))
            .toList(growable: false);
    _bundle = _bundle.copyWith(ocrCandidates: [
      ..._bundle.ocrCandidates.where((item) => item.patientId != patient.id),
      ...sourcedCandidates,
    ]);
    notifyListeners();
    return sourcedCandidates.length;
  }

  CareTask? taskById(String taskId) {
    for (final task in _bundle.tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  FamilyMember? memberById(String? memberId) {
    if (memberId == null) {
      return null;
    }
    for (final member in familyMembers) {
      if (member.id == memberId) {
        return member;
      }
    }
    return null;
  }

  PatientProfile blankPatient() {
    final now = DateTime.now();
    return PatientProfile(
      id: '',
      ownerUid: user?.uid ?? 'demo_user_1',
      fullName: '',
      dischargeDate: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  CareTask blankTask() {
    final patient = selectedPatient;
    final now = DateTime.now();
    return CareTask(
      id: '',
      patientId: patient?.id ?? '',
      title: '',
      type: TaskType.medication,
      status: TaskStatus.pending,
      scheduledAt: DateTime(now.year, now.month, now.day, now.hour + 1),
      assigneeId: familyMembers.isEmpty ? null : familyMembers.first.id,
      assigneeName: familyMembers.isEmpty
          ? 'Unassigned'
          : familyMembers.first.displayName,
      createdAt: now,
      updatedAt: now,
    );
  }

  void setLargeText(bool value) {
    _largeText = value;
    notifyListeners();
  }

  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    if (_notificationPort != null) {
      if (value) {
        unawaited(
            _notificationPort.rescheduleAll(_pendingTasksForSelectedPatient()));
      } else {
        for (final task in _pendingTasksForSelectedPatient()) {
          unawaited(_notificationPort.cancelTaskReminder(task.id));
        }
      }
    }
    notifyListeners();
  }

  double get avgPain7d {
    if (lastSevenLogs.isEmpty) {
      return 0;
    }
    final sum =
        lastSevenLogs.fold<int>(0, (total, log) => total + log.painLevel);
    return sum / lastSevenLogs.length;
  }

  double get maxTemp7d {
    if (lastSevenLogs.isEmpty) {
      return 0;
    }
    return lastSevenLogs
        .map((log) => log.temperatureC)
        .reduce((a, b) => a > b ? a : b);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<CareTask> _pendingTasksForSelectedPatient() {
    final patient = selectedPatient;
    if (patient == null) return const [];
    return _bundle.tasks
        .where((task) =>
            task.patientId == patient.id && task.status == TaskStatus.pending)
        .toList(growable: false);
  }

  @override
  void dispose() {
    final ocrPort = _ocrPort;
    if (ocrPort is DisposableIntegration) {
      unawaited((ocrPort as DisposableIntegration).disposeIntegration());
    }
    super.dispose();
  }
}
