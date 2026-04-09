import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/calendar_data.dart';
import '../providers/nudge_provider.dart';

class NudgeBottomSheet extends ConsumerStatefulWidget {
  final String challengeId;
  final List<CalendarMember> members;
  final List<String> verifiedMemberIds;

  const NudgeBottomSheet({
    super.key,
    required this.challengeId,
    required this.members,
    required this.verifiedMemberIds,
  });

  @override
  ConsumerState<NudgeBottomSheet> createState() => _NudgeBottomSheetState();
}

class _NudgeBottomSheetState extends ConsumerState<NudgeBottomSheet> {
  final Set<String> _nudgedIds = {};
  final Set<String> _loadingIds = {};

  List<CalendarMember> _getUnverifiedMembers(String? currentUserId) {
    return widget.members.where((m) {
      final isVerified = widget.verifiedMemberIds.contains(m.id);
      final isSelf = currentUserId != null && m.id == currentUserId;
      return !isVerified && !isSelf;
    }).toList();
  }

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
      _showSnackBar('콕 찔렀어요!');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loadingIds.remove(member.id));
      final apiEx = e.error;
      if (apiEx is ApiException) {
        switch (apiEx.code) {
          case 'ALREADY_NUDGED':
            _nudgedIds.add(member.id);
            _showSnackBar('오늘 이미 콕 찔렀어요');
          case 'ALREADY_VERIFIED':
            _showSnackBar('이미 인증을 완료했어요');
          default:
            _showSnackBar('오류가 발생했어요. 다시 시도해 주세요.');
        }
      } else {
        _showSnackBar('오류가 발생했어요. 다시 시도해 주세요.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingIds.remove(member.id));
      _showSnackBar('오류가 발생했어요. 다시 시도해 주세요.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authStateProvider).valueOrNull?.id;
    final unverifiedMembers = _getUnverifiedMembers(currentUserId);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '콕 찌르기',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '아직 인증 안 한 멤버에게 알림을 보내요',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (unverifiedMembers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '모든 멤버가 인증을 완료했어요!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: unverifiedMembers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = unverifiedMembers[index];
                  final isNudged = _nudgedIds.contains(member.id);
                  final isLoading = _loadingIds.contains(member.id);
                  return _MemberNudgeRow(
                    member: member,
                    isNudged: isNudged,
                    isLoading: isLoading,
                    onNudge: () => _onNudge(member),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberNudgeRow extends StatelessWidget {
  final CalendarMember member;
  final bool isNudged;
  final bool isLoading;
  final VoidCallback onNudge;

  const _MemberNudgeRow({
    required this.member,
    required this.isNudged,
    required this.isLoading,
    required this.onNudge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: member.profileImageUrl != null
                ? NetworkImage(member.profileImageUrl!)
                : null,
            child: member.profileImageUrl == null
                ? Text(
                    member.nickname.isNotEmpty
                        ? member.nickname[0]
                        : '?',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.nickname,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: isLoading
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ElevatedButton(
                    onPressed: isNudged ? null : onNudge,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Semantics(
                      label: isNudged
                          ? '${member.nickname} 콕 찌르기 완료'
                          : '${member.nickname}에게 콕 찌르기',
                      child: Text(isNudged ? '완료' : '콕!'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
