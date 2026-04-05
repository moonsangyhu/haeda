import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'emoji_icon.dart';

class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: EmojiIcon('🏠'),
            selectedIcon: EmojiIcon('🏡'),
            label: '내 챌린지',
          ),
          NavigationDestination(
            icon: EmojiIcon('🧭'),
            selectedIcon: EmojiIcon('🗺️'),
            label: '탐색',
          ),
          NavigationDestination(
            icon: EmojiIcon('🔔'),
            selectedIcon: EmojiIcon('🛎️'),
            label: '알림',
          ),
        ],
      ),
    );
  }
}
