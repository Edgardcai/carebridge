import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/care/data/care_repository.dart';
import 'features/care/application/care_store.dart';
import 'features/care/data/demo_care_repository.dart';
import 'features/care/data/firebase_care_repository.dart';
import 'features/care/integrations/firebase_storage_port.dart';
import 'features/care/integrations/integration_ports.dart';
import 'features/care/integrations/local_notification_port.dart';
import 'features/care/integrations/local_storage_port.dart';
import 'features/care/integrations/mlkit_ocr_port.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationPort = LocalNotificationPort();
  await notificationPort.initialize();
  final backend = await _initializeBackend();

  final store = CareStore(
    backend.repository,
    ocrPort: MlKitOcrPort(),
    notificationPort: notificationPort,
    storagePort: backend.storagePort,
  )..load();

  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const CareBridgeApp(),
    ),
  );
}

Future<_CareBackend> _initializeBackend() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('CareBridge backend: Firebase enabled.');
    return _CareBackend(
      repository: FirebaseCareRepository(),
      storagePort: FirebaseStoragePort(),
    );
  } catch (error, stackTrace) {
    debugPrint('CareBridge backend: Firebase init failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    debugPrint('CareBridge backend: using demo backend.');
  }

  return _CareBackend(
    repository: DemoCareRepository(),
    storagePort: LocalStoragePort(),
  );
}

class _CareBackend {
  const _CareBackend({
    required this.repository,
    required this.storagePort,
  });

  final CareRepository repository;
  final StoragePort storagePort;
}
