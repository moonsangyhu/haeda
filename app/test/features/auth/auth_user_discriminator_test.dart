import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/auth/models/auth_models.dart';

void main() {
  group('AuthUser discriminator', () {
    test('AuthUser 생성 시 discriminator 필드를 옵션으로 지정할 수 있다', () {
      const user = AuthUser(
        id: 'user-1',
        nickname: '테스터',
        discriminator: '43217',
        isNew: false,
      );
      expect(user.discriminator, '43217');
    });

    test('discriminator 없이 생성 시 null 이다', () {
      const user = AuthUser(
        id: 'user-2',
        nickname: '테스터2',
        isNew: false,
      );
      expect(user.discriminator, isNull);
    });

    test('fromJson 에서 discriminator 필드를 파싱한다', () {
      final json = {
        'id': 'user-3',
        'nickname': '파싱테스터',
        'discriminator': '99999',
        'profile_image_url': null,
        'background_color': null,
        'is_new': false,
      };
      final user = AuthUser.fromJson(json);
      expect(user.discriminator, '99999');
    });

    test('fromJson 에서 discriminator 없으면 null 이다', () {
      final json = {
        'id': 'user-4',
        'nickname': '파싱테스터2',
        'profile_image_url': null,
        'background_color': null,
        'is_new': false,
      };
      final user = AuthUser.fromJson(json);
      expect(user.discriminator, isNull);
    });
  });
}
