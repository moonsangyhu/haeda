import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../challenge_create/widgets/emoji_picker.dart';
import '../providers/challenge_detail_provider.dart';

class ChallengeIconEditSheet extends ConsumerStatefulWidget {
  final String challengeId;
  final String currentIcon;

  const ChallengeIconEditSheet({
    super.key,
    required this.challengeId,
    required this.currentIcon,
  });

  @override
  ConsumerState<ChallengeIconEditSheet> createState() =>
      _ChallengeIconEditSheetState();
}

class _ChallengeIconEditSheetState
    extends ConsumerState<ChallengeIconEditSheet> {
  late String _picked;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.currentIcon;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        '/challenges/${widget.challengeId}/settings',
        data: {'icon': _picked},
      );
      ref.invalidate(challengeDetailProvider(widget.challengeId));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이모지 변경에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '챌린지 이모지 변경',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            EmojiPicker(
              initialValue: _picked,
              onChanged: (v) => setState(() => _picked = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('emoji_save_button'),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(_saving ? '저장 중...' : '저장'),
            ),
          ],
        ),
      ),
    );
  }
}
