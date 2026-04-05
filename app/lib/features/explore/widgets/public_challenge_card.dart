import 'package:flutter/material.dart';
import '../models/public_challenge.dart';

class PublicChallengeCard extends StatelessWidget {
  final PublicChallenge challenge;
  final VoidCallback onTap;

  const PublicChallengeCard({
    super.key,
    required this.challenge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + category chip row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      challenge.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      challenge.category,
                      style: theme.textTheme.labelSmall,
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Date range + member count row
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${challenge.startDate} ~ ${challenge.endDate}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.people_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${challenge.memberCount}명',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (challenge.photoRequired) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.photo_camera_outlined,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '사진 필수',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Creator info row
              Row(
                children: [
                  _CreatorAvatar(
                    imageUrl: challenge.creator.profileImageUrl,
                    nickname: challenge.creator.nickname,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    challenge.creator.nickname,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorAvatar extends StatelessWidget {
  final String? imageUrl;
  final String nickname;

  const _CreatorAvatar({required this.imageUrl, required this.nickname});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundImage: NetworkImage(imageUrl!),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      );
    }

    return CircleAvatar(
      radius: 12,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        nickname.isNotEmpty ? nickname[0] : '?',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
