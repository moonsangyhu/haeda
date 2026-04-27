import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/gems/models/gem_pack.dart';
import 'package:haeda/features/gems/widgets/gem_pack_card.dart';

void main() {
  testWidgets('renders bonus badge when bonus_gems > 0', (tester) async {
    const pack = GemPack(
      id: 'pack_medium',
      gems: 5000,
      bonusGems: 500,
      priceKrw: 25000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GemPackCard(pack: pack, onPurchase: () {}),
        ),
      ),
    );
    expect(find.textContaining('+500'), findsOneWidget);
    expect(find.text('25,000원'), findsOneWidget);
    expect(find.text('5,000'), findsOneWidget);
  });

  testWidgets('no bonus badge when bonus_gems = 0', (tester) async {
    const pack = GemPack(
      id: 'pack_small',
      gems: 1000,
      bonusGems: 0,
      priceKrw: 5000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GemPackCard(pack: pack, onPurchase: () {}),
        ),
      ),
    );
    expect(find.textContaining('보너스'), findsNothing);
    expect(find.textContaining('5,000'), findsAtLeastNWidgets(1));
  });

  testWidgets('purchase tap calls onPurchase', (tester) async {
    var tapped = false;
    const pack = GemPack(
      id: 'pack_small',
      gems: 1000,
      bonusGems: 0,
      priceKrw: 5000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GemPackCard(pack: pack, onPurchase: () => tapped = true),
        ),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    expect(tapped, isTrue);
  });
}
