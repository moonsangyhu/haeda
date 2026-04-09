import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/nudge_provider.dart';

class NudgeBanner extends ConsumerStatefulWidget {
  final String challengeId;

  const NudgeBanner({super.key, required this.challengeId});

  @override
  ConsumerState<NudgeBanner> createState() => _NudgeBannerState();
}

class _NudgeBannerState extends ConsumerState<NudgeBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final nudgesAsync = ref.watch(receivedNudgesProvider(widget.challengeId));

    return nudgesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (nudges) {
        final unread = nudges.where((n) => !n.isRead).toList();
        if (unread.isEmpty) return const SizedBox.shrink();

        final senderName = unread.first.title.isNotEmpty
            ? unread.first.title
            : '누군가';

        return _NudgeBannerCard(
          senderName: senderName,
          onVerify: () => context.push('/challenges/${widget.challengeId}/verify'),
          onDismiss: () => setState(() => _dismissed = true),
        );
      },
    );
  }
}

class _NudgeBannerCard extends StatelessWidget {
  final String senderName;
  final VoidCallback onVerify;
  final VoidCallback onDismiss;

  const _NudgeBannerCard({
    required this.senderName,
    required this.onVerify,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        color: theme.colorScheme.primaryContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: InkWell(
          onTap: onVerify,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Text(
                  '👆',
                  style: const TextStyle(fontSize: 20),
                  semanticsLabel: '콕 찌르기',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$senderName님이 콕 찔렀어요!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '인증해주세요',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: '콕 찌르기 알림 닫기',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                    color: theme.colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
