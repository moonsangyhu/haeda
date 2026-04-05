import 'package:flutter/material.dart';
import '../../../core/theme/season_icons.dart';
import '../models/calendar_data.dart';

class CalendarDayCell extends StatelessWidget {
  final int day;
  final DayEntry? entry;
  final List<CalendarMember> members;
  final VoidCallback? onTap;

  const CalendarDayCell({
    super.key,
    required this.day,
    this.entry,
    required this.members,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 2),
            _buildContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (entry == null) {
      return const SizedBox.shrink();
    }

    // 전원 인증: 계절 아이콘 표시
    if (entry!.allCompleted && entry!.seasonIconType != null) {
      return Text(
        SeasonIcons.getIcon(entry!.seasonIconType),
        style: const TextStyle(fontSize: 20),
      );
    }

    // 일부 인증: 인증한 멤버 프로필 썸네일 표시
    if (entry!.verifiedMembers.isNotEmpty) {
      return _buildMemberThumbnails(context);
    }

    return const SizedBox.shrink();
  }

  Widget _buildMemberThumbnails(BuildContext context) {
    final verifiedMemberIds = entry!.verifiedMembers.toSet();
    final verifiedMembersList = members
        .where((m) => verifiedMemberIds.contains(m.id))
        .toList();

    // 최대 3명까지만 표시
    final displayMembers = verifiedMembersList.take(3).toList();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 1,
      runSpacing: 1,
      children: displayMembers.map((member) {
        return _MemberAvatar(member: member);
      }).toList(),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final CalendarMember member;

  const _MemberAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 8,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: member.profileImageUrl != null
          ? NetworkImage(member.profileImageUrl!)
          : null,
      child: member.profileImageUrl == null
          ? Text(
              member.nickname.isNotEmpty ? member.nickname[0] : '?',
              style: const TextStyle(fontSize: 7),
            )
          : null,
    );
  }
}
