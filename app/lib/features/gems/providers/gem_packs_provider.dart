import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/gem_pack.dart';

final gemPacksProvider = FutureProvider<List<GemPack>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/gems/packs');
  final data = response.data as Map<String, dynamic>;
  final list = data['packs'] as List;
  return list
      .map((j) => GemPack.fromJson(j as Map<String, dynamic>))
      .toList();
});
