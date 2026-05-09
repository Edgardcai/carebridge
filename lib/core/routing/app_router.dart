import 'package:flutter/material.dart';

import '../../features/care/presentation/screens.dart';

class AppRoutes {
  static const splash = '/';
  static const legal = '/onboarding/legal';
  static const auth = '/auth';
  static const patientNew = '/patient/new';
  static const patients = '/patients';
  static const home = '/home';
  static const tasks = '/tasks';
  static const taskDetail = '/tasks/detail';
  static const taskForm = '/tasks/form';
  static const scanReview = '/scan/review';
  static const log = '/log';
  static const timeline = '/log/timeline';
  static const family = '/family';
  static const settings = '/settings';
}

class TaskFormArgs {
  const TaskFormArgs({this.taskId});

  final String? taskId;
}

class AppRouter {
  static Route<void> onGenerateRoute(RouteSettings settings) {
    Widget page;

    switch (settings.name) {
      case AppRoutes.splash:
        page = const SplashScreen();
        break;
      case AppRoutes.legal:
        page = const LegalScreen();
        break;
      case AppRoutes.auth:
        page = const AuthScreen();
        break;
      case AppRoutes.patientNew:
        page = const PatientFormScreen();
        break;
      case AppRoutes.patients:
        page = const CareShell(currentIndex: 0, child: PatientListScreen());
        break;
      case AppRoutes.home:
        page = const CareShell(currentIndex: 0, child: HomeScreen());
        break;
      case AppRoutes.tasks:
        page = const CareShell(currentIndex: 1, child: TasksScreen());
        break;
      case AppRoutes.taskDetail:
        page = TaskDetailScreen(taskId: settings.arguments! as String);
        break;
      case AppRoutes.taskForm:
        final args = settings.arguments is TaskFormArgs
            ? settings.arguments! as TaskFormArgs
            : const TaskFormArgs();
        page = TaskFormScreen(taskId: args.taskId);
        break;
      case AppRoutes.scanReview:
        page = const OcrReviewScreen();
        break;
      case AppRoutes.log:
        page = const CareShell(currentIndex: 2, child: SymptomLogScreen());
        break;
      case AppRoutes.timeline:
        page = const TimelineScreen();
        break;
      case AppRoutes.family:
        page = const CareShell(currentIndex: 3, child: FamilyHubScreen());
        break;
      case AppRoutes.settings:
        page = const CareShell(currentIndex: 0, child: SettingsScreen());
        break;
      default:
        page = const CareShell(currentIndex: 0, child: HomeScreen());
    }

    return MaterialPageRoute<void>(
      builder: (_) => page,
      settings: settings,
    );
  }
}
