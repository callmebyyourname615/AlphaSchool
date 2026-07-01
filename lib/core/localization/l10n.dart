import 'package:flutter/material.dart';

class L10n {
  static const supportedLocales = <Locale>[Locale('en'), Locale('th')];

  static const _strings = <String, Map<String, String>>{
    'en': {
      'appTitle': 'School App',
      'homeTitle': 'Home',
      'subtitle': 'Premium School System',
      'theme': 'Theme',
      'dark': 'Dark',
      'light': 'Light',
      'language': 'Language',
      'quickActions': 'Quick actions',
      'students': 'Students',
      'announcements': 'Announcements',
      'grades': 'Grades',
      'profile': 'Profile',
    },
    'th': {
      'appTitle': 'แอปโรงเรียน',
      'homeTitle': 'หน้าแรก',
      'subtitle': 'ระบบโรงเรียนพรีเมียม',
      'theme': 'ธีม',
      'dark': 'มืด',
      'light': 'สว่าง',
      'language': 'ภาษา',
      'quickActions': 'เมนูลัด',
      'students': 'นักเรียน',
      'announcements': 'ประกาศ',
      'grades': 'เกรด',
      'profile': 'โปรไฟล์',
    },
  };

  static String t(BuildContext context, String key) {
    final code = Localizations.localeOf(context).languageCode;
    return _strings[code]?[key] ?? _strings['en']![key] ?? key;
  }
}
