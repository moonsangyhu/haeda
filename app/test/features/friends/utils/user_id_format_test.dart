import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/friends/utils/user_id_format.dart';

void main() {
  group('parseUserId', () {
    test('returns nickname and discriminator on valid input', () {
      final result = parseUserId('홍길동#43217');
      expect(result, isNotNull);
      expect(result!.nickname, '홍길동');
      expect(result.discriminator, '43217');
    });

    test('returns null when missing #', () {
      expect(parseUserId('홍길동43217'), isNull);
    });

    test('returns null when discriminator is not 5 digits', () {
      expect(parseUserId('홍길동#1234'), isNull);
      expect(parseUserId('홍길동#123456'), isNull);
      expect(parseUserId('홍길동#abcde'), isNull);
    });

    test('returns null when nickname is empty', () {
      expect(parseUserId('#43217'), isNull);
    });

    test('returns null when nickname is too long', () {
      final long = 'a' * 31;
      expect(parseUserId('$long#12345'), isNull);
    });

    test('handles leading/trailing whitespace', () {
      final result = parseUserId('  홍길동#43217  ');
      expect(result, isNotNull);
      expect(result!.nickname, '홍길동');
    });
  });

  group('formatUserId', () {
    test('joins with #', () {
      expect(formatUserId('홍길동', '43217'), '홍길동#43217');
    });
  });
}
