import 'package:flutter/material.dart';
import '../../../core/constants/emoji_presets.dart';

class EmojiPicker extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;

  /// 카테고리 입력값 (자유 텍스트). null 또는 빈 문자열이면 universal preset.
  /// 변경되면 preset 그리드가 즉시 갱신된다 (선택 emoji 는 유지).
  final String? category;

  const EmojiPicker({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.category,
  });

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> {
  late final TextEditingController _customController;
  String? _selected;
  bool _customMode = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    final init = widget.initialValue;
    final initialPresets = resolvePresets(widget.category);
    _customController = TextEditingController(
      text: init != null && !initialPresets.contains(init) ? init : '',
    );
    if (init != null && !initialPresets.contains(init)) {
      _customMode = true;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _selectPreset(String e) {
    setState(() {
      _selected = e;
      _customMode = false;
      _customController.clear();
    });
    widget.onChanged(e);
  }

  void _toggleCustom() {
    setState(() {
      _customMode = !_customMode;
      if (!_customMode) _customController.clear();
    });
  }

  void _onCustomChanged(String value) {
    final trimmed = value.trim();
    setState(() => _selected = trimmed.isEmpty ? null : trimmed);
    if (trimmed.isNotEmpty) widget.onChanged(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final presets = resolvePresets(widget.category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          key: const Key('emoji_preset_wrap'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in presets)
              ChoiceChip(
                key: Key('emoji_preset_$e'),
                label: Text(e, style: const TextStyle(fontSize: 20)),
                selected: _selected == e && !_customMode,
                onSelected: (_) => _selectPreset(e),
              ),
            ChoiceChip(
              key: const Key('emoji_custom_toggle'),
              label: const Text('직접 입력'),
              selected: _customMode,
              onSelected: (_) => _toggleCustom(),
            ),
          ],
        ),
        if (_customMode) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('emoji_custom_field'),
            controller: _customController,
            maxLength: 2,
            onChanged: _onCustomChanged,
            decoration: const InputDecoration(
              hintText: '이모지 입력',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ],
      ],
    );
  }
}
