import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'integration_ports.dart';

class FirebaseStoragePort implements StoragePort {
  FirebaseStoragePort({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadDischargeImage({
    required String patientId,
    required String localPath,
  }) {
    final id = DateTime.now().toUtc().microsecondsSinceEpoch;
    return _uploadImage(
      localPath: localPath,
      storagePath: 'patients/$patientId/discharge_scans/$id.jpg',
    );
  }

  @override
  Future<String> uploadSymptomPhoto({
    required String patientId,
    required DateTime logDate,
    required String localPath,
  }) {
    final day = _dayKey(logDate);
    final id = DateTime.now().toUtc().microsecondsSinceEpoch;
    return _uploadImage(
      localPath: localPath,
      storagePath: 'patients/$patientId/symptom_photos/$day/$id.jpg',
    );
  }

  Future<String> _uploadImage({
    required String localPath,
    required String storagePath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Photo file not found: $localPath');
    }
    final ref = _storage.ref(storagePath);
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  String _dayKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}'
        '${local.month.toString().padLeft(2, '0')}'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
