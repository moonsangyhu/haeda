import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';
import '../providers/invite_preview_provider.dart';
import '../providers/join_challenge_provider.dart';
import '../../challenge_space/models/challenge_detail.dart';

/// Flow 4-A — 초대 링크를 통한 챌린지 참여 미리보기 화면.
/// 초대 코드로 챌린지 정보를 미리 보여주고 참여 버튼을 제공한다.
class InvitePreviewScreen extends ConsumerWidget {
  final String inviteCode;

  const InvitePreviewScreen({super.key, required this.inviteCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(invitePreviewProvider(inviteCode));

    return Scaffold(
      appBar: AppBar(
        title: const Text('챌린지 미리보기'),
      ),
      body: previewAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, _) {
          final msg = error is ApiException && error.code == 'INVALID_INVITE_CODE'
              ? '유효하지 않은 초대 코드입니다.'
              : '챌린지 정보를 불러올 수 없습니다.';
          return AppErrorWidget(
            error: msg,
            onRetry: () => ref.invalidate(invitePreviewProvider(inviteCode)),
          );
        },
        data: (challenge) => _InvitePreviewBody(challenge: challenge),
      ),
    );
  }
}

class _InvitePreviewBody extends ConsumerWidget {
  final ChallengeDetail challenge;

  const _InvitePreviewBody({required this.challenge});

  String _formatFrequency(Map<String, dynamic> freq) {
    final type = freq['type'] as String?;
    if (type == 'daily') return '매일';
    if (type == 'weekly') {
      final times = freq['times_per_week'];
      return '주 ${times ?? '?'}회';
    }
    return type ?? '-';
  }

  Future<void> _onJoin(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(joinChallengeProvider.notifier).join(challenge.id);
      if (context.mounted) {
        context.go('/challenges/${challenge.id}');
      }
    } on ApiException catch (e) {
      if (!context.mounted) return;
      if (e.code == 'ALREADY_JOINED') {
        // 이미 참여 중이면 바로 챌린지 공간으로 이동
        context.go('/challenges/${challenge.id}');
        return;
      }
      final msg = e.code == 'CHALLENGE_ENDED'
          ? '이미 종료된 챌린지입니다.'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('참여 중 오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(joinChallengeProvider).isLoading;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 카테고리 칩
        Row(
          children: [
            Chip(
              label: Text(challenge.category),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 제목
        Text(
          challenge.title,
          key: const Key('challenge_title'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),

        // 설명
        if (challenge.description != null &&
            challenge.description!.isNotEmpty) ...[
          Text(
            challenge.description!,
            key: const Key('challenge_description'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
        ],

        const Divider(),
        const SizedBox(height: 8),

        // 기간
        _InfoRow(
          icon: Icons.calendar_month_outlined,
          label: '기간',
          value:
              '${challenge.startDate} ~ ${challenge.endDate}',
        ),
        const SizedBox(height: 12),

        // 인증 빈도
        _InfoRow(
          icon: Icons.repeat,
          label: '인증 빈도',
          value: _formatFrequency(challenge.verificationFrequency),
        ),
        const SizedBox(height: 12),

        // 사진 필수 여부
        _InfoRow(
          icon: Icons.photo_camera_outlined,
          label: '사진 필수',
          value: challenge.photoRequired ? '필수' : '선택',
        ),
        const SizedBox(height: 12),

        // 참여자 수
        _InfoRow(
          icon: Icons.group_outlined,
          label: '현재 참여자',
          value: '${challenge.memberCount}명',
        ),
        const SizedBox(height: 32),

        FilledButton(
          key: const Key('join_button'),
          onPressed: isLoading ? null : () => _onJoin(context, ref),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('참여하기'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(value),
      ],
    );
  }
}
