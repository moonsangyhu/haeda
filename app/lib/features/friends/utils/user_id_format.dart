class ParsedUserId {
  final String nickname;
  final String discriminator;

  const ParsedUserId({required this.nickname, required this.discriminator});
}

final RegExp _userIdPattern = RegExp(r'^(.{1,30})#([0-9]{5})$');

ParsedUserId? parseUserId(String input) {
  final trimmed = input.trim();
  final match = _userIdPattern.firstMatch(trimmed);
  if (match == null) return null;
  return ParsedUserId(
    nickname: match.group(1)!,
    discriminator: match.group(2)!,
  );
}

String formatUserId(String nickname, String discriminator) {
  return '$nickname#$discriminator';
}
