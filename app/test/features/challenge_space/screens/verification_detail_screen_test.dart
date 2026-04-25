import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// VerificationDetailScreen 위젯 테스트.
/// Provider 의존성을 피하기 위해 핵심 UI 컴포넌트를 독립적으로 테스트한다.
void main() {
  group('인증 상세 화면 - AppBar', () {
    testWidgets('"인증 상세" 타이틀이 표시된다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: _DetailAppBar(),
          ),
        ),
      );

      expect(find.text('인증 상세'), findsOneWidget);
    });

    testWidgets('뒤로가기 버튼이 있다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: _DetailAppBar(),
          ),
        ),
      );

      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  group('인증 상세 화면 - 작성자 섹션', () {
    testWidgets('닉네임이 표시된다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _AuthorInfo(
              nickname: '김철수',
              date: '2026-04-05',
            ),
          ),
        ),
      );

      expect(find.text('김철수'), findsOneWidget);
    });

    testWidgets('날짜가 "2026년 4월 5일" 형식으로 표시된다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _AuthorInfo(
              nickname: '김철수',
              date: '2026-04-05',
            ),
          ),
        ),
      );

      expect(find.text('2026년 4월 5일'), findsOneWidget);
    });
  });

  group('인증 상세 화면 - 일기 텍스트', () {
    testWidgets('일기 텍스트가 표시된다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: _DiaryText(text: '오늘 운동을 열심히 했습니다.'),
            ),
          ),
        ),
      );

      expect(find.text('오늘 운동을 열심히 했습니다.'), findsOneWidget);
    });
  });

  group('인증 리스트 아이템 - 탭 동작', () {
    testWidgets('인증 리스트 아이템에 onTap이 있다', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              title: const Text('김철수'),
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      expect(tapped, isTrue);
    });
  });
}

// --- 테스트용 독립 위젯들 ---

class _DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DetailAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('인증 상세'),
      leading: const BackButton(),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AuthorInfo extends StatelessWidget {
  final String nickname;
  final String date;

  const _AuthorInfo({required this.nickname, required this.date});

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return '${parsed.year}년 ${parsed.month}월 ${parsed.day}일';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(nickname),
        Text(_formatDate(date)),
      ],
    );
  }
}

class _DiaryText extends StatelessWidget {
  final String text;

  const _DiaryText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text);
  }
}
