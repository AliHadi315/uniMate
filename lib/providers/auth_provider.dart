import 'package:flutter/material.dart';

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

class _StoredUser {
  final AuthUser user;
  final String password;

  _StoredUser(this.user, this.password);
}

class AuthProvider extends ChangeNotifier {
  final Map<String, _StoredUser> _usersByUniId = {};
  AuthUser? _currentUser;

  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  String? signUp({
    required String fullName,
    required String universityName,
    required String universityId,
    required String password,
    required String country,
  }) {
    if (fullName.trim().isEmpty ||
        universityName.trim().isEmpty ||
        universityId.trim().isEmpty ||
        password.isEmpty ||
        country.trim().isEmpty) {
      return 'All fields are required.';
    }

    if (_usersByUniId.containsKey(universityId.trim())) {
      return 'Account with this University ID already exists.';
    }

    final user = AuthUser(
      fullName: fullName.trim(),
      universityName: universityName.trim(),
      universityId: universityId.trim(),
      country: country.trim(),
    );

    _usersByUniId[user.universityId] = _StoredUser(user, password);
    _currentUser = user;
    notifyListeners();
    return null;
  }

  String? login({required String universityId, required String password}) {
    final stored = _usersByUniId[universityId.trim()];
    if (stored == null) return 'No account found for this University ID.';
    if (stored.password != password) return 'Invalid password.';
    _currentUser = stored.user;
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
