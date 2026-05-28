import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/feed/models/feed_item_data.dart';
import 'package:haeda/features/feed/providers/feed_provider.dart';
import 'package:haeda/features/feed/screens/feed_screen.dart';

void main() {
  group('FeedScreen', () {
    testWidgets('shows loading indicator while loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedListProvider.overrideWith(
              (ref, cursor) => Completer<FeedListData>().future,
            ),
          ],
          child: const MaterialApp(home: FeedScreen()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no items', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedListProvider.overrideWith(
              (ref, cursor) async =>
                  const FeedListData(items: [], nextCursor: null),
            ),
          ],
          child: const MaterialApp(home: FeedScreen()),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('친구를 추가하고\n소식을 확인해보세요!'), findsOneWidget);
      expect(find.text('친구 찾기'), findsOneWidget);
    });

    testWidgets('shows feed items when data is available', (tester) async {
      final items = [
        FeedItemData(
          id: '1',
          actor: const FeedActor(
            id: 'user-1',
            nickname: '홍길동',
            profileImageUrl: null,
          ),
          type: 'verification',
          challengeTitle: '30일 운동',
          challengeId: 'ch-1',
          photoUrls: null,
          diaryText: null,
          clapCount: 5,
          hasClapped: false,
          createdAt: DateTime.now().toIso8601String(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedListProvider.overrideWith(
              (ref, cursor) async =>
                  FeedListData(items: items, nextCursor: null),
            ),
          ],
          child: const MaterialApp(home: FeedScreen()),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('홍길동'), findsWidgets);
      expect(find.textContaining('30일 운동'), findsWidgets);
    });

    testWidgets('shows error state on failure', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedListProvider.overrideWith(
              (ref, cursor) async => throw Exception('network error'),
            ),
          ],
          child: const MaterialApp(home: FeedScreen()),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('피드를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });
  });
}
