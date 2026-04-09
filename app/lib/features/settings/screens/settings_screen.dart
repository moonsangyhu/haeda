import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '로그아웃',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoggingOut = true);
    try {
      await ref.read(authStateProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── Profile section ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primary.withAlpha(51),
                  backgroundImage: (user?.profileImageUrl != null &&
                          (user!.profileImageUrl?.isNotEmpty ?? false))
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child: (user?.profileImageUrl == null ||
                          (user?.profileImageUrl?.isEmpty ?? true))
                      ? Icon(
                          Icons.person,
                          size: 32,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.nickname ?? '사용자',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(indent: 20, endIndent: 20),
          const SizedBox(height: 8),

          // ── App settings section header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              '앱 설정',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Dark mode toggle
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('다크 모드'),
            subtitle: const Text('앱 화면을 어둡게 표시합니다'),
            value: settings.darkMode,
            onChanged: (value) => notifier.setDarkMode(value),
            activeThumbColor: theme.colorScheme.primary,
            activeTrackColor: theme.colorScheme.primary.withAlpha(128),
          ),

          // Notifications toggle
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('알림'),
            subtitle: const Text('푸시 알림을 받습니다'),
            value: settings.notificationsEnabled,
            onChanged: (value) => notifier.setNotificationsEnabled(value),
            activeThumbColor: theme.colorScheme.primary,
            activeTrackColor: theme.colorScheme.primary.withAlpha(128),
          ),

          const SizedBox(height: 8),
          const Divider(indent: 20, endIndent: 20),
          const SizedBox(height: 16),

          // ── Logout button ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              onPressed: _isLoggingOut ? null : _logout,
              icon: _isLoggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: Text(_isLoggingOut ? '로그아웃 중...' : '로그아웃'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error, width: 1.5),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
