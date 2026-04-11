import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/character/providers/character_provider.dart';
import '../../features/status_bar/widgets/status_bar.dart';
import '../theme/app_theme.dart';
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
    final backgroundHex =
        ref.watch(authStateProvider).valueOrNull?.backgroundColor;
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
        backgroundHex: backgroundHex,
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
    required this.backgroundHex,
    required this.theme,
    required this.onTap,
  });

  final int currentIndex;
  final dynamic character; // CharacterData?
  final String? backgroundHex;
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
                icon: _CharacterTabIcon(
                  character: character,
                  backgroundHex: backgroundHex,
                  size: 22,
                ),
                selectedIcon: _CharacterTabIcon(
                  character: character,
                  backgroundHex: backgroundHex,
                  size: 24,
                  selected: true,
                ),
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

/// 하단 내 방 탭의 캐릭터 아이콘 — 유저별 고유 원형 배경 위에 작은 캐릭터를 올린다.
class _CharacterTabIcon extends StatelessWidget {
  const _CharacterTabIcon({
    required this.character,
    required this.backgroundHex,
    required this.size,
    this.selected = false,
  });

  final dynamic character;
  final String? backgroundHex;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.characterBackgroundFromHex(backgroundHex);
    // 배경 원은 캐릭터보다 살짝 크게.
    final diameter = size + 8;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.55),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: CharacterAvatar(character: character, size: size),
    );
  }
}

/// Center "챌린지" tab — pulsing fire gradient button with hot palette
class _CenterTabItem extends StatefulWidget {
  const _CenterTabItem({
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  State<_CenterTabItem> createState() => _CenterTabItemState();
}

class _CenterTabItemState extends State<_CenterTabItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '챌린지',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _curved,
          builder: (context, child) {
            final t = _curved.value;
            final scale = 1.0 + 0.06 * t;
            final glowMul = 0.7 + 0.3 * t;
            final innerBlur = 14.0 + 6.0 * t;

            final innerOpacity =
                (widget.isSelected ? 0.55 : 0.35) * glowMul;
            final outerOpacity =
                (widget.isSelected ? 0.35 : 0.20) * glowMul;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: widget.isSelected
                              ? const [
                                  Color(0xFFFF1744),
                                  Color(0xFFFF6D00),
                                  Color(0xFFFFD600),
                                ]
                              : const [
                                  Color(0xFFFF6B6B),
                                  Color(0xFFFF8A3D),
                                  Color(0xFFFFC837),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3D00)
                                .withValues(alpha: innerOpacity),
                            blurRadius: innerBlur,
                            offset: Offset.zero,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFFC837)
                                .withValues(alpha: outerOpacity),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white,
                          width: widget.isSelected ? 3.0 : 2.5,
                        ),
                      ),
                      child: const Center(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          child: CuteIcon('fire', size: 30),
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: Text(
                    '챌린지',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: widget.isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: widget.isSelected
                          ? const Color(0xFFFF1744)
                          : const Color(0xFFFF6B6B),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
