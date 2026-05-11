import 'dart:io';

import 'integration_ports.dart';

class LocalStoragePort implements StoragePort {
  @override
  Future<String> uploadDischargeImage({
    required String patientId,
    required String localPath,
  }) async {
    return _ensurePath(localPath);
  }

  @override
  Future<String> uploadSymptomPhoto({
    required String patientId,
    required DateTime logDate,
    required String localPath,
  }) async {
    return _ensurePath(localPath);
  }

  Future<String> _ensurePath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Photo file not found: $path');
    }
    return file.path;
  }
}
