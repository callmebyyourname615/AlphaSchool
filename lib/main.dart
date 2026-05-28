import 'package:alpha_school/features/home/presentation/pages/home_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/services/global_alert_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/pages/year_picker_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  runApp(const CConnectApp());
}

class CConnectApp extends StatefulWidget {
  const CConnectApp({super.key});

  @override
  State<CConnectApp> createState() => _CConnectAppState();
}

class _CConnectAppState extends State<CConnectApp> {
  Locale _locale = const Locale('en');

  void _toggleTheme() => AppTheme.toggleThemeMode();
  void _setLocale(Locale locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: GlobalAlert.navigatorKey,
          debugShowCheckedModeBanner: false,

          theme: AppTheme.lightTheme(_locale),
          darkTheme: AppTheme.darkTheme(_locale),
          themeMode: mode,

          locale: _locale,
          supportedLocales: const [Locale('en'), Locale('lo'), Locale('th')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          routes: {'/homeShell': (_) => const HomeShellPage()},

          home: YearPickerPage(
            onToggleTheme: _toggleTheme,
            themeMode: mode,
            // onSetLocale: _setLocale,
          ),
        );
      },
    );
  }
}
