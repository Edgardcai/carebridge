import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import 'care_repository.dart';

class FirebaseCareRepository implements CareRepository {
  FirebaseCareRepository({
    firebase_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  static const _defaultPassword = 'carebridge';

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  String? _selectedPatientId;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _patients =>
      _db.collection('patients');

  @override
  Future<CareBundle> load() async {
    final current = _auth.currentUser;
    if (current == null) {
      return _emptyBundle();
    }

    final user = await _ensureUserDoc(current);
    final userDoc = await _users.doc(user.uid).get();
    final persistedSelected =
        (userDoc.data()?['selectedPatientId'] as String?)?.trim();

    final patients = await _loadPatientsForUser(user.uid);
    if (patients.isEmpty) {
      _selectedPatientId = null;
      return _emptyBundle(user: user);
    }

    final selectedId =
        patients.any((patient) => patient.id == persistedSelected)
            ? persistedSelected
            : patients.first.id;
    _selectedPatientId = selectedId;

    final orderedPatients = [...patients]..sort((a, b) {
        if (a.id == selectedId) return -1;
        if (b.id == selectedId) return 1;
        return a.fullName.compareTo(b.fullName);
      });

    final tasks = <CareTask>[];
    final symptomLogs = <SymptomLog>[];
    final familyMembers = <FamilyMember>[];

    for (final patient in orderedPatients) {
      tasks.addAll(await _loadTasks(patient.id));
      symptomLogs.addAll(await _loadSymptomLogs(patient.id));
      familyMembers.addAll(await _loadFamilyMembers(patient, user));
    }

    return CareBundle(
      user: user,
      patients: orderedPatients,
      tasks: tasks,
      symptomLogs: symptomLogs,
      familyMembers: familyMembers,
      ocrCandidates: const [],
    );
  }

  @override
  Future<AppUser> signInDemo({
    required String email,
    required String displayName,
    String? password,
    bool createAccount = false,
  }) async {
    final safeEmail = email.trim();
    final safeName = displayName.trim().isEmpty
        ? safeEmail.split('@').first
        : displayName.trim();
    final safePassword = (password == null || password.trim().isEmpty)
        ? _defaultPassword
        : password.trim();

    firebase_auth.UserCredential credential;
    if (createAccount) {
      credential = await _createOrSignIn(
        email: safeEmail,
        password: safePassword,
      );
    } else {
      credential = await _signInOrCreateDemo(
        email: safeEmail,
        password: safePassword,
      );
    }

    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw Exception('Firebase Auth did not return a user.');
    }
    if (safeName.isNotEmpty && firebaseUser.displayName != safeName) {
      await firebaseUser.updateDisplayName(safeName);
    }
    try {
      return await _ensureUserDoc(firebaseUser, displayName: safeName);
    } catch (error) {
      debugPrint('CareBridge Firebase: user doc write failed: $error');
      return AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? safeEmail,
        displayName: safeName,
        isDemo: false,
      );
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<PatientProfile> upsertPatient(PatientProfile patient) async {
    final uid = _requireUid();
    final now = DateTime.now();
    final creating = patient.id.trim().isEmpty;
    final ref = creating ? _patients.doc() : _patients.doc(patient.id);

    if (!creating) {
      await _ensureCanWritePatient(ref.id);
    }

    final createdAt = creating ? now : patient.createdAt;
    final normalized = patient.copyWith(
      id: ref.id,
      ownerUid: patient.ownerUid.trim().isEmpty ? uid : patient.ownerUid,
      createdAt: createdAt,
      updatedAt: now,
    );

    await ref.set(
      _patientToFirestore(normalized, includeSharedWith: creating),
      SetOptions(merge: true),
    );
    await _ensureDefaultFamilyMember(normalized, await _currentAppUser());
    await selectPatient(normalized.id);
    return normalized;
  }

  @override
  Future<void> selectPatient(String patientId) async {
    final uid = _requireUid();
    final patient = await _patients.doc(patientId).get();
    if (!patient.exists) {
      throw Exception('Patient not found.');
    }
    final data = patient.data() ?? const <String, dynamic>{};
    final ownerUid = data['ownerUid'] as String? ?? '';
    final sharedWith = _stringList(data['sharedWith']);
    if (ownerUid != uid && !sharedWith.contains(uid)) {
      throw Exception('You do not have access to this patient.');
    }
    _selectedPatientId = patientId;
    await _users.doc(uid).set(
      {
        'selectedPatientId': patientId,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<CareTask> upsertTask(CareTask task) async {
    if (task.patientId.trim().isEmpty) {
      throw Exception('Cannot save a task without a patient.');
    }
    await _ensureCanWritePatient(task.patientId);

    final now = DateTime.now();
    final ref = task.id.trim().isEmpty
        ? _taskCollection(task.patientId).doc()
        : _taskCollection(task.patientId).doc(task.id);
    final normalized = task.copyWith(
      id: ref.id,
      createdAt: task.id.trim().isEmpty ? now : task.createdAt,
      updatedAt: now,
    );
    await ref.set(_taskToFirestore(normalized), SetOptions(merge: true));
    return normalized;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final location = await _findTask(taskId);
    await _ensureCanWritePatient(location.patientId);
    await location.ref.delete();
  }

  @override
  Future<CareTask> markTaskStatus(String taskId, TaskStatus status) async {
    final location = await _findTask(taskId);
    await _ensureCanWritePatient(location.patientId);

    final snapshot = await location.ref.get();
    if (!snapshot.exists) {
      throw Exception('Task not found.');
    }
    final task = _taskFromDoc(snapshot, location.patientId);
    final now = DateTime.now();
    final updated = task.copyWith(
      status: status,
      completedAt: status == TaskStatus.completed ? now : null,
      clearCompletedAt: status != TaskStatus.completed,
      updatedAt: now,
    );
    await location.ref.set(_taskToFirestore(updated), SetOptions(merge: true));
    return updated;
  }

  @override
  Future<SymptomLog> upsertSymptomLog(SymptomLog log) async {
    if (log.patientId.trim().isEmpty) {
      throw Exception('Cannot save a symptom log without a patient.');
    }
    await _ensureCanWritePatient(log.patientId);

    final now = DateTime.now();
    final ref = log.id.trim().isEmpty
        ? _symptomCollection(log.patientId).doc(_logId(log.date))
        : _symptomCollection(log.patientId).doc(log.id);
    final normalized = log.copyWith(
      id: ref.id,
      createdAt: log.id.trim().isEmpty ? now : log.createdAt,
      updatedAt: now,
    );
    await ref.set(_symptomLogToFirestore(normalized), SetOptions(merge: true));
    return normalized;
  }

  @override
  Future<List<CareTask>> createTasksFromOcrCandidates(
    List<OcrCandidate> candidates,
  ) async {
    final selected =
        _uniqueCandidates(candidates.where((item) => item.selected));
    if (selected.isEmpty) {
      return const [];
    }

    final now = DateTime.now();
    final created = <CareTask>[];
    final patientCache = <String, PatientProfile>{};
    final assigneeCache = <String, FamilyMember?>{};
    final existingKeysByPatient = <String, Set<String>>{};
    final batch = _db.batch();

    for (final candidate in selected) {
      final patient = await _loadPatient(candidate.patientId, patientCache);
      await _ensureCanWritePatient(patient.id);

      var existingKeys = existingKeysByPatient[patient.id];
      if (existingKeys == null) {
        existingKeys = await _loadTaskFingerprints(patient.id);
        existingKeysByPatient[patient.id] = existingKeys;
      }

      FamilyMember? assignee;
      if (assigneeCache.containsKey(patient.id)) {
        assignee = assigneeCache[patient.id];
      } else {
        assignee = await _defaultAssigneeFor(patient);
        assigneeCache[patient.id] = assignee;
      }
      final repeatRule = _repeatFromCandidate(candidate);
      final durationDays = _durationFromCandidate(candidate, repeatRule);
      final scheduledAt =
          candidate.scheduledAt ?? DateTime(now.year, now.month, now.day, 9);
      final ref = _taskCollection(patient.id).doc();
      final task = CareTask(
        id: ref.id,
        patientId: patient.id,
        title: _titleFromCandidate(candidate),
        details: candidate.extractedText,
        type: _typeFromCandidate(candidate.type),
        status: TaskStatus.pending,
        scheduledAt: scheduledAt,
        repeatRule: repeatRule,
        repeatDurationDays: durationDays,
        reminderMinutesOfDay:
            _timesFromCandidate(candidate, repeatRule, scheduledAt),
        remindMinutesBefore:
            candidate.type == OcrCandidateType.appointment ? 1440 : 0,
        assigneeId: assignee?.id,
        assigneeName: assignee?.displayName ?? 'Unassigned',
        sourceLabel: candidate.sourceImageUrl == null
            ? 'Discharge scan'
            : 'Discharge scan image',
        sourceImageUrl: candidate.sourceImageUrl,
        createdAt: now,
        updatedAt: now,
      );
      if (existingKeys.add(_taskFingerprint(task))) {
        batch.set(ref, _taskToFirestore(task));
        created.add(task);
      }
    }

    if (created.isNotEmpty) {
      await batch.commit();
    }
    return created;
  }

  Future<firebase_auth.UserCredential> _createOrSignIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        return _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      rethrow;
    }
  }

  Future<firebase_auth.UserCredential> _signInOrCreateDemo({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' ||
          error.code == 'invalid-credential') {
        try {
          return await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on firebase_auth.FirebaseAuthException catch (createError) {
          if (createError.code == 'email-already-in-use') {
            throw Exception(
              'This email already exists. Please log in with the original password.',
            );
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<AppUser> _ensureUserDoc(
    firebase_auth.User user, {
    String? displayName,
  }) async {
    final now = DateTime.now();
    final ref = _users.doc(user.uid);
    final snapshot = await ref.get();
    final safeName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : (user.email ?? 'CareBridge user').split('@').first;
    final appUser = AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: safeName,
      isDemo: false,
    );
    await ref.set(
      {
        'email': appUser.email,
        'displayName': appUser.displayName,
        if (!snapshot.exists) 'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
    return appUser;
  }

  Future<AppUser> _currentAppUser() async {
    final current = _auth.currentUser;
    if (current == null) {
      throw Exception('Please sign in first.');
    }
    return _ensureUserDoc(current);
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Please sign in first.');
    }
    return uid;
  }

  CareBundle _emptyBundle({AppUser? user}) => CareBundle(
        user: user,
        patients: const [],
        tasks: const [],
        symptomLogs: const [],
        familyMembers: const [],
        ocrCandidates: const [],
      );

  Future<List<PatientProfile>> _loadPatientsForUser(String uid) async {
    final owned = await _patients.where('ownerUid', isEqualTo: uid).get();
    final shared =
        await _patients.where('sharedWith', arrayContains: uid).get();
    final byId = <String, PatientProfile>{};
    for (final doc in [...owned.docs, ...shared.docs]) {
      byId[doc.id] = _patientFromDoc(doc, uid);
    }
    final patients = byId.values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return patients;
  }

  Future<PatientProfile> _loadPatient(
    String patientId,
    Map<String, PatientProfile> cache,
  ) async {
    final cached = cache[patientId];
    if (cached != null) {
      return cached;
    }
    final snapshot = await _patients.doc(patientId).get();
    if (!snapshot.exists) {
      throw Exception('Patient not found for OCR task creation.');
    }
    final patient = _patientFromDoc(snapshot, _requireUid());
    cache[patientId] = patient;
    return patient;
  }

  Future<List<CareTask>> _loadTasks(String patientId) async {
    final snapshot = await _taskCollection(patientId).get();
    final tasks =
        snapshot.docs.map((doc) => _taskFromDoc(doc, patientId)).toList();
    tasks.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return tasks;
  }

  Future<List<SymptomLog>> _loadSymptomLogs(String patientId) async {
    final snapshot = await _symptomCollection(patientId).get();
    final logs =
        snapshot.docs.map((doc) => _symptomLogFromDoc(doc, patientId)).toList();
    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  }

  Future<List<FamilyMember>> _loadFamilyMembers(
    PatientProfile patient,
    AppUser user,
  ) async {
    final snapshot = await _familyCollection(patient.id).get();
    final members = snapshot.docs
        .map((doc) => _familyMemberFromDoc(doc, patient.id))
        .toList();
    if (members.isEmpty && patient.ownerUid == user.uid) {
      final owner = await _ensureDefaultFamilyMember(patient, user);
      return [owner];
    }
    members.sort((a, b) {
      final roleCompare = a.role.index.compareTo(b.role.index);
      if (roleCompare != 0) return roleCompare;
      return a.displayName.compareTo(b.displayName);
    });
    return members;
  }

  Future<FamilyMember> _ensureDefaultFamilyMember(
    PatientProfile patient,
    AppUser user,
  ) async {
    final member = FamilyMember(
      id: 'member_${_safeId(user.uid)}',
      patientId: patient.id,
      displayName: user.displayName.isEmpty ? 'You' : user.displayName,
      relationship: 'Primary carer',
      role: FamilyRole.primaryCarer,
      userUid: user.uid,
      readOnly: false,
    );
    await _familyCollection(patient.id).doc(member.id).set(
          _familyMemberToFirestore(member),
          SetOptions(merge: true),
        );
    return member;
  }

  Future<void> _ensureCanWritePatient(String patientId) async {
    final uid = _requireUid();
    final patient = await _patients.doc(patientId).get();
    if (!patient.exists) {
      throw Exception('Patient not found.');
    }
    final data = patient.data() ?? const <String, dynamic>{};
    if (data['ownerUid'] == uid) {
      return;
    }
    final family = await _familyCollection(patientId)
        .where('userUid', isEqualTo: uid)
        .limit(1)
        .get();
    for (final member in family.docs) {
      if (member.data()['readOnly'] != true) {
        return;
      }
    }
    throw Exception('You do not have permission to edit this patient.');
  }

  CollectionReference<Map<String, dynamic>> _taskCollection(String patientId) =>
      _patients.doc(patientId).collection('tasks');

  CollectionReference<Map<String, dynamic>> _symptomCollection(
    String patientId,
  ) =>
      _patients.doc(patientId).collection('symptomLogs');

  CollectionReference<Map<String, dynamic>> _familyCollection(
    String patientId,
  ) =>
      _patients.doc(patientId).collection('familyMembers');

  Future<_TaskLocation> _findTask(String taskId) async {
    final selected = _selectedPatientId;
    if (selected != null) {
      final ref = _taskCollection(selected).doc(taskId);
      final snapshot = await ref.get();
      if (snapshot.exists) {
        return _TaskLocation(patientId: selected, ref: ref);
      }
    }

    final patients = await _loadPatientsForUser(_requireUid());
    for (final patient in patients) {
      final ref = _taskCollection(patient.id).doc(taskId);
      final snapshot = await ref.get();
      if (snapshot.exists) {
        return _TaskLocation(patientId: patient.id, ref: ref);
      }
    }
    throw Exception('Task not found.');
  }

  Future<Set<String>> _loadTaskFingerprints(String patientId) async {
    final tasks = await _loadTasks(patientId);
    return tasks.map(_taskFingerprint).toSet();
  }

  Map<String, dynamic> _patientToFirestore(
    PatientProfile patient, {
    bool includeSharedWith = false,
  }) {
    return {
      'ownerUid': patient.ownerUid,
      'fullName': patient.fullName,
      'age': patient.age,
      'dischargeDate': Timestamp.fromDate(patient.dischargeDate),
      'conditionCategory': patient.conditionCategory,
      'mainDepartment': patient.mainDepartment,
      'notes': patient.notes,
      'emergencyContact': {
        'name': patient.emergencyContact.name,
        'relationship': patient.emergencyContact.relationship,
        'phone': patient.emergencyContact.phone,
      },
      if (includeSharedWith) 'sharedWith': <String>[],
      'createdAt': Timestamp.fromDate(patient.createdAt),
      'updatedAt': Timestamp.fromDate(patient.updatedAt),
    };
  }

  PatientProfile _patientFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String uid,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final emergency = _map(data['emergencyContact']);
    final now = DateTime.now();
    return PatientProfile(
      id: doc.id,
      ownerUid: data['ownerUid'] as String? ?? uid,
      fullName: data['fullName'] as String? ?? 'Unnamed patient',
      age: _intOrNull(data['age']),
      dischargeDate: _date(data['dischargeDate'], now),
      conditionCategory: data['conditionCategory'] as String? ?? '',
      mainDepartment: data['mainDepartment'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      emergencyContact: EmergencyContact(
        name: emergency['name'] as String? ?? '',
        relationship: emergency['relationship'] as String? ?? '',
        phone: emergency['phone'] as String? ?? '',
      ),
      createdAt: _date(data['createdAt'], now),
      updatedAt: _date(data['updatedAt'], now),
    );
  }

  Map<String, dynamic> _taskToFirestore(CareTask task) {
    return {
      'patientId': task.patientId,
      'title': task.title,
      'details': task.details,
      'type': task.type.name,
      'status': task.status.name,
      'scheduledAt': Timestamp.fromDate(task.scheduledAt),
      'repeatRule': task.repeatRule.name,
      'repeatDurationDays': task.repeatDurationDays,
      'reminderMinutesOfDay': task.reminderMinutesOfDay,
      'remindMinutesBefore': task.remindMinutesBefore,
      'assigneeId': task.assigneeId,
      'assigneeName': task.assigneeName,
      'sourceLabel': task.sourceLabel,
      'sourceImageUrl': task.sourceImageUrl,
      'completedAt': task.completedAt == null
          ? null
          : Timestamp.fromDate(task.completedAt!),
      'createdAt': Timestamp.fromDate(task.createdAt),
      'updatedAt': Timestamp.fromDate(task.updatedAt),
    };
  }

  CareTask _taskFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String patientId,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final now = DateTime.now();
    final scheduledAt = _date(data['scheduledAt'], now);
    return CareTask(
      id: doc.id,
      patientId: data['patientId'] as String? ?? patientId,
      title: data['title'] as String? ?? 'Untitled task',
      details: data['details'] as String? ?? '',
      type: _enumByName(TaskType.values, data['type'], TaskType.note),
      status:
          _enumByName(TaskStatus.values, data['status'], TaskStatus.pending),
      scheduledAt: scheduledAt,
      repeatRule:
          _enumByName(RepeatRule.values, data['repeatRule'], RepeatRule.none),
      repeatDurationDays: _int(data['repeatDurationDays'], 1),
      reminderMinutesOfDay: _intList(data['reminderMinutesOfDay']),
      remindMinutesBefore: _int(data['remindMinutesBefore'], 0),
      assigneeId: data['assigneeId'] as String?,
      assigneeName: data['assigneeName'] as String? ?? 'Unassigned',
      sourceLabel: data['sourceLabel'] as String?,
      sourceImageUrl: data['sourceImageUrl'] as String?,
      completedAt: _dateOrNull(data['completedAt']),
      createdAt: _date(data['createdAt'], scheduledAt),
      updatedAt: _date(data['updatedAt'], now),
    );
  }

  Map<String, dynamic> _symptomLogToFirestore(SymptomLog log) {
    return {
      'patientId': log.patientId,
      'date': Timestamp.fromDate(log.date),
      'painLevel': log.painLevel,
      'temperatureC': log.temperatureC,
      'notes': log.notes,
      'photoUrls': log.photoUrls,
      'createdAt': Timestamp.fromDate(log.createdAt),
      'updatedAt': Timestamp.fromDate(log.updatedAt),
    };
  }

  SymptomLog _symptomLogFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String patientId,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final now = DateTime.now();
    return SymptomLog(
      id: doc.id,
      patientId: data['patientId'] as String? ?? patientId,
      date: _date(data['date'], now),
      painLevel: _int(data['painLevel'], 0),
      temperatureC: _double(data['temperatureC'], 36.8),
      notes: data['notes'] as String? ?? '',
      photoUrls: _stringList(data['photoUrls']),
      createdAt: _date(data['createdAt'], now),
      updatedAt: _date(data['updatedAt'], now),
    );
  }

  Map<String, dynamic> _familyMemberToFirestore(FamilyMember member) {
    return {
      'userUid': member.userUid,
      'displayName': member.displayName,
      'relationship': member.relationship,
      'role': member.role.name,
      'readOnly': member.readOnly,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  FamilyMember _familyMemberFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String patientId,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return FamilyMember(
      id: doc.id,
      patientId: patientId,
      displayName: data['displayName'] as String? ?? 'Family member',
      relationship: data['relationship'] as String? ?? '',
      role: _enumByName(
        FamilyRole.values,
        data['role'],
        FamilyRole.familyViewer,
      ),
      userUid: data['userUid'] as String?,
      readOnly: data['readOnly'] != false,
    );
  }

  List<OcrCandidate> _uniqueCandidates(Iterable<OcrCandidate> candidates) {
    final seen = <String>{};
    final unique = <OcrCandidate>[];
    for (final candidate in candidates) {
      final key =
          '${candidate.patientId}|${candidate.type.name}|${_normalizeText(candidate.extractedText)}';
      if (seen.add(key)) {
        unique.add(candidate);
      }
    }
    return unique;
  }

  Future<FamilyMember?> _defaultAssigneeFor(PatientProfile patient) async {
    final user = await _currentAppUser();
    final members = await _loadFamilyMembers(patient, user);
    for (final member in members) {
      if (member.role == FamilyRole.primaryCarer) return member;
    }
    for (final member in members) {
      if (member.role == FamilyRole.patient) return member;
    }
    return members.isEmpty ? null : members.first;
  }

  String _titleFromCandidate(OcrCandidate candidate) {
    final parsed =
        _extractTitleFromText(candidate.extractedText, candidate.type);
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
        final take = RegExp(
          r'(?:take|medicine|drug)\s+([A-Za-z][A-Za-z0-9\- ]{2,30})',
          caseSensitive: false,
        ).firstMatch(text);
        if (take != null) return take.group(1)?.trim();
        break;
      case OcrCandidateType.appointment:
        final clinic = RegExp(
          r'(?:appointment|follow[- ]?up)\s+(?:with\s+)?([A-Za-z][A-Za-z .-]{2,40})',
          caseSensitive: false,
        ).firstMatch(text);
        if (clinic != null) return 'Appointment: ${clinic.group(1)!.trim()}';
        break;
      case OcrCandidateType.instruction:
        final verb = RegExp(
          r'^(walk|exercise|stretch|physio)',
          caseSensitive: false,
        ).firstMatch(text);
        if (verb != null) {
          final word = verb.group(1)!;
          return '${word[0].toUpperCase()}${word.substring(1)} plan';
        }
        break;
      case OcrCandidateType.other:
        break;
    }

    final sentence = text.split(RegExp(r'[.;,]')).first.trim();
    if (sentence.length <= 48) return sentence;
    return '${sentence.substring(0, 45)}...';
  }

  RepeatRule _repeatFromCandidate(OcrCandidate candidate) {
    final lower = candidate.extractedText.toLowerCase();
    if (candidate.type == OcrCandidateType.appointment) {
      return RepeatRule.none;
    }
    if (_hasAny(lower, const ['three times daily', '3 times daily', 'tid'])) {
      return RepeatRule.threeTimesDaily;
    }
    if (_hasAny(lower,
        const ['twice daily', 'two times daily', '2 times daily', 'bid'])) {
      return RepeatRule.twiceDaily;
    }
    if (_hasAny(lower, const ['every 3 days', 'every three days'])) {
      return RepeatRule.everyThreeDays;
    }
    if (_hasAny(
        lower, const ['every 2 days', 'every two days', 'every other day'])) {
      return RepeatRule.everyTwoDays;
    }
    if (_hasAny(lower, const ['weekly', 'every week', 'next week'])) {
      return RepeatRule.weekly;
    }
    if (_hasAny(lower,
        const ['daily', 'every morning', 'every evening', 'every night'])) {
      return RepeatRule.daily;
    }
    return candidate.type == OcrCandidateType.medication
        ? RepeatRule.daily
        : RepeatRule.none;
  }

  int _durationFromCandidate(OcrCandidate candidate, RepeatRule repeatRule) {
    if (!repeatRule.isRepeating) {
      return 1;
    }
    final match = RegExp(r'\bfor\s+(\d{1,2})\s+days?\b', caseSensitive: false)
        .firstMatch(candidate.extractedText);
    if (match != null) {
      return int.parse(match.group(1)!).clamp(1, 30).toInt();
    }
    if (repeatRule == RepeatRule.weekly) {
      return 30;
    }
    return candidate.type == OcrCandidateType.medication ? 7 : 14;
  }

  List<int> _timesFromCandidate(
    OcrCandidate candidate,
    RepeatRule repeatRule,
    DateTime scheduledAt,
  ) {
    if (!repeatRule.isMultiDaily) {
      return const [];
    }
    final first = scheduledAt.hour * 60 + scheduledAt.minute;
    switch (repeatRule) {
      case RepeatRule.twiceDaily:
        return [first, _addHours(first, 9)];
      case RepeatRule.threeTimesDaily:
        return [first, _addHours(first, 5), _addHours(first, 10)];
      case RepeatRule.none:
      case RepeatRule.daily:
      case RepeatRule.everyTwoDays:
      case RepeatRule.everyThreeDays:
      case RepeatRule.weekly:
        return const [];
    }
  }

  TaskType _typeFromCandidate(OcrCandidateType type) {
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

  String _taskFingerprint(CareTask task) {
    final normalizedDetails = _normalizeText(task.details);
    final normalizedTitle = _normalizeText(task.title);
    return [
      task.patientId,
      task.type.name,
      normalizedDetails.isEmpty ? normalizedTitle : normalizedDetails,
    ].join('|');
  }

  String _normalizeText(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  bool _hasAny(String text, List<String> keywords) =>
      keywords.any((keyword) => text.contains(keyword));

  int _addHours(int minutes, int hours) => (minutes + hours * 60) % (24 * 60);

  String _logId(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}'
        '${local.month.toString().padLeft(2, '0')}'
        '${local.day.toString().padLeft(2, '0')}_'
        '${local.hour.toString().padLeft(2, '0')}'
        '${local.minute.toString().padLeft(2, '0')}'
        '${local.second.toString().padLeft(2, '0')}_'
        '${local.microsecond.toString().padLeft(6, '0')}';
  }

  String _safeId(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

  DateTime _date(Object? value, DateTime fallback) =>
      _dateOrNull(value) ?? fallback;

  DateTime? _dateOrNull(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  int _int(Object? value, int fallback) => _intOrNull(value) ?? fallback;

  int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double _double(Object? value, double fallback) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  List<String> _stringList(Object? value) {
    if (value is Iterable) {
      return value
          .whereType<Object>()
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  List<int> _intList(Object? value) {
    if (value is Iterable) {
      return value
          .map(_intOrNull)
          .whereType<int>()
          .where((minute) => minute >= 0 && minute < 24 * 60)
          .toList(growable: false);
    }
    return const [];
  }

  T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
    final name = value?.toString();
    for (final item in values) {
      if (item.name == name) {
        return item;
      }
    }
    return fallback;
  }
}

class _TaskLocation {
  const _TaskLocation({
    required this.patientId,
    required this.ref,
  });

  final String patientId;
  final DocumentReference<Map<String, dynamic>> ref;
}
