import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/core/api/api_client.dart';
import 'package:haeda/features/character/providers/shop_provider.dart';
import 'package:haeda/features/status_bar/models/user_stats.dart';
import 'package:haeda/features/status_bar/providers/user_stats_provider.dart';

/// 모든 POST `/shop/items/.../purchase` 요청을 201 로 즉시 성공시키는 인터셉터.
class _StubPurchaseInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (options.method == 'POST' &&
        options.path.contains('/shop/items/') &&
        options.path.endsWith('/purchase')) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 201,
          data: {
            'item_id': 'item-x',
            'remaining_balance': 80,
          },
        ),
      );
      return;
    }
    handler.next(options);
  }
}

Dio _buildStubDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
  dio.interceptors.add(_StubPurchaseInterceptor());
  return dio;
}

void main() {
  group('ShopPurchaseNotifier.purchaseItem', () {
    test(
      '구매 성공 시 상단 상태바의 젬 잔액이 즉시 갱신되도록 userStatsProvider 가 invalidate 되어야 한다',
      () async {
        var fetchCount = 0;
        const stubStats = UserStats(
          streak: 0,
          verifiedToday: false,
          activeChallenges: 0,
          completedChallenges: 0,
          gems: 100,
        );

        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(_buildStubDio()),
            userStatsProvider.overrideWith((ref) async {
              fetchCount++;
              return stubStats;
            }),
          ],
        );
        addTearDown(container.dispose);

        // 1) 최초 read — 상태바가 처음 그려지는 시나리오
        await container.read(userStatsProvider.future);
        expect(fetchCount, 1, reason: '최초 read 시 1회 fetch 되어야 한다');

        // 2) 구매 실행
        final ok = await container
            .read(shopPurchaseProvider.notifier)
            .purchaseItem('item-x');
        expect(ok, isTrue, reason: 'stub 가 201 을 반환하므로 구매는 성공해야 한다');

        // 3) 구매 후 read — invalidate 가 일어났다면 다시 fetch 되어야 함
        await container.read(userStatsProvider.future);
        expect(
          fetchCount,
          2,
          reason:
              '구매 성공 후 userStatsProvider 가 invalidate 되어 상태바 젬 잔액이 즉시 갱신되어야 한다',
        );
      },
    );
  });
}
