import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/room_speech_api.dart';
import '../models/room_speech.dart';

// Phases of the state machine (durations in ms)
const _fadeInMs = 180;
const _holdMs = 3000;
const _fadeOutMs = 180;
const _repeatGapMs = 120;
const _turnGapMs = 500;
const _tickMs = 16; // ~60fps
const _repeatsPerTurn = 3;
const _pollSeconds = 60;

enum _Phase { turnGap, fadeIn, hold, fadeOut, repeatGap }

class RoomSpeechController extends ChangeNotifier {
  RoomSpeechController(
    this._api,
    this._challengeId,
    this._myUserId,
    this._myNickname,
  );

  final RoomSpeechApi _api;
  final String _challengeId;
  final String _myUserId;
  final String _myNickname;

  List<RoomSpeech> queue = [];
  int currentIdx = 0;
  String? activeSpeakerId;
  String? activeText;
  double bubbleOpacity = 0.0;
  double bubbleScale = 1.0;

  Timer? _tickTimer;
  Timer? _pollTimer;
  _Phase _phase = _Phase.turnGap;
  int _phaseElapsed = 0;
  int _repeatCount = 1;

  Future<void> hydrate() async {
    try {
      final fetched = await _api.list(_challengeId);
      _mergeQueue(fetched);
      notifyListeners();
    } catch (_) {
      // silently fail — keep last-known queue
    }
  }

  void _mergeQueue(List<RoomSpeech> fetched) {
    // Preserve active speaker position; replace queue content
    final activeId = activeSpeakerId;
    queue = fetched;
    if (queue.isEmpty) {
      currentIdx = 0;
      activeSpeakerId = null;
      activeText = null;
      bubbleOpacity = 0.0;
      return;
    }
    if (activeId != null) {
      final idx = queue.indexWhere((s) => s.userId == activeId);
      if (idx >= 0) {
        currentIdx = idx;
      } else {
        currentIdx = currentIdx.clamp(0, queue.length - 1);
      }
    } else {
      currentIdx = currentIdx.clamp(0, queue.length - 1);
    }
  }

  void start() {
    if (_tickTimer != null) return;
    // Start in turnGap so the first speaker fires immediately
    _phase = _Phase.turnGap;
    _phaseElapsed = _turnGapMs; // skip the gap
    _repeatCount = 1;

    _tickTimer = Timer.periodic(
      const Duration(milliseconds: _tickMs),
      _onTick,
    );
    _pollTimer = Timer.periodic(
      const Duration(seconds: _pollSeconds),
      (_) => hydrate(),
    );
  }

  void _onTick(Timer _) {
    if (queue.isEmpty) {
      if (activeSpeakerId != null) {
        activeSpeakerId = null;
        activeText = null;
        bubbleOpacity = 0.0;
        bubbleScale = 1.0;
        notifyListeners();
      }
      return;
    }

    _phaseElapsed += _tickMs;

    switch (_phase) {
      case _Phase.turnGap:
        if (_phaseElapsed >= _turnGapMs) {
          _advanceTurn();
          _phase = _Phase.fadeIn;
          _phaseElapsed = 0;
        }

      case _Phase.fadeIn:
        final t = (_phaseElapsed / _fadeInMs).clamp(0.0, 1.0);
        bubbleOpacity = t;
        bubbleScale = _easeOutBack(0.92, 1.0, t);
        notifyListeners();
        if (_phaseElapsed >= _fadeInMs) {
          bubbleOpacity = 1.0;
          bubbleScale = 1.0;
          _phase = _Phase.hold;
          _phaseElapsed = 0;
        }

      case _Phase.hold:
        if (_phaseElapsed >= _holdMs) {
          _phase = _Phase.fadeOut;
          _phaseElapsed = 0;
        }

      case _Phase.fadeOut:
        final t = (_phaseElapsed / _fadeOutMs).clamp(0.0, 1.0);
        bubbleOpacity = 1.0 - t;
        bubbleScale = 1.0;
        notifyListeners();
        if (_phaseElapsed >= _fadeOutMs) {
          bubbleOpacity = 0.0;
          _phase = _Phase.repeatGap;
          _phaseElapsed = 0;
        }

      case _Phase.repeatGap:
        if (_phaseElapsed >= _repeatGapMs) {
          if (_repeatCount < _repeatsPerTurn) {
            _repeatCount++;
            _phase = _Phase.fadeIn;
            _phaseElapsed = 0;
          } else {
            // End of turn
            activeSpeakerId = null;
            activeText = null;
            bubbleOpacity = 0.0;
            bubbleScale = 1.0;
            _repeatCount = 1;
            currentIdx++;
            _phase = _Phase.turnGap;
            _phaseElapsed = 0;
            notifyListeners();
          }
        }
    }
  }

  void _advanceTurn() {
    if (queue.isEmpty) return;
    final speaker = queue[currentIdx % queue.length];
    activeSpeakerId = speaker.userId;
    activeText = speaker.content;
    notifyListeners();
  }

  // Simple easeOutBack approximation
  double _easeOutBack(double from, double to, double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    final eased = 1 + c3 * _pow(t - 1, 3) + c1 * _pow(t - 1, 2);
    return from + (to - from) * eased.clamp(0.0, 1.1);
  }

  double _pow(double x, int n) {
    double result = 1.0;
    for (var i = 0; i < n; i++) {
      result *= x;
    }
    return result;
  }

  void pauseForOffstage() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void resume() {
    if (_tickTimer != null) return;
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: _tickMs),
      _onTick,
    );
  }

  Future<void> submit(String text) async {
    final speech = await _api.submit(
      _challengeId,
      text,
      myUserId: _myUserId,
      myNickname: _myNickname,
    );
    _upsertMine(speech);
    notifyListeners();
  }

  void _upsertMine(RoomSpeech speech) {
    final existingIdx = queue.indexWhere((s) => s.userId == _myUserId);
    if (existingIdx >= 0) {
      queue = [
        ...queue.sublist(0, existingIdx),
        speech,
        ...queue.sublist(existingIdx + 1),
      ];
      // Jump so next turn starts on me
      currentIdx = existingIdx - 1;
    } else {
      queue = [...queue, speech];
      currentIdx = queue.length - 2;
    }
    if (currentIdx < 0) currentIdx = queue.length - 1;
  }

  Future<void> deleteMine() async {
    await _api.remove(_challengeId);
    final idx = queue.indexWhere((s) => s.userId == _myUserId);
    if (idx >= 0) {
      if (activeSpeakerId == _myUserId) {
        activeSpeakerId = null;
        activeText = null;
        bubbleOpacity = 0.0;
        bubbleScale = 1.0;
        _phase = _Phase.turnGap;
        _phaseElapsed = 0;
        _repeatCount = 1;
      }
      queue = [...queue.sublist(0, idx), ...queue.sublist(idx + 1)];
      if (queue.isEmpty) {
        currentIdx = 0;
      } else {
        currentIdx = currentIdx.clamp(0, queue.length - 1);
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}

final roomSpeechProvider = ChangeNotifierProvider.family
    .autoDispose<RoomSpeechController,
        ({String challengeId, String myUserId, String myNickname})>(
  (ref, params) {
    final api = ref.watch(roomSpeechApiProvider);
    return RoomSpeechController(
      api,
      params.challengeId,
      params.myUserId,
      params.myNickname,
    );
  },
);
