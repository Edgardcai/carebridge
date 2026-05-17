import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/care/application/care_store.dart';

class CareBridgeApp extends StatelessWidget {
  const CareBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final largeText = context.watch<CareStore>().largeText;
    return MaterialApp(
      title: 'CareBridge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final baseScale = media.textScaler.scale(1);
        return MediaQuery(
          data: media.copyWith(
            textScaler:
                TextScaler.linear(largeText ? baseScale * 1.18 : baseScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
