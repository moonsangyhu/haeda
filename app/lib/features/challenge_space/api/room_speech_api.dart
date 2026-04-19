import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/room_speech.dart';

class RoomSpeechApi {
  RoomSpeechApi(this._dio);

  final Dio _dio;

  Future<List<RoomSpeech>> list(String challengeId) async {
    final response = await _dio.get<List<dynamic>>(
      '/challenges/$challengeId/room-speech',
    );
    final data = response.data ?? [];
    return data
        .map((e) => RoomSpeech.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RoomSpeech> submit(
    String challengeId,
    String content, {
    required String myUserId,
    required String myNickname,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/challenges/$challengeId/room-speech',
      data: {'content': content},
    );
    final data = response.data!;
    return RoomSpeech(
      userId: myUserId,
      nickname: myNickname,
      content: data['content'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
      expiresAt: DateTime.parse(data['expires_at'] as String),
    );
  }

  Future<void> remove(String challengeId) async {
    await _dio.delete<void>('/challenges/$challengeId/room-speech');
  }
}

final roomSpeechApiProvider = Provider<RoomSpeechApi>(
  (ref) => RoomSpeechApi(ref.watch(dioProvider)),
);
