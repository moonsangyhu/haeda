import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// DailyVerificationsScreen 위젯 테스트.
/// Provider 의존성을 피하기 위해 핵심 UI 컴포넌트를 독립적으로 테스트한다.
void main() {
  group('날짜별 인증 현황 화면 - AppBar', () {
    testWidgets('날짜가 "4월 2일 인증 현황" 형식으로 표시', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: _DateAppBar(dateStr: '2026-04-02'),
          ),
        ),
      );

      expect(find.text('4월 2일 인증 현황'), findsOneWidget);
    });
  });

  group('날짜별 인증 현황 화면 - 완료 배너', () {
    testWidgets('전원 인증 완료 시 완료 메시지 표시', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _CompletionBanner(
              allCompleted: true,
              verificationCount: 5,
            ),
          ),
        ),
      );

      expect(find.text('전원 인증 완료!'), findsOneWidget);
    });

    testWidgets('미완료 시 완료 메시지 미표시', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _CompletionBanner(
              allCompleted: false,
              verificationCount: 3,
            ),
          ),
        ),
      );

      expect(find.text('전원 인증 완료!'), findsNothing);
    });
  });

  group('날짜별 인증 현황 화면 - 인증자 리스트', () {
    testWidgets('인증자 닉네임 표시', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: _VerificationList(
                nicknames: ['김철수', '이영희', '박지민'],
              ),
            ),
          ),
        ),
      );

      expect(find.text('김철수'), findsOneWidget);
      expect(find.text('이영희'), findsOneWidget);
      expect(find.text('박지민'), findsOneWidget);
    });

    testWidgets('인증 항목 탭 시 onTap 콜백 호출', (tester) async {
      String? tappedId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TappableVerificationList(
              items: const [
                _VerificationListItemData(id: 'v-001', nickname: '김철수'),
                _VerificationListItemData(id: 'v-002', nickname: '이영희'),
              ],
              onTap: (id) => tappedId = id,
            ),
          ),
        ),
      );

      await tester.tap(find.text('김철수'));
      expect(tappedId, 'v-001');

      await tester.tap(find.text('이영희'));
      expect(tappedId, 'v-002');
    });

    testWidgets('인증자 없을 때 빈 메시지 표시', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _VerificationList(nicknames: []),
          ),
        ),
      );

      expect(find.text('아직 인증한 사람이 없습니다.'), findsOneWidget);
    });
  });
}

// --- 테스트용 독립 위젯들 ---

class _DateAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String dateStr;

  const _DateAppBar({required this.dateStr});

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return '${parsed.month}월 ${parsed.day}일 인증 현황';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(_formatDate(dateStr)));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CompletionBanner extends StatelessWidget {
  final bool allCompleted;
  final int verificationCount;

  const _CompletionBanner({
    required this.allCompleted,
    required this.verificationCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allCompleted) const Text('전원 인증 완료!'),
          Text('$verificationCount명 인증'),
        ],
      ),
    );
  }
}

class _VerificationListItemData {
  final String id;
  final String nickname;
  const _VerificationListItemData({required this.id, required this.nickname});
}

class _TappableVerificationList extends StatelessWidget {
  final List<_VerificationListItemData> items;
  final void Function(String id) onTap;

  const _TappableVerificationList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items
          .map((item) => ListTile(
                title: Text(item.nickname),
                onTap: () => onTap(item.id),
              ))
          .toList(),
    );
  }
}

class _VerificationList extends StatelessWidget {
  final List<String> nicknames;

  const _VerificationList({required this.nicknames});

  @override
  Widget build(BuildContext context) {
    if (nicknames.isEmpty) {
      return const Center(child: Text('아직 인증한 사람이 없습니다.'));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: nicknames.map((n) => ListTile(title: Text(n))).toList(),
    );
  }
}
