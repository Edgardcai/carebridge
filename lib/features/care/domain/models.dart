enum TaskType { medication, visit, rehab, note }

enum TaskStatus { pending, completed, missed }

enum RepeatRule {
  none,
  daily,
  everyTwoDays,
  everyThreeDays,
  weekly,
  twiceDaily,
  threeTimesDaily,
}

enum FamilyRole { patient, primaryCarer, familyViewer }

enum OcrCandidateType { medication, appointment, instruction, other }

extension TaskTypeLabel on TaskType {
  String get label {
    switch (this) {
      case TaskType.medication:
        return 'Meds';
      case TaskType.visit:
        return 'Visit';
      case TaskType.rehab:
        return 'Rehab';
      case TaskType.note:
        return 'Note';
    }
  }
}

extension TaskStatusLabel on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.missed:
        return 'Missed';
    }
  }
}

extension RepeatRuleLabel on RepeatRule {
  String get label {
    switch (this) {
      case RepeatRule.none:
        return 'None';
      case RepeatRule.daily:
        return 'Daily';
      case RepeatRule.everyTwoDays:
        return 'Every 2 days';
      case RepeatRule.everyThreeDays:
        return 'Every 3 days';
      case RepeatRule.weekly:
        return 'Weekly';
      case RepeatRule.twiceDaily:
        return 'Twice daily';
      case RepeatRule.threeTimesDaily:
        return 'Three times daily';
    }
  }

  bool get isRepeating => this != RepeatRule.none;

  bool get isMultiDaily =>
      this == RepeatRule.twiceDaily || this == RepeatRule.threeTimesDaily;

  int get dayInterval {
    switch (this) {
      case RepeatRule.none:
      case RepeatRule.daily:
      case RepeatRule.twiceDaily:
      case RepeatRule.threeTimesDaily:
        return 1;
      case RepeatRule.everyTwoDays:
        return 2;
      case RepeatRule.everyThreeDays:
        return 3;
      case RepeatRule.weekly:
        return 7;
    }
  }

  int get timesPerActiveDay {
    switch (this) {
      case RepeatRule.twiceDaily:
        return 2;
      case RepeatRule.threeTimesDaily:
        return 3;
      case RepeatRule.none:
      case RepeatRule.daily:
      case RepeatRule.everyTwoDays:
      case RepeatRule.everyThreeDays:
      case RepeatRule.weekly:
        return 1;
    }
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.isDemo = true,
  });

  final String uid;
  final String email;
  final String displayName;
  final bool isDemo;

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    bool? isDemo,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isDemo: isDemo ?? this.isDemo,
    );
  }
}

class EmergencyContact {
  const EmergencyContact({
    this.name = '',
    this.relationship = '',
    this.phone = '',
  });

  final String name;
  final String relationship;
  final String phone;

  EmergencyContact copyWith({
    String? name,
    String? relationship,
    String? phone,
  }) {
    return EmergencyContact(
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
    );
  }
}

