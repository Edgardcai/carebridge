import '../domain/models.dart';

abstract class CareRepository {
  Future<CareBundle> load();

  Future<AppUser> signInDemo({
    required String email,
    required String displayName,
    String? password,
    bool createAccount = false,
  });

  Future<void> signOut();

  Future<PatientProfile> upsertPatient(PatientProfile patient);

  Future<void> selectPatient(String patientId);

  Future<CareTask> upsertTask(CareTask task);

  Future<void> deleteTask(String taskId);

  Future<CareTask> markTaskStatus(String taskId, TaskStatus status);

  Future<SymptomLog> upsertSymptomLog(SymptomLog log);

  Future<List<CareTask>> createTasksFromOcrCandidates(
    List<OcrCandidate> candidates,
  );
}
