import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/character/providers/character_provider.dart';
import '../../features/status_bar/widgets/status_bar.dart';
import 'character_avatar.dart';
import 'cute_icon.dart';

class MainShell extends ConsumerWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final character = ref.watch(myCharacterProvider).valueOrNull;
    final currentIndex = navigationShell.currentIndex;
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(
            bottom: false,
            child: StatusBar(),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: navigationShell,
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: _BottomBar(
        currentIndex: currentIndex,
        character: character,
        theme: theme,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == currentIndex,
          );
        },
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.character,
    required this.theme,
    required this.onTap,
  });

  final int currentIndex;
  final dynamic character; // CharacterData?
  final ThemeData theme;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            top: 4,
            bottom: bottomPadding > 0 ? 0 : 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 0: 내 방
              _TabItem(
                index: 0,
                isSelected: currentIndex == 0,
                label: '내 방',
                icon: CharacterAvatar(character: character, size: 22),
                selectedIcon: CharacterAvatar(character: character, size: 24),
                onTap: onTap,
              ),
              // 1: 상점
              _TabItem(
                index: 1,
                isSelected: currentIndex == 1,
                label: '상점',
                icon: _buildShopIcon(false),
                selectedIcon: _buildShopIcon(true),
                onTap: onTap,
              ),
              // 2: 챌린지 (center, raised)
              _CenterTabItem(
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
                theme: theme,
              ),
              // 3: 피드
              _TabItem(
                index: 3,
                isSelected: currentIndex == 3,
                label: '피드',
                icon: Icon(
                  Icons.dynamic_feed,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.45,
                  ),
                ),
                selectedIcon: Icon(
                  Icons.dynamic_feed,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                onTap: onTap,
              ),
              // 4: 설정
              _TabItem(
                index: 4,
                isSelected: currentIndex == 4,
                label: '설정',
                icon: const CuteIcon('settings', size: 22, opacity: 0.45),
                selectedIcon: const CuteIcon('settings', size: 24),
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopIcon(bool selected) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFF6B6B), Color(0xFFFFAB40), Color(0xFFFFD740)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Icon(
        selected ? Icons.storefront : Icons.storefront_outlined,
        size: selected ? 24 : 22,
        color: Colors.white,
      ),
    );
  }
}

/// Normal tab item (non-center)
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.index,
    required this.isSelected,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.onTap,
  });

  final int index;
  final bool isSelected;
  final String label;
  final Widget icon;
  final Widget selectedIcon;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isSelected ? selectedIcon : icon,
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Center "챌린지" tab — raised/elevated with colorful gradient + challenge icon
class _CenterTabItem extends StatelessWidget {
  const _CenterTabItem({
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Raised circular button with challenge icon inside
          Transform.translate(
            offset: const Offset(0, -14),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isSelected
                      ? const [Color(0xFF7C4DFF), Color(0xFFE040FB)]
                      : const [Color(0xFFB388FF), Color(0xFFF48FB1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withOpacity(
                      isSelected ? 0.4 : 0.2,
                    ),
                    blurRadius: isSelected ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: Colors.white,
                  width: 2.5,
                ),
              ),
              child: Center(
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: const CuteIcon('home', size: 28),
                ),
              ),
            ),
          ),
          // Label below
          Transform.translate(
            offset: const Offset(0, -10),
            child: Text(
              '챌린지',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF7C4DFF)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
