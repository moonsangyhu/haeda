import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../models/calendar_data.dart';
import '../providers/nudge_provider.dart';

/// Inline member list shown in the challenge space.
/// Each unverified member (except self) has a nudge button.
/// Verified members show a check mark.
class MemberNudgeList extends ConsumerStatefulWidget {
  final String challengeId;
  final List<CalendarMember> members;
  final List<String> verifiedMemberIds;
  final String? currentUserId;

  const MemberNudgeList({
    super.key,
    required this.challengeId,
    required this.members,
    required this.verifiedMemberIds,
    this.currentUserId,
  });

  @override
  ConsumerState<MemberNudgeList> createState() => _MemberNudgeListState();
}

class _MemberNudgeListState extends ConsumerState<MemberNudgeList> {
  final Set<String> _nudgedIds = {};
  final Set<String> _loadingIds = {};

  Future<void> _onNudge(CalendarMember member) async {
    if (_loadingIds.contains(member.id) || _nudgedIds.contains(member.id)) {
      return;
    }
    setState(() => _loadingIds.add(member.id));

    try {
      await sendNudge(ref, widget.challengeId, member.id);
      if (!mounted) return;
      setState(() {
        _nudgedIds.add(member.id);
        _loadingIds.remove(member.id);
      });
      _showSnackBar('${member.nickname}님에게 콕 찔렀어요!');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loadingIds.remove(member.id));
      final apiEx = e.error;
      if (apiEx is ApiException) {
        switch (apiEx.code) {
          case 'ALREADY_NUDGED':
            setState(() => _nudgedIds.add(member.id));
            _showSnackBar('오늘 이미 콕 찔렀어요');
          case 'ALREADY_VERIFIED':
            _showSnackBar('이미 인증을 완료했어요');
          default:
            _showSnackBar('오류가 발생했어요');
        }
      } else {
        _showSnackBar('오류가 발생했어요');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingIds.remove(member.id));
      _showSnackBar('오류가 발생했어요');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sort: unverified first, then verified
    final sorted = List<CalendarMember>.from(widget.members)
      ..sort((a, b) {
        final aVerified = widget.verifiedMemberIds.contains(a.id);
        final bVerified = widget.verifiedMemberIds.contains(b.id);
        if (aVerified == bVerified) return 0;
        return aVerified ? 1 : -1;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: Divider(color: theme.colorScheme.outline)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '챌린지원',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(child: Divider(color: theme.colorScheme.outline)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...sorted.map((member) {
          final isSelf =
              widget.currentUserId != null && member.id == widget.currentUserId;
          final isVerified = widget.verifiedMemberIds.contains(member.id);
          final isNudged = _nudgedIds.contains(member.id);
          final isLoading = _loadingIds.contains(member.id);

          return _MemberRow(
            member: member,
            isSelf: isSelf,
            isVerified: isVerified,
            isNudged: isNudged,
            isLoading: isLoading,
            onNudge: () => _onNudge(member),
          );
        }),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final CalendarMember member;
  final bool isSelf;
  final bool isVerified;
  final bool isNudged;
  final bool isLoading;
  final VoidCallback onNudge;

  const _MemberRow({
    required this.member,
    required this.isSelf,
    required this.isVerified,
    required this.isNudged,
    required this.isLoading,
    required this.onNudge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canNudge = !isSelf && !isVerified && !isNudged && !isLoading;

    return InkWell(
      onTap: canNudge ? onNudge : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: member.profileImageUrl != null
                  ? NetworkImage(member.profileImageUrl!)
                  : null,
              child: member.profileImageUrl == null
                  ? Text(
                      member.nickname.isNotEmpty ? member.nickname[0] : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Nickname + self label
            Expanded(
              child: Row(
                children: [
                  Text(
                    member.nickname,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isSelf) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(나)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Status / action
            _buildTrailing(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, ThemeData theme) {
    if (isVerified) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '인증 완료',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      );
    }

    if (isSelf) {
      return Text(
        '미인증',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (isNudged) {
      return Text(
        '콕 완료',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Can nudge — show tap indicator
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '콕!',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        Icon(
          Icons.touch_app_outlined,
          size: 16,
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }
}
