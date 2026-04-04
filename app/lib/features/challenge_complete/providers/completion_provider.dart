import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/completion_result.dart';

final completionProvider =
    FutureProvider.family<CompletionResult, String>((ref, challengeId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/challenges/$challengeId/completion');
  final data = response.data as Map<String, dynamic>;
  return CompletionResult.fromJson(data);
});
