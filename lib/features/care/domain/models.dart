enum TaskType { medication, visit, rehab, note }

enum TaskStatus { pending, completed, missed }

enum RepeatRule { none, daily, weekly }

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
      case RepeatRule.weekly:
        return 'Weekly';
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
    final start = DateTime(dischargeDate.year, dischargeDate.month, dischargeDate.day);
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

  CareTask copyWith({
    String? id,
    String? patientId,
    String? title,
    String? details,
    TaskType? type,
    TaskStatus? status,
    DateTime? scheduledAt,
    RepeatRule? repeatRule,
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
    this.selected = true,
  });

  final String id;
  final String patientId;
  final OcrCandidateType type;
  final String extractedText;
  final double confidence;
  final DateTime? scheduledAt;
  final bool selected;

  OcrCandidate copyWith({
    String? id,
    String? patientId,
    OcrCandidateType? type,
    String? extractedText,
    double? confidence,
    DateTime? scheduledAt,
    bool? selected,
  }) {
    return OcrCandidate(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      type: type ?? this.type,
      extractedText: extractedText ?? this.extractedText,
      confidence: confidence ?? this.confidence,
      scheduledAt: scheduledAt ?? this.scheduledAt,
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
