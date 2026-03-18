import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:industrial_service_reports/core/constants.dart';

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Thrown by [SyncService] when the JWT has expired.
///
/// The user can still use the app offline; they just need to log in again
/// before the next sync.
class TokenExpiredException implements Exception {
  const TokenExpiredException();

  @override
  String toString() => 'TokenExpiredException';
}

// ---------------------------------------------------------------------------
// StoredSession
// ---------------------------------------------------------------------------

class StoredSession {
  const StoredSession({
    required this.userId,
    required this.userName,
    required this.email,
    required this.techId,
    required this.role,
  });

  final String userId;
  final String userName;
  final String email;

  /// Technician code (e.g. "T-001").
  final String techId;
  final String role;
}

// ---------------------------------------------------------------------------
// AuthService
// ---------------------------------------------------------------------------

/// Manages JWT lifecycle: login, logout, token retrieval and session restore.
///
/// **Offline-first design:**
/// - [getStoredSession] returns a session even when the token is expired so
///   the technician can keep using the app without connectivity.
/// - [hasValidTokenForSync] is the gating check before any network sync;
///   it returns `false` when the token is expired, prompting re-login.
class AuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserName = 'auth_user_name';
  static const String _keyUserEmail = 'auth_user_email';
  static const String _keyUserCode = 'auth_user_code';
  static const String _keyUserRole = 'auth_user_role';
  static const String _keyTokenExpiry = 'auth_token_expiry'; // ISO-8601 UTC

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// POST /api/auth/login → stores JWT + user data, returns [StoredSession].
  Future<StoredSession> login({
    required String email,
    required String password,
    String baseUrl = kServerBaseUrlDevice,
  }) async {
    final String loginUrl = '$baseUrl/api/auth/login';
    // ignore: avoid_print
    print('[AuthService] POST $loginUrl (email: $email)');
    final http.Response response = await http.post(
      Uri.parse(loginUrl),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'email': email.trim(),
        'password': password,
        'client_type': 'mobile',
      }),
    );

    if (response.statusCode == 401) {
      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['detail'] ?? 'Credenciales incorrectas');
    }
    if (response.statusCode == 403) {
      throw Exception('Usuario desactivado. Contacta a soporte.');
    }
    if (response.statusCode != 200) {
      throw Exception('Error del servidor: ${response.statusCode}');
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final String token = data['access_token'] as String;
    final Map<String, dynamic> user = data['user'] as Map<String, dynamic>;

    final String userId = user['id'] as String;
    final String userName = user['name'] as String;
    final String techId = user['code'] as String? ?? '';
    final String role = user['role'] as String;

    // Decode the exp claim from the JWT payload (no external package needed).
    final String expiryIso = _expiryFromToken(token);

    // Persist token, expiry and user data in one batch.
    await Future.wait(<Future<void>>[
      _storage.write(key: kAuthTokenKey, value: token),
      _storage.write(key: _keyTokenExpiry, value: expiryIso),
      _storage.write(key: _keyUserId, value: userId),
      _storage.write(key: _keyUserName, value: userName),
      _storage.write(key: _keyUserEmail, value: email.trim()),
      _storage.write(key: _keyUserCode, value: techId),
      _storage.write(key: _keyUserRole, value: role),
    ]);

    return StoredSession(
      userId: userId,
      userName: userName,
      email: email.trim(),
      techId: techId,
      role: role,
    );
  }

  /// Delete all stored credentials.
  Future<void> logout() => _storage.deleteAll();

  /// Return the stored JWT string, or null if never logged in.
  Future<String?> getToken() => _storage.read(key: kAuthTokenKey);

  /// True if any user session exists in secure storage — **regardless of
  /// token expiry**.  Used by the router to decide whether to show the login
  /// screen on app start; the technician must be able to open the app offline
  /// even when the token has expired.
  Future<bool> isLoggedIn() async {
    final String? userId = await _storage.read(key: _keyUserId);
    return userId != null && userId.isNotEmpty;
  }

  /// True if the stored JWT exists **and has not expired locally**.
  ///
  /// Expiry is evaluated against the device clock without any network call.
  /// Call this before attempting a sync to decide whether to prompt re-login.
  Future<bool> hasValidTokenForSync() async {
    final String? token = await getToken();
    if (token == null || token.isEmpty) return false;
    return !(await _isTokenExpiredLocally());
  }

  /// Restore the session from secure storage (used on app startup).
  ///
  /// Returns a [StoredSession] even when the token is expired so the app
  /// can be used offline.  Returns null only when no user data is stored at
  /// all (first install or after an explicit logout).
  Future<StoredSession?> getStoredSession() async {
    final String? userId = await _storage.read(key: _keyUserId);
    if (userId == null || userId.isEmpty) return null;

    final String? userName = await _storage.read(key: _keyUserName);
    final String? email = await _storage.read(key: _keyUserEmail);
    final String? techId = await _storage.read(key: _keyUserCode);
    final String? role = await _storage.read(key: _keyUserRole);

    if (userName == null || email == null) return null;

    return StoredSession(
      userId: userId,
      userName: userName,
      email: email,
      techId: techId ?? '',
      role: role ?? 'technician',
    );
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Check the locally stored expiry date against the device clock.
  Future<bool> _isTokenExpiredLocally() async {
    final String? expiryStr = await _storage.read(key: _keyTokenExpiry);
    if (expiryStr == null) return true; // no expiry record → treat as expired
    final DateTime? expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return true;
    return DateTime.now().toUtc().isAfter(expiry);
  }

  /// Decode the `exp` claim from the JWT and return an ISO-8601 UTC string.
  ///
  /// Uses only `dart:convert` — no extra packages.  Falls back to 7 days
  /// from now if decoding fails (matches the backend mobile token lifetime).
  static String _expiryFromToken(String token) {
    try {
      final List<String> parts = token.split('.');
      if (parts.length != 3) throw FormatException('invalid jwt');

      // Base64url → base64 (add padding as needed).
      String payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
        case 3:
          payload += '=';
      }

      final Map<String, dynamic> claims =
          jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
      final int expUnix = claims['exp'] as int;
      return DateTime.fromMillisecondsSinceEpoch(expUnix * 1000, isUtc: true)
          .toIso8601String();
    } catch (_) {
      // Fallback: 7 days from now
      return DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String();
    }
  }
}
