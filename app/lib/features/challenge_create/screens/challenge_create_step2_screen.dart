import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_exception.dart';
import '../providers/challenge_create_provider.dart';

/// Flow 3 — Step 2: 규칙 설정 화면.
/// 시작일, 종료일, 인증 빈도(매일/주N회), 사진 필수 여부 설정 후 챌린지 생성.
class ChallengeCreateStep2Screen extends ConsumerStatefulWidget {
  /// Step 1에서 GoRouter extra로 전달된 기본 정보.
  final Map<String, dynamic> step1Data;

  const ChallengeCreateStep2Screen({
    super.key,
    required this.step1Data,
  });

  @override
  ConsumerState<ChallengeCreateStep2Screen> createState() =>
      _ChallengeCreateStep2ScreenState();
}

class _ChallengeCreateStep2ScreenState
    extends ConsumerState<ChallengeCreateStep2Screen> {
  DateTime? _startDate;
  DateTime? _endDate;
  _FrequencyType _frequencyType = _FrequencyType.daily;
  int _timesPerWeek = 3;
  bool _photoRequired = false;
  bool _isPublic = false;

  final _dateFormatter = DateFormat('yyyy-MM-dd');
  final _displayFormatter = DateFormat('yyyy. M. d.');

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && !_endDate!.isAfter(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작일을 먼저 선택해주세요.')),
      );
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!.add(const Duration(days: 29)),
      firstDate: _startDate!.add(const Duration(days: 1)),
      lastDate: _startDate!.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Map<String, dynamic> _buildFrequency() {
    if (_frequencyType == _FrequencyType.daily) {
      return {'type': 'daily'};
    }
    return {'type': 'weekly', 'times_per_week': _timesPerWeek};
  }

  Future<void> _onSubmit() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작일과 종료일을 모두 선택해주세요.')),
      );
      return;
    }

    final request = ChallengeCreateRequest(
      title: widget.step1Data['title'] as String,
      description: widget.step1Data['description'] as String?,
      category: widget.step1Data['category'] as String,
      startDate: _dateFormatter.format(_startDate!),
      endDate: _dateFormatter.format(_endDate!),
      verificationFrequency: _buildFrequency(),
      photoRequired: _photoRequired,
      isPublic: _isPublic,
    );

    try {
      final result = await ref
          .read(challengeCreateProvider.notifier)
          .createChallenge(request);
      if (mounted) {
        context.go('/create/complete/${result.id}',
            extra: result.inviteCode);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(challengeCreateProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('챌린지 만들기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/create'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StepIndicator(current: 2, total: 2),
          const SizedBox(height: 24),

          // 시작일
          _FieldLabel('시작일'),
          const SizedBox(height: 8),
          _DatePickerTile(
            key: const Key('start_date_tile'),
            label: _startDate != null
                ? _displayFormatter.format(_startDate!)
                : '날짜 선택',
            onTap: _pickStartDate,
          ),
          const SizedBox(height: 20),

          // 종료일
          _FieldLabel('종료일'),
          const SizedBox(height: 8),
          _DatePickerTile(
            key: const Key('end_date_tile'),
            label: _endDate != null
                ? _displayFormatter.format(_endDate!)
                : '날짜 선택',
            onTap: _pickEndDate,
          ),
          const SizedBox(height: 20),

          // 인증 빈도
          _FieldLabel('인증 빈도'),
          const SizedBox(height: 8),
          _FrequencySelector(
            selected: _frequencyType,
            timesPerWeek: _timesPerWeek,
            onTypeChanged: (type) =>
                setState(() => _frequencyType = type),
            onTimesChanged: (n) => setState(() => _timesPerWeek = n),
          ),
          const SizedBox(height: 20),

          // 사진 필수 여부
          _FieldLabel('사진 첨부'),
          SwitchListTile(
            key: const Key('photo_required_switch'),
            title: const Text('사진 필수'),
            subtitle: const Text('인증 시 사진 첨부를 필수로 요구합니다.'),
            value: _photoRequired,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _photoRequired = v),
          ),
          const SizedBox(height: 20),

          // 공개 여부
          _FieldLabel('공개 설정'),
          SwitchListTile(
            key: const Key('is_public_switch'),
            title: const Text('공개 챌린지'),
            subtitle: const Text('탐색 탭에서 다른 사용자가 찾을 수 있습니다.'),
            value: _isPublic,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
          const SizedBox(height: 32),

          FilledButton(
            key: const Key('submit_button'),
            onPressed: isLoading ? null : _onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('생성하기'),
          ),
        ],
      ),
    );
  }
}

enum _FrequencyType { daily, weekly }

class _FrequencySelector extends StatelessWidget {
  final _FrequencyType selected;
  final int timesPerWeek;
  final ValueChanged<_FrequencyType> onTypeChanged;
  final ValueChanged<int> onTimesChanged;

  const _FrequencySelector({
    required this.selected,
    required this.timesPerWeek,
    required this.onTypeChanged,
    required this.onTimesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _FrequencyChip(
              label: '매일',
              selected: selected == _FrequencyType.daily,
              onTap: () => onTypeChanged(_FrequencyType.daily),
            ),
            const SizedBox(width: 8),
            _FrequencyChip(
              label: '주N회',
              selected: selected == _FrequencyType.weekly,
              onTap: () => onTypeChanged(_FrequencyType.weekly),
            ),
          ],
        ),
        if (selected == _FrequencyType.weekly) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('주 '),
              DropdownButton<int>(
                key: const Key('times_per_week_dropdown'),
                value: timesPerWeek,
                items: List.generate(6, (i) => i + 1)
                    .map(
                      (n) => DropdownMenuItem(
                        value: n,
                        child: Text('$n회'),
                      ),
                    )
                    .toList(),
                onChanged: (n) {
                  if (n != null) onTimesChanged(n);
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FrequencyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DatePickerTile({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Step $current / $total',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
