import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/cute_icon.dart';
import '../../auth/providers/auth_provider.dart';
import '../../character/providers/character_provider.dart';
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
    final character = ref.watch(myCharacterProvider).valueOrNull;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final bgColor =
        AppTheme.characterBackgroundFromHex(user?.backgroundColor);

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
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bgColor,
                  ),
                  alignment: Alignment.center,
                  child: CharacterAvatar(character: character, size: 52),
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
            secondary: const CuteIcon('moon', size: 26),
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
            secondary: const CuteIcon('bell', size: 26),
            title: const Text('알림'),
            subtitle: const Text('푸시 알림을 받습니다'),
            value: settings.notificationsEnabled,
            onChanged: (value) => notifier.setNotificationsEnabled(value),
            activeThumbColor: theme.colorScheme.primary,
            activeTrackColor: theme.colorScheme.primary.withAlpha(128),
          ),

          // Day cutoff hour setting
          _DayCutoffHourTile(),

          const SizedBox(height: 8),
          const Divider(indent: 20, endIndent: 20),
          const SizedBox(height: 8),

          // ── Friend management section header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              '친구',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Icon(Icons.people, size: 26, color: theme.colorScheme.primary),
            title: const Text('친구 목록'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/friends'),
          ),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Icon(Icons.mail, size: 26, color: theme.colorScheme.primary),
            title: const Text('받은 요청'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/friends/requests'),
          ),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Icon(Icons.person_add, size: 26, color: theme.colorScheme.primary),
            title: const Text('연락처로 친구 찾기'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/friends/contact-search'),
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
                  : const CuteIcon('wave', size: 22),
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

/// ListTile + BottomSheet for selecting the day cutoff hour.
class _DayCutoffHourTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DayCutoffHourTile> createState() =>
      _DayCutoffHourTileState();
}

class _DayCutoffHourTileState extends ConsumerState<_DayCutoffHourTile> {
  static const _labels = ['자정까지', '새벽 1시까지', '새벽 2시까지'];

  Future<void> _showPicker(int currentValue) async {
    int selected = currentValue;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      '하루 경계 시각',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (int i = 0; i <= 2; i++)
                    ListTile(
                      leading: Radio<int>(
                        value: i,
                        groupValue: selected,
                        onChanged: (v) {
                          if (v != null) setInner(() => selected = v);
                        },
                      ),
                      title: Text(_labels[i]),
                      onTap: () => setInner(() => selected = i),
                    ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('확인'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;
    if (selected == currentValue) return;

    try {
      await ref
          .read(authStateProvider.notifier)
          .updateDayCutoffHour(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('하루 경계 시각이 "${_labels[selected]}"로 변경되었어요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('설정 변경에 실패했습니다. 다시 시도해 주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cutoff =
        ref.watch(authStateProvider).valueOrNull?.dayCutoffHour ?? 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(Icons.schedule, size: 26, color: theme.colorScheme.primary),
      title: const Text('하루 경계 시각'),
      subtitle: const Text('새벽 인증을 전날 미션으로 인정해요'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _labels[cutoff.clamp(0, 2)],
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showPicker(cutoff),
    );
  }
}
