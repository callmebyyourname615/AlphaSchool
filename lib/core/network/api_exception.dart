class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;
  final dynamic body; // raw decoded response body

  const ApiException(this.message, {this.statusCode, this.cause, this.body});

  @override
  String toString() {
    final code = statusCode == null ? '' : ' ($statusCode)';
    return 'ApiException$code: $message';
  }
}
