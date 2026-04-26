import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/friends/screens/contact_search_screen.dart';

void main() {
  testWidgets('ID 입력 필드와 placeholder 가 보인다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ContactSearchScreen()),
      ),
    );
    expect(find.text('닉네임#12345 형식으로 입력'), findsOneWidget);
    expect(find.byKey(const Key('id_search_field')), findsOneWidget);
  });

  testWidgets('형식 미달 시 ID 검색 버튼은 비활성', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ContactSearchScreen()),
      ),
    );
    await tester.enterText(find.byKey(const Key('id_search_field')), '홍길동');
    await tester.pump();
    final button = tester.widget<IconButton>(
      find.byKey(const Key('id_search_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('형식 충족 시 ID 검색 버튼 활성화', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ContactSearchScreen()),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('id_search_field')),
      '홍길동#43217',
    );
    await tester.pump();
    final button = tester.widget<IconButton>(
      find.byKey(const Key('id_search_button')),
    );
    expect(button.onPressed, isNotNull);
  });
}
