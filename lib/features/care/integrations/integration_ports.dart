import '../domain/models.dart';

/// Role B implements these ports with Firebase Auth, Firestore, and Storage.
abstract class AuthPort {
  Future<AppUser?> currentUser();

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();
}

abstract class PatientDataPort {
  Stream<List<PatientProfile>> watchPatientsForUser(String uid);

  Future<PatientProfile> savePatient(PatientProfile patient);

  Future<void> deletePatient(String patientId);
}

abstract class TaskDataPort {
  Stream<List<CareTask>> watchTasks(String patientId);

  Future<CareTask> saveTask(CareTask task);

  Future<void> deleteTask(String taskId);

  Future<CareTask> markTaskStatus(String taskId, TaskStatus status);
}

abstract class SymptomDataPort {
  Stream<List<SymptomLog>> watchLogs(String patientId);

  Future<SymptomLog> saveLog(SymptomLog log);
}

abstract class FamilyDataPort {
  Stream<List<FamilyMember>> watchFamilyMembers(String patientId);

  Future<void> inviteFamilyMember({
    required String patientId,
    required String email,
    required FamilyRole role,
  });
}

abstract class StoragePort {
  Future<String> uploadDischargeImage({
    required String patientId,
    required String localPath,
  });

  Future<String> uploadSymptomPhoto({
    required String patientId,
    required DateTime logDate,
    required String localPath,
  });
}

/// Role C implements ML Kit OCR behind this port.
abstract class OcrPort {
  Future<List<OcrCandidate>> extractTaskCandidates({
    required String patientId,
    required String localImagePath,
  });
}

/// Role C implements flutter_local_notifications behind this port.
abstract class NotificationPort {
  Future<void> requestPermission();

  Future<void> scheduleTaskReminder(CareTask task);

  Future<void> cancelTaskReminder(String taskId);

  Future<void> rescheduleAll(List<CareTask> tasks);
}

abstract class DisposableIntegration {
  Future<void> disposeIntegration();
}
