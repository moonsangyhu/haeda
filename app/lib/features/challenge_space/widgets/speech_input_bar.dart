import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/room_speech.dart';
import '../providers/room_speech_provider.dart';

const _maxLen = 40;
const _warnLen = 30;

class SpeechInputBar extends ConsumerStatefulWidget {
  final String challengeId;
  final String? currentUserId;
  final String myNickname;

  const SpeechInputBar({
    super.key,
    required this.challengeId,
    required this.currentUserId,
    this.myNickname = '나',
  });

  @override
  ConsumerState<SpeechInputBar> createState() => _SpeechInputBarState();
}

class _SpeechInputBarState extends ConsumerState<SpeechInputBar> {
  final _textCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _submitting = false;
  String? _inlineHint;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() => setState(() {}));
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {});
    if (!_focus.hasFocus) return;
    // 키보드가 올라온 뒤 입력 바를 viewport 바닥에 정렬해 가리지 않게 한다.
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted || !_focus.hasFocus) return;
      final ctx = context;
      if (!ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 200),
        alignment: 1.0,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _textCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// widget prop 보다 auth provider 의 fresh 값을 우선 사용. parent rebuild
  /// 누락이나 race condition 으로 widget.currentUserId 가 stale null 인
  /// 케이스를 우회한다.
  String? _resolveUserId() {
    final fromAuth = ref.read(authStateProvider).valueOrNull?.id;
    return fromAuth ?? widget.currentUserId;
  }

  String _resolveNickname() {
    final fromAuth = ref.read(authStateProvider).valueOrNull?.nickname;
    return fromAuth ?? widget.myNickname;
  }

  bool get _canSubmit =>
      !_submitting && _textCtrl.text.trim().isNotEmpty;

  ({String challengeId, String myUserId, String myNickname})? get _params {
    final id = _resolveUserId();
    if (id == null) return null;
    return (
      challengeId: widget.challengeId,
      myUserId: id,
      myNickname: _resolveNickname(),
    );
  }

  void _showHint(String msg) {
    _hintTimer?.cancel();
    setState(() => _inlineHint = msg);
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _inlineHint = null);
    });
  }

  void _onSendPressed() {
    if (_submitting) return;
    if (_textCtrl.text.trim().isEmpty) {
      _showHint('내용을 입력해주세요');
      _focus.requestFocus();
      return;
    }
    final params = _params;
    if (params == null) {
      // 진단 정보를 hint 에 노출 — currentUserId 가 정확히 어디서 막히는지 보임
      final asyncState = ref.read(authStateProvider);
      String reason;
      if (asyncState.isLoading) {
        reason = '로그인 정보 로딩 중';
      } else if (asyncState.hasError) {
        reason = '로그인 정보 오류';
      } else {
        reason = '로그인이 필요해요';
      }
      _showHint(reason);
      return;
    }
    _submit(params);
  }

  Future<void> _submit(
    ({String challengeId, String myUserId, String myNickname}) params,
  ) async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(roomSpeechProvider(params).notifier).submit(text);
      if (!mounted) return;
      _textCtrl.clear();
    } on DioException catch (e) {
      if (!mounted) return;
      _handleApiError(e.error, e.response?.statusCode, e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      _handleApiError(e, e.statusCode, null);
    } catch (e) {
      if (!mounted) return;
      _showHint('전송 실패: ${e.runtimeType}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _handleApiError(Object? raw, int? status, String? fallbackMsg) {
    final apiEx = raw is ApiException ? raw : null;
    final code = apiEx?.code;
    if (code == 'SPEECH_RATE_LIMITED') {
      _showHint('잠시 후 다시');
    } else if (code == 'SPEECH_NOT_MEMBER') {
      _showHint('멤버만 한마디 남길 수 있어요');
    } else if (code == 'SPEECH_TOO_LONG') {
      _showHint('40자 이내로');
    } else if (code == 'SPEECH_EMPTY') {
      _showHint('내용을 입력해주세요');
    } else if (code != null) {
      _showHint('전송 실패: $code');
    } else if (status != null) {
      _showHint('전송 실패 (HTTP $status)');
    } else {
      _showHint('전송 실패: ${fallbackMsg ?? '알 수 없음'}');
    }
  }

  Future<void> _delete() async {
    final params = _params;
    if (params == null) return;
    try {
      await ref.read(roomSpeechProvider(params).notifier).deleteMine();
    } on DioException catch (e) {
      if (!mounted) return;
      final apiEx = e.error;
      final code = apiEx is ApiException ? apiEx.code : null;
      _showHint('지우기 실패${code != null ? ': $code' : ''}');
    } catch (e) {
      if (!mounted) return;
      _showHint('지우기 실패: ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = _params;

    RoomSpeech? mySpeech;
    if (params != null) {
      final controller = ref.watch(roomSpeechProvider(params));
      mySpeech = controller.queue
          .where((s) => s.userId == widget.currentUserId)
          .cast<RoomSpeech?>()
          .firstWhere((_) => true, orElse: () => null);
    }

    final hasMine = mySpeech != null;
    final len = _textCtrl.text.length;
    final showCounter = _focus.hasFocus || len > 0;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: theme.dividerColor.withValues(alpha: 0.4)),
          if (hasMine)
            _MyActiveSpeechHint(
              content: mySpeech.content,
              onDelete: _delete,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: '방에 한마디 입력',
                            textField: true,
                            child: TextField(
                              controller: _textCtrl,
                              focusNode: _focus,
                              maxLength: _maxLen,
                              maxLines: 1,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _onSendPressed(),
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                              ],
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: '방에 한마디 보내기',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF9E9E9E),
                                ),
                                counterText: '',
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        if (_inlineHint != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _inlineHint!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFEF5350),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else if (showCounter) ...[
                          const SizedBox(width: 6),
                          Text(
                            '$len/$_maxLen',
                            style: TextStyle(
                              fontSize: 11,
                              color: len > _warnLen
                                  ? const Color(0xFFEF5350)
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: '전송',
                  child: IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: _canSubmit
                          ? theme.colorScheme.primary
                          : const Color(0xFFBDBDBD),
                    ),
                    onPressed: _onSendPressed,
                    tooltip: '전송',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyActiveSpeechHint extends StatelessWidget {
  final String content;
  final VoidCallback onDelete;

  const _MyActiveSpeechHint({
    required this.content,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Text('💬', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: '내 한마디: $content, 지우려면 두 번 탭',
              child: RichText(
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                  children: [
                    const TextSpan(
                      text: '내가 한 말: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    TextSpan(text: '"$content"'),
                  ],
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '지우기',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
