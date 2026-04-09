import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/notifications/providers/notification_provider.dart';

class MainShell extends ConsumerWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  // Maps branch index (0-3) to nav bar index (0,1,3,4) — skipping center index 2.
  int _branchToNavIndex(int branchIndex) {
    // branch 0 -> nav 0, branch 1 -> nav 1, branch 2 -> nav 3, branch 3 -> nav 4
    return branchIndex < 2 ? branchIndex : branchIndex + 1;
  }

  // Maps nav bar index to branch index. Returns null for the center "+" button (index 2).
  int? _navToBranchIndex(int navIndex) {
    if (navIndex == 2) return null;
    return navIndex < 2 ? navIndex : navIndex - 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _branchToNavIndex(navigationShell.currentIndex),
        onDestinationSelected: (index) {
          if (index == 2) {
            context.push('/create');
            return;
          }
          final branchIndex = _navToBranchIndex(index);
          if (branchIndex == null) return;
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '내 챌린지',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '탐색',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_circle_outlined, size: 32),
            selectedIcon: Icon(Icons.add_circle, size: 32),
            label: '만들기',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications),
            ),
            label: '알림',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
