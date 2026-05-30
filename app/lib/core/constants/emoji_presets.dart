/// 1행에 노출되는 preset 개수 (각 카테고리 / universal 동일).
const int kEmojiPresetCount = 12;

/// 카테고리 미지정 / 매핑 미발견 시 fallback.
const List<String> kEmojiPresets = [
  '🎯', '💪', '📚', '🏃', '🧘', '🍎',
  '💧', '😴', '📝', '🎨', '🎵', '🌱',
];

/// 카테고리 → preset 매핑. 사용자 자유 입력 카테고리에 대해
/// resolvePresets() 가 exact / partial 매칭으로 적용.
const Map<String, List<String>> kEmojiPresetsByCategory = {
  '운동': [
    '💪', '🏃', '🧘', '🏋️', '🤸', '⚽',
    '🚴', '🏊', '🥇', '🔥', '🥋', '🏆',
  ],
  '공부': [
    '📚', '📝', '🧠', '💡', '✏️', '🎓',
    '📖', '🔬', '🧪', '🗂️', '📐', '🌟',
  ],
  '독서': [
    '📚', '📖', '✏️', '💡', '🧠', '📝',
    '🔖', '☕', '🌙', '🎓', '🗂️', '🌟',
  ],
  '학습': [
    '📚', '📝', '🧠', '💡', '✏️', '🎓',
    '📖', '🔬', '🧪', '🗂️', '📐', '🌟',
  ],
  '건강': [
    '🍎', '💧', '🥗', '😴', '💊', '🫐',
    '🥕', '🥑', '🍵', '🧘', '🏃', '✨',
  ],
  '습관': [
    '✅', '⏰', '📅', '🎯', '🔁', '📊',
    '🌱', '🌿', '🌸', '☀️', '🌙', '🔥',
  ],
  '취미': [
    '🎨', '🎵', '🎮', '📷', '🎭', '🌱',
    '🎸', '🎬', '🍰', '🪴', '🧶', '✨',
  ],
  '명상': [
    '🧘', '😌', '💭', '✨', '🌙', '🕯️',
    '🌸', '🍃', '☁️', '🌊', '🌟', '🌿',
  ],
  '다이어트': [
    '🥗', '🍎', '💧', '⚖️', '🏃', '💪',
    '🫐', '🥑', '🥕', '🍵', '✨', '🔥',
  ],
};

/// 카테고리 문자열에 매칭되는 preset 반환.
/// 우선순위: exact key → partial (contains 양방향) → universal fallback.
List<String> resolvePresets(String? category) {
  if (category == null) return kEmojiPresets;
  final trimmed = category.trim();
  if (trimmed.isEmpty) return kEmojiPresets;

  final exact = kEmojiPresetsByCategory[trimmed];
  if (exact != null) return exact;

  for (final entry in kEmojiPresetsByCategory.entries) {
    if (trimmed.contains(entry.key) || entry.key.contains(trimmed)) {
      return entry.value;
    }
  }
  return kEmojiPresets;
}
