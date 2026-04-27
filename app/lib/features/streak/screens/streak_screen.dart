import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/streak_calendar_provider.dart';
import '../widgets/streak_calendar_grid.dart';
import '../widgets/streak_header.dart';

class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _shift(int delta) {
    setState(() {
      var y = _year;
      var m = _month + delta;
      if (m > 12) {
        m = 1;
        y += 1;
      } else if (m < 1) {
        m = 12;
        y -= 1;
      }
      _year = y;
      _month = m;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async =
        ref.watch(streakCalendarProvider((year: _year, month: _month)));

    return Scaffold(
      appBar: AppBar(title: const Text('연속 기록')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 실패: $e')),
        data: (cal) => SingleChildScrollView(
          child: Column(
            children: [
              StreakHeader(streak: cal.streak),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StreakCalendarGrid(
                  calendar: cal,
                  onPrevMonth: () => _shift(-1),
                  onNextMonth: () => _shift(1),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
