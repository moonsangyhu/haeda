import 'package:flutter/material.dart';

class FriendTile extends StatelessWidget {
  const FriendTile({
    super.key,
    required this.nickname,
    this.profileImageUrl,
    this.trailing,
    this.onTap,
  });

  final String nickname;
  final String? profileImageUrl;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial =
        nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: theme.colorScheme.primary.withAlpha(51),
        backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
            ? NetworkImage(profileImageUrl!)
            : null,
        child: (profileImageUrl == null || profileImageUrl!.isEmpty)
            ? Text(
                initial,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              )
            : null,
      ),
      title: Text(
        nickname,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
