import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';
import 'api_exception.dart';

class MultipartFilePart {
  const MultipartFilePart({
    required this.field,
    required this.bytes,
    required this.filename,
  });

  final String field;
  final Uint8List bytes;
  final String filename;
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 20),
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUri = Uri.parse(baseUrl ?? ApiConfig.baseUrl),
       _timeout = timeout;

  final http.Client _httpClient;
  final Uri _baseUri;
  final Duration _timeout;

  Future<dynamic> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      'GET',
      path,
      headers: headers,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> post(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) {
    return _send(
      'POST',
      path,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
    );
  }

  Future<dynamic> put(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) {
    return _send(
      'PUT',
      path,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
    );
  }

  Future<dynamic> patch(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) {
    return _send(
      'PATCH',
      path,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
    );
  }

  Future<dynamic> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) {
    return _send(
      'DELETE',
      path,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
    );
  }

  Future<dynamic> multipartPost(
    String path, {
    required Map<String, String> fields,
    Uint8List? fileBytes,
    String? fileName,
    String fileField = 'file',
    List<MultipartFilePart> files = const [],
    Map<String, String>? headers,
  }) async {
    final request = http.MultipartRequest('POST', _buildUri(path, null));
    request.headers.addAll({'Accept': 'application/json', ...?headers});
    request.fields.addAll(fields);
    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName ?? 'homework-upload.jpg',
          contentType: _contentTypeForFilename(fileName),
        ),
      );
    }
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          file.field,
          file.bytes,
          filename: file.filename,
          contentType: _contentTypeForFilename(file.filename),
        ),
      );
    }

    try {
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _decodeResponse(response);
    } on TimeoutException catch (error) {
      throw ApiException('Request timed out', cause: error);
    } on http.ClientException catch (error) {
      throw ApiException('Could not connect to the API', cause: error);
    } on FormatException catch (error) {
      throw ApiException('Invalid response from API', cause: error);
    }
  }

  Future<dynamic> multipartPut(
    String path, {
    required Map<String, String> fields,
    List<MultipartFilePart> files = const [],
    Map<String, String>? headers,
  }) async {
    final request = http.MultipartRequest('PUT', _buildUri(path, null));
    request.headers.addAll({'Accept': 'application/json', ...?headers});
    request.fields.addAll(fields);
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          file.field,
          file.bytes,
          filename: file.filename,
          contentType: _contentTypeForFilename(file.filename),
        ),
      );
    }
    try {
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(_timeout);
      return _decodeResponse(await http.Response.fromStream(streamedResponse));
    } on TimeoutException catch (error) {
      throw ApiException('Request timed out', cause: error);
    } on http.ClientException catch (error) {
      throw ApiException('Could not connect to the API', cause: error);
    } on FormatException catch (error) {
      throw ApiException('Invalid response from API', cause: error);
    }
  }

  void close() => _httpClient.close();

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final request = http.Request(method, uri);

    request.headers.addAll({
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      ...?headers,
    });

    if (body != null) {
      request.body = jsonEncode(body);
    }

    try {
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _decodeResponse(response);
    } on TimeoutException catch (error) {
      throw ApiException('Request timed out', cause: error);
    } on http.ClientException catch (error) {
      throw ApiException('Could not connect to the API', cause: error);
    } on FormatException catch (error) {
      throw ApiException('Invalid response from API', cause: error);
    }
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path
        : '${_baseUri.path}/';

    return _baseUri.replace(
      path: '$basePath$normalizedPath',
      queryParameters: {
        ..._baseUri.queryParameters,
        for (final entry in (queryParameters ?? {}).entries)
          if (entry.value != null) entry.key: entry.value.toString(),
      },
    );
  }

  MediaType _contentTypeForFilename(String? filename) {
    final extension = (filename?.split('.').last ?? '').toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'gif':
        return MediaType('image', 'gif');
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'webm':
        return MediaType('video', 'webm');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  dynamic _decodeResponse(http.Response response) {
    final body = response.body.trim();
    final decoded = body.isEmpty ? null : jsonDecode(body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ApiException(
      _errorMessage(decoded) ?? 'API request failed',
      statusCode: response.statusCode,
      body: decoded,
    );
  }

  String? _errorMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'] ?? decoded['error'];
      return message?.toString();
    }
    return null;
  }
}
