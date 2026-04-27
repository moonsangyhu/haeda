import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../models/gem_pack.dart';

class GemPackCard extends StatelessWidget {
  const GemPackCard({
    super.key,
    required this.pack,
    required this.onPurchase,
  });

  final GemPack pack;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat('#,###');
    final bonusText =
        pack.bonusGems > 0 ? ' +${formatter.format(pack.bonusGems)} 보너스' : '';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SvgPicture.asset('assets/icons/gem.svg', width: 36, height: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatter.format(pack.gems)}$bonusText',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatter.format(pack.priceKrw)}원',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onPurchase,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('구매'),
          ),
        ],
      ),
    );
  }
}
