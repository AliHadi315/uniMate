import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/user_storage.dart';

class AuthUser {
  final int id;
  final String fullName;
  final String universityName;
  final String universityId;
  final String country;

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.universityName,
    required this.universityId,
    required this.country,
  });

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AuthUser.fromRow(Map<String, Object?> row) => AuthUser(
    id: row['id'] as int,
    fullName: row['fullName'] as String,
    universityName: row['universityName'] as String,
    universityId: row['universityId'] as String,
    country: row['country'] as String,
  );
}

/// Owns the signed-in account and keeps the session across app restarts.
class AuthProvider extends ChangeNotifier {
  static const _sessionKey = 'unimate.session.userId';

  AuthUser? _currentUser;
  bool _restoring = true;

  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// True until the persisted session has been checked, so the UI can show a
  /// splash instead of flashing the login screen.
  bool get isRestoring => _restoring;

  /// Id used to scope every course/task/chat query. -1 when signed out.
  int get userId => _currentUser?.id ?? -1;

  /// Reloads the previously signed-in account, if any.
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(_sessionKey);
      if (id != null) {
        final row = await findUserById(id);
        if (row != null) {
          _currentUser = AuthUser.fromRow(row);
        } else {
          await prefs.remove(_sessionKey);
        }
      }
    } catch (e) {
      debugPrint('Could not restore session: $e');
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<String?> signUp({
    required String fullName,
    required String universityName,
    required String universityId,
    required String password,
    required String country,
  }) async {
    if (fullName.trim().isEmpty ||
        universityName.trim().isEmpty ||
        universityId.trim().isEmpty ||
        password.isEmpty ||
        country.trim().isEmpty) {
      return 'All fields are required.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    try {
      final result = await insertUser(
        fullName: fullName,
        universityName: universityName,
        universityId: universityId,
        country: country,
        password: password,
      );

      if (!result.ok) return result.error;

      await _setUser(AuthUser.fromRow(result.user!));
      return null;
    } catch (e) {
      return 'Could not create the account: $e';
    }
  }

  Future<String?> login({
    required String universityId,
    required String password,
  }) async {
    if (universityId.trim().isEmpty || password.isEmpty) {
      return 'Enter your University ID and password.';
    }

    try {
      final row = await findUserByCredentials(
        universityId: universityId,
        password: password,
      );
      if (row == null) return 'Invalid University ID or password.';

      await _setUser(AuthUser.fromRow(row));
      return null;
    } catch (e) {
      return 'Could not sign in: $e';
    }
  }

  /// Saves profile edits and refreshes the in-memory user.
  Future<String?> updateProfile({
    required String fullName,
    required String universityName,
    required String country,
  }) async {
    final user = _currentUser;
    if (user == null) return 'You are not signed in.';
    if (fullName.trim().isEmpty ||
        universityName.trim().isEmpty ||
        country.trim().isEmpty) {
      return 'All fields are required.';
    }

    try {
      await updateUserProfile(
        id: user.id,
        fullName: fullName,
        universityName: universityName,
        country: country,
      );
      _currentUser = AuthUser(
        id: user.id,
        fullName: fullName.trim(),
        universityName: universityName.trim(),
        universityId: user.universityId,
        country: country.trim(),
      );
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not save the profile: $e';
    }
  }

  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _currentUser;
    if (user == null) return 'You are not signed in.';
    if (newPassword.length < 6) {
      return 'New password must be at least 6 characters.';
    }

    return changePassword(
      id: user.id,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> logout() async {
    _currentUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (e) {
      debugPrint('Could not clear session: $e');
    }
    notifyListeners();
  }

  Future<void> _setUser(AuthUser user) async {
    _currentUser = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sessionKey, user.id);
    } catch (e) {
      debugPrint('Could not persist session: $e');
    }
    notifyListeners();
  }
}
