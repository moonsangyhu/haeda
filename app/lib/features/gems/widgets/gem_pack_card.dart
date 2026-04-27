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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SvgPicture.asset('assets/icons/gem.svg', width: 36, height: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        formatter.format(pack.gems),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (pack.bonusGems > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${formatter.format(pack.bonusGems)} 보너스',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${formatter.format(pack.priceKrw)}원',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onPurchase,
              child: const Text('구매하기'),
            ),
          ],
        ),
      ),
    );
  }
}
