import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/core/constants/emoji_presets.dart';

void main() {
  group('resolvePresets', () {
    test('null 또는 빈 카테고리 → universal preset 반환', () {
      expect(resolvePresets(null), kEmojiPresets);
      expect(resolvePresets(''), kEmojiPresets);
      expect(resolvePresets('   '), kEmojiPresets);
    });

    test('exact 매핑 키 → 해당 카테고리 preset', () {
      final presets = resolvePresets('운동');
      expect(presets, contains('💪'));
      expect(presets, contains('🏃'));
      expect(presets.length, kEmojiPresetCount);
    });

    test('공부 / 독서 / 학습 모두 study preset 으로 분기', () {
      final study = resolvePresets('공부');
      expect(study, contains('📚'));
      expect(resolvePresets('독서'), contains('📚'));
      expect(resolvePresets('학습'), contains('📚'));
    });

    test('부분 일치 → 첫 매칭 preset 반환', () {
      // '아침 운동' 같은 자유 입력
      final partial = resolvePresets('아침 운동');
      expect(partial, contains('💪'));
    });

    test('매핑에 없는 카테고리 → universal fallback', () {
      final unknown = resolvePresets('완전히낯선카테고리');
      expect(unknown, kEmojiPresets);
    });

    test('모든 preset 그룹은 동일 개수 (kEmojiPresetCount)', () {
      for (final entry in kEmojiPresetsByCategory.entries) {
        expect(
          entry.value.length,
          kEmojiPresetCount,
          reason: '${entry.key} preset 길이 mismatch',
        );
      }
      expect(kEmojiPresets.length, kEmojiPresetCount);
    });
  });
}
