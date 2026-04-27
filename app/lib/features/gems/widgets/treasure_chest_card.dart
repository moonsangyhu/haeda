import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/chest_state.dart';
import '../models/treasure_chest.dart';

class TreasureChestCard extends StatelessWidget {
  const TreasureChestCard({
    super.key,
    required this.chest,
    required this.onOpen,
  });

  final TreasureChest chest;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SvgPicture.asset(_iconAsset(), width: 64, height: 64),
            const SizedBox(height: 12),
            Text(
              _stateText(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (chest.state == ChestState.locked) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _progress(),
                minHeight: 6,
              ),
            ],
            const SizedBox(height: 16),
            if (chest.state == ChestState.openable)
              ElevatedButton(
                onPressed: onOpen,
                child: Text('${chest.rewardGems}보석 받기'),
              ),
          ],
        ),
      ),
    );
  }

  String _iconAsset() {
    switch (chest.state) {
      case ChestState.noChest:
      case ChestState.locked:
        return 'assets/icons/chest_locked.svg';
      case ChestState.openable:
        return 'assets/icons/chest_ready.svg';
      case ChestState.opened:
        return 'assets/icons/chest_opened.svg';
    }
  }

  String _stateText() {
    switch (chest.state) {
      case ChestState.noChest:
        return '오늘 챌린지를 인증하면\n보물상자가 열립니다';
      case ChestState.locked:
        return _formatRemaining(chest.remainingSeconds ?? 0);
      case ChestState.openable:
        return '보물상자가 준비됐어요!';
      case ChestState.opened:
        return '오늘 보상 받음. 내일 다시 인증!';
    }
  }

  String _formatRemaining(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분 남음';
    return '$m분 남음';
  }

  double _progress() {
    const total = 12 * 3600;
    final remaining = chest.remainingSeconds ?? total;
    final elapsed = total - remaining;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}
