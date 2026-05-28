import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  ApiConfig._();

  static const String _apiBaseUrlKey = 'API_BASE_URL';

  static String get baseUrl {
    final value = dotenv.env[_apiBaseUrlKey]?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('Missing $_apiBaseUrlKey in .env');
    }
    return value;
  }
}
