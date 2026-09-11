import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController {
  static const _prefsKey = 'app_locale_code';
  static const supportedLocales = <Locale>[Locale('en'), Locale('lo')];

  static final ValueNotifier<Locale> notifier = ValueNotifier<Locale>(
    const Locale('lo'),
  );

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    notifier.value = _localeFromCode(code);
  }

  static Future<void> setLocale(Locale locale) async {
    final next = _localeFromCode(locale.languageCode);
    if (notifier.value.languageCode == next.languageCode) return;

    notifier.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, next.languageCode);
  }

  static Locale _localeFromCode(String? code) {
    for (final locale in supportedLocales) {
      if (locale.languageCode == code) return locale;
    }
    return const Locale('lo');
  }
}
