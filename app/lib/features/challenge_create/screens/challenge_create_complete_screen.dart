import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

/// Flow 3 — 생성 완료 화면.
/// 초대 코드 표시, 링크 복사, 챌린지로 이동 제공.
class ChallengeCreateCompleteScreen extends StatelessWidget {
  final String challengeId;
  final String inviteCode;

  const ChallengeCreateCompleteScreen({
    super.key,
    required this.challengeId,
    required this.inviteCode,
  });

  void _shareInviteCode() {
    Share.share('해다에서 함께 챌린지해요!\n\n챌린지 초대 코드: $inviteCode');
  }

  Future<void> _copyInviteCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 코드가 클립보드에 복사되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Icon(
                Icons.check_circle_outline,
                size: 72,
                color: Colors.green,
              ),
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
                  borderRadius: BorderRadius.circular(8),
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
              OutlinedButton.icon(
                key: const Key('copy_button'),
                onPressed: () => _copyInviteCode(context),
                icon: const Icon(Icons.copy),
                label: const Text('링크 복사'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('share_button'),
                onPressed: _shareInviteCode,
                icon: const Icon(Icons.share),
                label: const Text('공유하기'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('go_to_challenge_button'),
                onPressed: () => context.go('/challenges/$challengeId'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('챌린지로 이동'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
