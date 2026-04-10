import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/notifications/providers/notification_provider.dart';
import '../../features/status_bar/widgets/status_bar.dart';
import 'cute_icon.dart';

class MainShell extends ConsumerWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: const StatusBar(),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          const NavigationDestination(
            icon: CuteIcon('home', size: 24, opacity: 0.5),
            selectedIcon: CuteIcon('home', size: 28),
            label: '내 챌린지',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bedroom_parent_outlined, size: 24),
            selectedIcon: Icon(Icons.bedroom_parent, size: 28),
            label: '내 방',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const CuteIcon('bell', size: 24, opacity: 0.5),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const CuteIcon('bell', size: 28),
            ),
            label: '알림',
          ),
          const NavigationDestination(
            icon: CuteIcon('settings', size: 24, opacity: 0.5),
            selectedIcon: CuteIcon('settings', size: 28),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
