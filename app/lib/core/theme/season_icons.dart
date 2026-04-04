class SeasonIcons {
  SeasonIcons._();

  static String getIcon(String? seasonIconType) {
    switch (seasonIconType) {
      case 'spring':
        return '🌸';
      case 'summer':
        return '🌿';
      case 'fall':
        return '🍁';
      case 'winter':
        return '❄️';
      default:
        return '';
    }
  }

  /// 월(month)로 계절 아이콘 타입을 반환한다.
  static String getTypeFromMonth(int month) {
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'fall';
    return 'winter'; // 12, 1, 2
  }
}
