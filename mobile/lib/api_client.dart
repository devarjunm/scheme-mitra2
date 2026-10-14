import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

const String _compileTimeApiBase = String.fromEnvironment('API_BASE_URL');
const String _tokenStorageKey = 'scheme_mitra_mobile_access_token';
const String _languageStorageKey = 'scheme_mitra_ui_language';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({Future<void> Function()? onSessionExpired})
      : _onSessionExpired = onSessionExpired,
        _storage = const FlutterSecureStorage() {
    _baseUrl = _validateBaseUrl(_compileTimeApiBase);
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl ?? 'https://configuration-required.invalid',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenStorageKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['X-Request-ID'] = _requestId();
        handler.next(options);
      },
      onError: (error, handler) async {
        final path = error.requestOptions.path;
        final isAuthExchange = path.endsWith('/auth/mobile/login') ||
            path.endsWith('/auth/mobile/register') ||
            path.endsWith('/auth/mobile/demo');
        if (error.response?.statusCode == 401 && !isAuthExchange) {
          await clearToken();
          await _onSessionExpired?.call();
        }
        handler.next(error);
      },
    ));
  }

  final FlutterSecureStorage _storage;
  final Future<void> Function()? _onSessionExpired;
  late final Dio _dio;
  late final String? _baseUrl;

  String? get baseUrl => _baseUrl;

  String? get configurationError {
    if (_baseUrl != null) return null;
    if (_compileTimeApiBase.trim().isEmpty) {
      return 'Set API_BASE_URL at build time. Release builds require the production HTTPS API origin.';
    }
    return 'API_BASE_URL is invalid. Use the HTTPS origin of the deployed Scheme Mitra API.';
  }

  static String? _validateBaseUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    if ((uri.path.isNotEmpty && uri.path != '/') || uri.query.isNotEmpty || uri.fragment.isNotEmpty) return null;
    final host = uri.host.toLowerCase();
    final looksLocal = host == '127.0.0.1' || host == '::1' || host == '0.0.0.0' ||
        host == '10.0.2.2' || host.endsWith('.local') || !host.contains('.');
    if (kReleaseMode) {
      if (uri.scheme != 'https' || looksLocal) return null;
    } else if (uri.scheme == 'https') {
      // HTTPS is preferred for all non-emulator builds.
    } else if (uri.scheme == 'http' && host == '10.0.2.2') {
      // Android emulator debug only; never accepted by a release build.
    } else {
      return null;
    }
    final normalizedPath = uri.path == '/' ? '' : uri.path;
    return uri.replace(path: normalizedPath, query: null, fragment: null).toString().replaceFirst(RegExp(r'/$'), '');
  }

  static String _requestId() => '${DateTime.now().microsecondsSinceEpoch}-${UniqueKey().hashCode}';

  void _requireConfigured() {
    if (configurationError != null) throw ApiException(configurationError!);
  }

  Future<void> saveToken(String token) => _storage.write(key: _tokenStorageKey, value: token);
  Future<String?> readToken() => _storage.read(key: _tokenStorageKey);
  Future<void> clearToken() => _storage.delete(key: _tokenStorageKey);
  Future<String?> readUiLanguage() => _storage.read(key: _languageStorageKey);
  Future<void> saveUiLanguage(String language) => _storage.write(key: _languageStorageKey, value: language);

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    _requireConfigured();
    try {
      final response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return <String, dynamic>{};
    } on DioException catch (error) {
      final response = error.response;
      final data = response?.data;
      var message = 'Could not connect. Check your connection and try again.';
      if (data is Map) {
        final nested = data['error'];
        if (nested is Map && nested['message'] is String) {
          message = nested['message'] as String;
        } else if (data['detail'] is String) {
          message = data['detail'] as String;
        }
      } else if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        message = 'The request timed out. Please retry.';
      }
      throw ApiException(message, statusCode: response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> getMap(String path, {Map<String, dynamic>? query}) =>
      _request(path, query: query);

  Future<Map<String, dynamic>> postMap(String path, {Object? body}) =>
      _request(path, method: 'POST', body: body);

  Future<Map<String, dynamic>> putMap(String path, {Object? body}) =>
      _request(path, method: 'PUT', body: body);

  Future<Map<String, dynamic>> patchMap(String path, {Object? body}) =>
      _request(path, method: 'PATCH', body: body);

  Future<Map<String, dynamic>> deleteMap(String path, {Object? body}) =>
      _request(path, method: 'DELETE', body: body);

  Future<AuthReply> login(String email, String password) async {
    final result = await postMap('/api/v1/auth/mobile/login', body: {'email': email, 'password': password});
    final reply = AuthReply.fromJson(result);
    await saveToken(reply.accessToken);
    return reply;
  }

  Future<AuthReply> register({
    required String fullName,
    required String email,
    required String password,
    required String district,
    required String taluka,
  }) async {
    final result = await postMap('/api/v1/auth/mobile/register', body: {
      'full_name': fullName,
      'email': email,
      'password': password,
      'state': 'Maharashtra',
      'district': district,
      'taluka': taluka,
    });
    final reply = AuthReply.fromJson(result);
    await saveToken(reply.accessToken);
    return reply;
  }

  Future<AuthReply> openDemo() async {
    final result = await postMap('/api/v1/auth/mobile/demo', body: {});
    final reply = AuthReply.fromJson(result);
    await saveToken(reply.accessToken);
    return reply;
  }

  Future<Map<String, dynamic>> currentUser() => getMap('/api/v1/auth/me');

  Future<void> logout() async {
    try {
      await postMap('/api/v1/auth/mobile/logout', body: {});
    } finally {
      await clearToken();
    }
  }

  Future<Map<String, dynamic>> readProfile() => getMap('/api/v1/profile');
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profile) =>
      putMap('/api/v1/profile', body: profile);

  Future<List<SchemeRecord>> listSchemes({String query = '', String category = ''}) async {
    final result = await getMap('/api/v1/schemes', query: {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (category.isNotEmpty) 'category': category,
    });
    final rows = result['schemes'];
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((row) => SchemeRecord.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<List<SchemeRecord>> listSaved() async {
    final result = await getMap('/api/v1/saved');
    final rows = result['saved'];
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((row) => SchemeRecord.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<SchemeRecord> readScheme(String slug) async {
    final result = await getMap('/api/v1/schemes/${Uri.encodeComponent(slug)}');
    final scheme = Map<String, dynamic>.from(result['scheme'] as Map);
    scheme['evaluation'] = result['evaluation'];
    scheme['saved'] = result['saved'];
    return SchemeRecord.fromJson(scheme);
  }

  Future<void> saveScheme(String slug, {required bool save}) async {
    final safeSlug = Uri.encodeComponent(slug);
    if (save) {
      await postMap('/api/v1/saved/$safeSlug', body: {});
    } else {
      await deleteMap('/api/v1/saved/$safeSlug');
    }
  }

  Future<List<Map<String, dynamic>>> listApplications() async {
    final result = await getMap('/api/v1/applications');
    final rows = result['applications'];
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> createApplication(Map<String, dynamic> values) =>
      postMap('/api/v1/applications', body: values);

  Future<Map<String, dynamic>> deleteAccount({required String password}) =>
      deleteMap('/api/v1/account', body: {'password': password, 'confirmation': 'DELETE'});
}
