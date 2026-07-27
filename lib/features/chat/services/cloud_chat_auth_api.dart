import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_auth_configuration.dart';
import '../models/chat_auth_session.dart';
import 'chat_auth_api.dart';

class CloudChatAuthApi implements ChatAuthApi {
  CloudChatAuthApi({required this.configuration, http.Client? client})
    : _client = client ?? http.Client();

  final ChatAuthConfiguration configuration;
  final http.Client _client;

  @override
  Future<ChatAuthSession> login({
    required String userId,
    required String pin,
  }) => _postSession('v1/auth/login', <String, String>{
    'userId': userId.trim(),
    'pin': pin,
  });

  @override
  Future<ChatAuthSession> refresh({required String refreshToken}) =>
      _postSession('v1/auth/refresh', <String, String>{
        'refreshToken': refreshToken,
      });

  @override
  Future<void> logout({required String refreshToken}) async {
    await _post('v1/auth/logout', <String, String>{
      'refreshToken': refreshToken,
    });
  }

  Future<ChatAuthSession> _postSession(
    String path,
    Map<String, String> body,
  ) async {
    final value = await _post(path, body);
    final session = ChatAuthSession.tryParse(value);
    if (session == null) {
      throw const ChatAuthException(
        'The authentication server returned an invalid response.',
        code: 'invalid_response',
      );
    }
    return session;
  }

  Future<Object?> _post(String path, Map<String, String> body) async {
    final baseUri = configuration.validatedBaseUri;
    if (baseUri == null) {
      throw const ChatAuthException(
        'Secure Chat authentication is not configured.',
        code: 'configuration_missing',
      );
    }
    final uri = baseUri.resolve(path);
    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {
              'content-type': 'application/json',
              'accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(configuration.requestTimeout);
    } on Object {
      throw const ChatAuthException(
        'Unable to reach the secure Chat authentication service.',
        code: 'network_error',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on Object {
      throw const ChatAuthException(
        'The authentication server returned an invalid response.',
        code: 'invalid_response',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final error = decoded is Map ? decoded['error'] : null;
    final errorMap = error is Map ? error : const {};
    final code = errorMap['code'] is String
        ? errorMap['code'] as String
        : 'request_failed';
    final message = errorMap['message'] is String
        ? errorMap['message'] as String
        : 'Secure Chat authentication failed.';
    throw ChatAuthException(
      _safeMessage(message),
      code: code,
      sessionExpired: response.statusCode == 401 && code == 'session_expired',
    );
  }

  String _safeMessage(String value) {
    final clean = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (clean.isEmpty) return 'Secure Chat authentication failed.';
    return clean.substring(0, clean.length > 160 ? 160 : clean.length);
  }

  @override
  void close() => _client.close();
}
