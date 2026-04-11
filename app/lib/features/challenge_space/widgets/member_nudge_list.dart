import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/character_avatar.dart';
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
          case 'CANNOT_NUDGE_SELF':
            _showSnackBar('자기 자신을 콕 찌를 수는 없어요');
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
            // Avatar — tap to view character detail
            GestureDetector(
              onTap: () => _showCharacterSheet(context, member),
              child: CharacterAvatar(
                character: member.character,
                size: 40,
                showEffect: false,
              ),
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
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✅', style: TextStyle(fontSize: 13)),
            SizedBox(width: 4),
            Text(
              '인증완료',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '👈',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 4),
          Text(
            '콕!',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showCharacterSheet(BuildContext context, CalendarMember m) {
    if (m.character == null) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CharacterAvatar(
              character: m.character,
              size: 120,
              showEffect: true,
            ),
            const SizedBox(height: 12),
            Text(
              m.nickname,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
