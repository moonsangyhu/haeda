import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/member_settings.dart';

class MemberSettingsNotifier extends StateNotifier<MemberSettings> {
  final Dio _dio;
  final String _challengeId;

  MemberSettingsNotifier(this._dio, this._challengeId)
      : super(const MemberSettings(notifyStreak: true));

  Future<void> toggleStreakNotification(bool value) async {
    final previous = state;
    state = MemberSettings(notifyStreak: value);
    try {
      final response = await _dio.patch(
        '/challenges/$_challengeId/members/me/settings',
        data: {'notify_streak': value},
      );
      final data = response.data as Map<String, dynamic>;
      state = MemberSettings.fromJson(data);
    } on DioException {
      state = previous;
    }
  }
}

final memberSettingsProvider = StateNotifierProvider.family<
    MemberSettingsNotifier, MemberSettings, String>(
  (ref, challengeId) =>
      MemberSettingsNotifier(ref.watch(dioProvider), challengeId),
);
