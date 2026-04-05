import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../my_page/providers/my_challenges_provider.dart';
import '../../../core/widgets/invite_share_buttons.dart';

/// Flow 3 — 생성 완료 화면.
/// 초대 코드 표시, 코드 복사, 카카오톡 공유, 확인 제공.
class ChallengeCreateCompleteScreen extends ConsumerWidget {
  final String challengeId;
  final String inviteCode;

  const ChallengeCreateCompleteScreen({
    super.key,
    required this.challengeId,
    required this.inviteCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('챌린지 생성 완료'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('\u2705', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              Text(
                '생성 완료!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              Text(
                '초대 코드',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  inviteCode,
                  key: const Key('invite_code_text'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              InviteShareButtons(inviteCode: inviteCode),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('confirm_button'),
                onPressed: () {
                  ref.invalidate(myChallengesProvider);
                  context.go('/my-page');
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
