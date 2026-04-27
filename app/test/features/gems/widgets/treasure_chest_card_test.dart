import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/gems/models/chest_state.dart';
import 'package:haeda/features/gems/models/treasure_chest.dart';
import 'package:haeda/features/gems/widgets/treasure_chest_card.dart';

TreasureChest _chest({
  ChestState state = ChestState.noChest,
  int? remainingSeconds,
}) =>
    TreasureChest(
      state: state,
      rewardGems: 100,
      remainingSeconds: remainingSeconds,
    );

void main() {
  testWidgets('noChest renders prompt text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TreasureChestCard(
            chest: _chest(state: ChestState.noChest),
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('인증하면'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('locked renders remaining time + progress', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TreasureChestCard(
            chest: _chest(state: ChestState.locked, remainingSeconds: 19380),
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.text('5시간 23분 남음'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('openable renders enabled button + ready text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TreasureChestCard(
            chest: _chest(state: ChestState.openable),
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('준비됐어요'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('openable tap calls onOpen', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TreasureChestCard(
            chest: _chest(state: ChestState.openable),
            onOpen: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    expect(tapped, isTrue);
  });

  testWidgets('opened renders done text + no button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TreasureChestCard(
            chest: _chest(state: ChestState.opened),
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('오늘 보상 받음'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
