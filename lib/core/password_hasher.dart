import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted SHA-256 password hashing.
///
/// Passwords are never stored in clear text: every account gets its own random
/// salt, and only `sha256(salt + password)` is persisted.
class PasswordHasher {
  const PasswordHasher._();

  static final Random _random = Random.secure();

  /// Generates a new 16-byte salt encoded as base64.
  static String newSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Hashes [password] with [salt] and returns the hex digest.
  static String hash(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  /// Constant-time-ish comparison of a candidate password against a stored hash.
  static bool verify({
    required String password,
    required String salt,
    required String expectedHash,
  }) {
    final candidate = hash(password, salt);
    if (candidate.length != expectedHash.length) return false;

    var mismatch = 0;
    for (var i = 0; i < candidate.length; i++) {
      mismatch |= candidate.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return mismatch == 0;
  }
}
