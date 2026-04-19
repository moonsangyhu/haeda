import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../providers/room_speech_provider.dart';

void showSpeechInputSheet(
  BuildContext context, {
  required String challengeId,
  required String myUserId,
  required String myNickname,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _SpeechInputSheet(
      challengeId: challengeId,
      myUserId: myUserId,
      myNickname: myNickname,
    ),
  );
}

class _SpeechInputSheet extends ConsumerStatefulWidget {
  final String challengeId;
  final String myUserId;
  final String myNickname;

  const _SpeechInputSheet({
    required this.challengeId,
    required this.myUserId,
    required this.myNickname,
  });

  @override
  ConsumerState<_SpeechInputSheet> createState() => _SpeechInputSheetState();
}

class _SpeechInputSheetState extends ConsumerState<_SpeechInputSheet> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  bool _isDeleting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({String challengeId, String myUserId, String myNickname}) get _params => (
        challengeId: widget.challengeId,
        myUserId: widget.myUserId,
        myNickname: widget.myNickname,
      );

  Future<void> _onSubmit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(roomSpeechProvider(_params).notifier).submit(text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('방에 한마디 전했어요 🗣️')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapApiError(e.code))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오류가 발생했어요. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _onDelete() async {
    setState(() => _isDeleting = true);
    try {
      await ref.read(roomSpeechProvider(_params).notifier).deleteMine();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제에 실패했어요. 다시 시도해 주세요.')),
      );
    }
  }

  String _mapApiError(String code) {
    switch (code) {
      case 'SPEECH_TOO_LONG':
        return '40자를 초과할 수 없어요.';
      case 'SPEECH_EMPTY':
        return '내용을 입력해 주세요.';
      case 'SPEECH_RATE_LIMITED':
        return '너무 빨리 보냈어요. 잠깐 후 다시 시도해 주세요.';
      case 'SPEECH_NOT_MEMBER':
        return '챌린지 멤버만 말할 수 있어요.';
      default:
        return '오류가 발생했어요. 다시 시도해 주세요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final charCount = _controller.text.length;
    final canSubmit = charCount > 0 && !_isLoading;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '방에 한마디',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLength: 40,
              maxLines: 2,
              minLines: 1,
              autofocus: true,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  Text(
                    '$currentLength / ${maxLength ?? 40}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\n')),
              ],
              decoration: InputDecoration(
                hintText: '한마디를 입력해요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (_) => setState(() {}),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 8),
            Text(
              '⏱ 오늘 자정까지 보여요',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _isDeleting ? null : _onDelete,
                  child: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('지우기'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: canSubmit ? _onSubmit : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('말하기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
