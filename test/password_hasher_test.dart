import 'package:flutter_test/flutter_test.dart';
import 'package:unimate/core/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    test('never returns the clear-text password', () {
      const password = 'sup3rsecret';
      final salt = PasswordHasher.newSalt();
      final hash = PasswordHasher.hash(password, salt);

      expect(hash, isNot(contains(password)));
      expect(hash.length, 64); // sha256 hex digest
    });

    test('salts are unique per account', () {
      final salts = List.generate(50, (_) => PasswordHasher.newSalt());
      expect(salts.toSet().length, 50);
    });

    test('the same password hashes differently under different salts', () {
      const password = 'repeat-me';
      final a = PasswordHasher.hash(password, PasswordHasher.newSalt());
      final b = PasswordHasher.hash(password, PasswordHasher.newSalt());
      expect(a, isNot(b));
    });

    test('verify accepts the right password and rejects wrong ones', () {
      const password = 'correct horse';
      final salt = PasswordHasher.newSalt();
      final hash = PasswordHasher.hash(password, salt);

      expect(
        PasswordHasher.verify(
          password: password,
          salt: salt,
          expectedHash: hash,
        ),
        isTrue,
      );
      expect(
        PasswordHasher.verify(
          password: 'wrong horse',
          salt: salt,
          expectedHash: hash,
        ),
        isFalse,
      );
      expect(
        PasswordHasher.verify(
          password: password,
          salt: PasswordHasher.newSalt(),
          expectedHash: hash,
        ),
        isFalse,
      );
    });

    test('verify handles an empty stored hash', () {
      expect(
        PasswordHasher.verify(password: 'x', salt: '', expectedHash: ''),
        isFalse,
      );
    });
  });
}
