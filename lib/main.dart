import 'package:alpha_school/features/home/presentation/pages/home_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/localization/app_localizations.dart';
import 'core/localization/app_locale_controller.dart';
import 'core/services/global_alert_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/pages/year_picker_page.dart';
import 'features/home/presentation/pages/task/task_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/config/app.env', isOptional: true);
  await AppLocaleController.init();
  runApp(const CConnectApp());
}

class CConnectApp extends StatelessWidget {
  const CConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocaleController.notifier,
      builder: (context, locale, _) {
        return MaterialApp(
          navigatorKey: GlobalAlert.navigatorKey,
          debugShowCheckedModeBanner: false,

          theme: AppTheme.lightTheme(locale),
          themeMode: ThemeMode.light,

          locale: locale,
          supportedLocales: AppLocaleController.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          routes: {'/homeShell': (_) => const HomeShellPage()},
          onGenerateRoute: (settings) {
            if (settings.name == '/tasks/speech-exercise') {
              final now = DateTime.now();
              final task = settings.arguments is TaskModel
                  ? settings.arguments as TaskModel
                  : TaskModel(
                      id: 'speech-exercise',
                      headerTask: 'Speech Therapy',
                      titleTask: 'Speech Exercise',
                      createdBy: 'Teacher A',
                      createdAt: now.subtract(const Duration(days: 1)),
                      deadline: now.add(const Duration(days: 2)),
                      status: TaskStatus.backlog,
                      mediaType: TaskMediaType.video,
                      mediaUrl:
                          'https://images.unsplash.com/photo-1524253482453-3fed8d2fe12b?auto=format&fit=crop&w=1400&q=80',
                    );
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => TaskDetailPage(task: task),
              );
            }
            return null;
          },

          home: const YearPickerPage(),
        );
      },
    );
  }
}
