import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/care/application/care_store.dart';
import 'features/care/data/demo_care_repository.dart';
import 'features/care/integrations/local_notification_port.dart';
import 'features/care/integrations/local_storage_port.dart';
import 'features/care/integrations/mlkit_ocr_port.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationPort = LocalNotificationPort();
  await notificationPort.initialize();

  final store = CareStore(
    DemoCareRepository(),
    ocrPort: MlKitOcrPort(),
    notificationPort: notificationPort,
    storagePort: LocalStoragePort(),
  )..load();

  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const CareBridgeApp(),
    ),
  );
}
