import 'package:flutter/material.dart';
import '../db/user_storage.dart';

class AuthUser {
  final String fullName;
  final String universityName;
  final String universityId;
  final String country;

  AuthUser({
    required this.fullName,
    required this.universityName,
    required this.universityId,
    required this.country,
  });
}

class AuthProvider extends ChangeNotifier {
  AuthUser? _currentUser;

  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

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

    final error = await insertUser(
      fullName: fullName,
      universityName: universityName,
      universityId: universityId,
      country: country,
      password: password,
    );

    if (error != null) return error;

    _currentUser = AuthUser(
      fullName: fullName.trim(),
      universityName: universityName.trim(),
      universityId: universityId.trim(),
      country: country.trim(),
    );

    notifyListeners();
    return null;
  }

  Future<String?> login({
    required String universityId,
    required String password,
  }) async {
    final row = await findUserByCredentials(
      universityId: universityId,
      password: password,
    );

    if (row == null) return 'Invalid University ID or password.';

    _currentUser = AuthUser(
      fullName: row['fullName'] as String,
      universityName: row['universityName'] as String,
      universityId: row['universityId'] as String,
      country: row['country'] as String,
    );

    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
