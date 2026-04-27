import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/treasure_chest.dart';

final treasureChestProvider =
    FutureProvider.autoDispose<TreasureChest>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/gems/chest');
  final data = response.data as Map<String, dynamic>;
  return TreasureChest.fromJson(data);
});
