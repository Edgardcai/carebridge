import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/care/application/care_store.dart';
import 'features/care/data/demo_care_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = CareStore(DemoCareRepository())..load();

  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const CareBridgeApp(),
    ),
  );
}