class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.ownerUid,
    required this.fullName,
    required this.dischargeDate,
    this.age,
    this.conditionCategory = '',
    this.mainDepartment = '',
    this.notes = '',
    this.emergencyContact = const EmergencyContact(),
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerUid;
  final String fullName;
  final int? age;
  final DateTime dischargeDate;
  final String conditionCategory;
  final String mainDepartment;
  final String notes;
  final EmergencyContact emergencyContact;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  int daySinceDischarge(DateTime now) {
    final start =
        DateTime(dischargeDate.year, dischargeDate.month, dischargeDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays + 1;
  }

  PatientProfile copyWith({
    String? id,
    String? ownerUid,
    String? fullName,
    int? age,
    DateTime? dischargeDate,
    String? conditionCategory,
    String? mainDepartment,
    String? notes,
    EmergencyContact? emergencyContact,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientProfile(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      dischargeDate: dischargeDate ?? this.dischargeDate,
      conditionCategory: conditionCategory ?? this.conditionCategory,
      mainDepartment: mainDepartment ?? this.mainDepartment,
      notes: notes ?? this.notes,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.patientId,
    required this.displayName,
    required this.relationship,
    required this.role,
    this.userUid,
    this.readOnly = true,
  });

  final String id;
  final String patientId;
  final String displayName;
  final String relationship;
  final FamilyRole role;
  final String? userUid;
  final bool readOnly;
}

class CareTask {
  const CareTask({
    required this.id,
    required this.patientId,
    required this.title,
    required this.type,
    required this.status,
    required this.scheduledAt,
    required this.createdAt,
    required this.updatedAt,
    this.details = '',
    this.repeatRule = RepeatRule.none,
    this.repeatDurationDays = 1,
    this.reminderMinutesOfDay = const [],
    this.remindMinutesBefore = 0,
    this.assigneeId,
    this.assigneeName = 'Unassigned',
    this.sourceLabel,
    this.sourceImageUrl,
    this.completedAt,
  });

  final String id;
  final String patientId;
  final String title;
  final String details;
  final TaskType type;
  final TaskStatus status;
  final DateTime scheduledAt;
  final RepeatRule repeatRule;
  final int repeatDurationDays;
  final List<int> reminderMinutesOfDay;
  final int remindMinutesBefore;
  final String? assigneeId;
  final String assigneeName;
  final String? sourceLabel;
  final String? sourceImageUrl;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isOnDate(DateTime date) {
    return scheduledAt.year == date.year &&
        scheduledAt.month == date.month &&
        scheduledAt.day == date.day;
  }

  int get normalizedRepeatDurationDays {
    if (!repeatRule.isRepeating) {
      return 1;
    }
    return repeatDurationDays < 1 ? 1 : repeatDurationDays;
  }

  List<int> get normalizedReminderMinutesOfDay {
    final base = scheduledAt.hour * 60 + scheduledAt.minute;
    final requiredCount = repeatRule.timesPerActiveDay;
    final values = <int>[
      base,
      ...reminderMinutesOfDay,
    ].where((minute) => minute >= 0 && minute < 24 * 60).toSet().toList()
      ..sort();

    if (values.length >= requiredCount) {
      return values.take(requiredCount).toList(growable: false);
    }

    final fallback = <int>{...values};
    while (fallback.length < requiredCount) {
      final next =
          (base + fallback.length * (12 * 60 ~/ requiredCount)) % (24 * 60);
      fallback.add(next);
    }
    final normalized = fallback.toList()..sort();
    return normalized.take(requiredCount).toList(growable: false);
  }

  CareTask copyWith({
    String? id,
    String? patientId,
    String? title,
    String? details,
    TaskType? type,
    TaskStatus? status,
    DateTime? scheduledAt,
    RepeatRule? repeatRule,
    int? repeatDurationDays,
    List<int>? reminderMinutesOfDay,
    int? remindMinutesBefore,
    String? assigneeId,
    String? assigneeName,
    String? sourceLabel,
    String? sourceImageUrl,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCompletedAt = false,
  }) {
    return CareTask(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      details: details ?? this.details,
      type: type ?? this.type,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      repeatRule: repeatRule ?? this.repeatRule,
      repeatDurationDays: repeatDurationDays ?? this.repeatDurationDays,
      reminderMinutesOfDay: reminderMinutesOfDay ?? this.reminderMinutesOfDay,
      remindMinutesBefore: remindMinutesBefore ?? this.remindMinutesBefore,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      sourceImageUrl: sourceImageUrl ?? this.sourceImageUrl,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SymptomLog {
  const SymptomLog({
    required this.id,
    required this.patientId,
    required this.date,
    required this.painLevel,
    required this.temperatureC,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.photoUrls = const [],
  });

  final String id;
  final String patientId;
  final DateTime date;
  final int painLevel;
  final double temperatureC;
  final String notes;
  final List<String> photoUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  SymptomLog copyWith({
    String? id,
    String? patientId,
    DateTime? date,
    int? painLevel,
    double? temperatureC,
    String? notes,
    List<String>? photoUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SymptomLog(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      date: date ?? this.date,
      painLevel: painLevel ?? this.painLevel,
      temperatureC: temperatureC ?? this.temperatureC,
      notes: notes ?? this.notes,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class OcrCandidate {
  const OcrCandidate({
    required this.id,
    required this.patientId,
    required this.type,
    required this.extractedText,
    required this.confidence,
    this.scheduledAt,
    this.sourceImageUrl,
    this.selected = true,
  });

  final String id;
  final String patientId;
  final OcrCandidateType type;
  final String extractedText;
  final double confidence;
  final DateTime? scheduledAt;
  final String? sourceImageUrl;
  final bool selected;

  OcrCandidate copyWith({
    String? id,
    String? patientId,
    OcrCandidateType? type,
    String? extractedText,
    double? confidence,
    DateTime? scheduledAt,
    String? sourceImageUrl,
    bool? selected,
  }) {
    return OcrCandidate(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      type: type ?? this.type,
      extractedText: extractedText ?? this.extractedText,
      confidence: confidence ?? this.confidence,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      sourceImageUrl: sourceImageUrl ?? this.sourceImageUrl,
      selected: selected ?? this.selected,
    );
  }
}

class CareBundle {
  const CareBundle({
    required this.user,
    required this.patients,
    required this.tasks,
    required this.symptomLogs,
    required this.familyMembers,
    required this.ocrCandidates,
  });

  final AppUser? user;
  final List<PatientProfile> patients;
  final List<CareTask> tasks;
  final List<SymptomLog> symptomLogs;
  final List<FamilyMember> familyMembers;
  final List<OcrCandidate> ocrCandidates;

  CareBundle copyWith({
    AppUser? user,
    bool clearUser = false,
    List<PatientProfile>? patients,
    List<CareTask>? tasks,
    List<SymptomLog>? symptomLogs,
    List<FamilyMember>? familyMembers,
    List<OcrCandidate>? ocrCandidates,
  }) {
    return CareBundle(
      user: clearUser ? null : user ?? this.user,
      patients: patients ?? this.patients,
      tasks: tasks ?? this.tasks,
      symptomLogs: symptomLogs ?? this.symptomLogs,
      familyMembers: familyMembers ?? this.familyMembers,
      ocrCandidates: ocrCandidates ?? this.ocrCandidates,
    );
  }
}
