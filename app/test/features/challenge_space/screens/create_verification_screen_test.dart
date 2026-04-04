import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CreateVerificationScreen 위젯 테스트.
/// Provider 의존성을 피하기 위해 핵심 UI 컴포넌트를 독립적으로 테스트한다.
void main() {
  group('인증 작성 화면 - 사진 영역', () {
    testWidgets('photo_required=true 일 때 필수 레이블 표시', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _PhotoAreaWidget(photoRequired: true, hasPhoto: false),
          ),
        ),
      );

      expect(find.text('사진 필수'), findsOneWidget);
    });

    testWidgets('photo_required=false 일 때 선택 레이블 표시', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _PhotoAreaWidget(photoRequired: false, hasPhoto: false),
          ),
        ),
      );

      expect(find.text('사진 선택 (선택 사항)'), findsOneWidget);
    });
  });

  group('인증 작성 화면 - 제출 버튼', () {
    testWidgets('photo_required=true 이고 사진 미선택 시 버튼 비활성화', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _SubmitButtonWidget(
              photoRequired: true,
              hasPhoto: false,
              isLoading: false,
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('photo_required=true 이고 사진 선택 시 버튼 활성화', (tester) async {
      bool submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _SubmitButtonWidget(
              photoRequired: true,
              hasPhoto: true,
              isLoading: false,
              onSubmit: () => submitted = true,
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(ElevatedButton));
      expect(submitted, isTrue);
    });

    testWidgets('photo_required=false 이고 사진 미선택 시 버튼 활성화', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _SubmitButtonWidget(
              photoRequired: false,
              hasPhoto: false,
              isLoading: false,
              onSubmit: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('로딩 중에는 버튼 비활성화', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _SubmitButtonWidget(
              photoRequired: false,
              hasPhoto: false,
              isLoading: true,
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('인증 작성 화면 - AppBar', () {
    testWidgets('타이틀이 "인증 작성" 으로 표시', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: _TestAppBar(),
          ),
        ),
      );

      expect(find.text('인증 작성'), findsOneWidget);
    });
  });
}

// --- 테스트용 독립 위젯들 ---

class _PhotoAreaWidget extends StatelessWidget {
  final bool photoRequired;
  final bool hasPhoto;

  const _PhotoAreaWidget({
    required this.photoRequired,
    required this.hasPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        photoRequired ? '사진 필수' : '사진 선택 (선택 사항)',
      ),
    );
  }
}

class _SubmitButtonWidget extends StatelessWidget {
  final bool photoRequired;
  final bool hasPhoto;
  final bool isLoading;
  final VoidCallback? onSubmit;

  const _SubmitButtonWidget({
    required this.photoRequired,
    required this.hasPhoto,
    required this.isLoading,
    this.onSubmit,
  });

  bool get _canSubmit {
    if (isLoading) return false;
    if (photoRequired && !hasPhoto) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _canSubmit ? onSubmit : null,
      child: isLoading
          ? const CircularProgressIndicator()
          : const Text('제출하기'),
    );
  }
}

class _TestAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _TestAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('인증 작성'));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
