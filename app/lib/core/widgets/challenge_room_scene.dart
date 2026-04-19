import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/challenge_space/models/calendar_data.dart';
import '../../features/challenge_space/providers/room_speech_provider.dart';
import '../../features/challenge_space/widgets/celebration_overlay.dart';
import '../../features/challenge_space/widgets/room_character.dart';
import '../../features/character/models/character_data.dart';
import '../../features/character/providers/character_provider.dart';
import '../../features/challenge_space/providers/nudge_provider.dart';
import 'miniroom_scene.dart' show MiniroomColors;

/// Challenge-room color palette — extends MiniroomColors with room-specific tokens.
class ChallengeRoomColors {
  ChallengeRoomColors._();

  // Inherited from MiniroomColors for wall/floor reuse
  static const wallBase = MiniroomColors.wallBase;
  static const wallShadow = MiniroomColors.wallShadow;
  static const baseboard = MiniroomColors.baseboard;
  static const moldingTop = MiniroomColors.moldingTop;
  static const woodDark = MiniroomColors.woodDark;
  static const woodLight = MiniroomColors.woodLight;
  static const windowFrame = MiniroomColors.windowFrame;
  static const windowGlass = MiniroomColors.windowGlass;
  static const skyBlue = MiniroomColors.skyBlue;
  static const windowPane = MiniroomColors.windowPane;
  static const clockFace = MiniroomColors.clockFace;
  static const clockHand = MiniroomColors.clockHand;

  // Cork board
  static const corkBoard = Color(0xFFD7CCC8);
  static const corkBoardDark = Color(0xFFBCAAA4);
  static const pinRed = Color(0xFFE57373);
  static const pinYellow = Color(0xFFFFF176);
  static const memoWhite = Color(0xFFFFFDE7);
  static const memoBlue = Color(0xFFE3F2FD);

  // Mini calendar
  static const calendarBg = Color(0xFFFFFDE7);
  static const calendarRed = Color(0xFFEF5350);
  static const calendarText = Color(0xFF5D4037);

  // Wood floor (horizontal grain — distinct from miniroom checkerboard)
  static const woodFloorLight = Color(0xFFE8D5B7);
  static const woodFloorDark = Color(0xFFD4B896);
  static const woodFloorGrain = Color(0xFFC9A882);

  // Character states
  static const verifiedGreen = Color(0xFF66BB6A);
  static const unverifiedGray = Color(0xFFBDBDBD);
  static const sleepyBlue = Color(0xFF90CAF9);

  // Celebration
  static const partyGold = Color(0xFFFFD54F);
  static const partyPink = Color(0xFFF48FB1);
  static const sparkle = Color(0xFFFFFFFF);
}

/// Holds position ratio for a single character slot in the room.
class _CharacterSlot {
  final double xRatio; // 0..1 from left
  final double yRatio; // 0..1 from top

  const _CharacterSlot(this.xRatio, this.yRatio);
}

/// Cyworld-style shared room for a challenge.
/// Shows all member characters; verified at front, unverified (sleepy) at back.
class ChallengeRoomScene extends ConsumerStatefulWidget {
  final List<CalendarMember> members;
  final List<String> verifiedMemberIds;
  final String? currentUserId;
  final String? creatorId;
  final String challengeId;
  final bool allCompletedToday;
  final VoidCallback? onCalendarTap;
  final VoidCallback? onVerify;
  final double height;

  const ChallengeRoomScene({
    super.key,
    required this.members,
    required this.verifiedMemberIds,
    required this.challengeId,
    this.currentUserId,
    this.creatorId,
    this.allCompletedToday = false,
    this.onCalendarTap,
    this.onVerify,
    this.height = 280,
  });

  @override
  ConsumerState<ChallengeRoomScene> createState() => _ChallengeRoomSceneState();
}

class _ChallengeRoomSceneState extends ConsumerState<ChallengeRoomScene>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final Set<String> _nudgedSet = {};

  ({String challengeId, String myUserId, String myNickname})? _speechParams;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSpeech();
  }

  @override
  void didUpdateWidget(covariant ChallengeRoomScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_speechParams == null &&
        widget.currentUserId != null &&
        widget.currentUserId != oldWidget.currentUserId) {
      _initSpeech();
    }
  }

  void _initSpeech() {
    final userId = widget.currentUserId;
    if (userId == null) return;
    final nickname = widget.members
            .where((m) => m.id == userId)
            .map((m) => m.nickname)
            .firstOrNull ??
        '나';
    _speechParams = (
      challengeId: widget.challengeId,
      myUserId: userId,
      myNickname: nickname,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final params = _speechParams;
      if (params == null) return;
      final controller = ref.read(roomSpeechProvider(params).notifier);
      controller.hydrate().then((_) {
        if (mounted) controller.start();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final params = _speechParams;
    if (params == null) return;
    if (state == AppLifecycleState.paused) {
      ref.read(roomSpeechProvider(params).notifier).pauseForOffstage();
    } else if (state == AppLifecycleState.resumed) {
      final controller = ref.read(roomSpeechProvider(params).notifier);
      controller.resume();
      controller.hydrate();
    }
  }

  Future<void> _onNudge(CalendarMember member) async {
    if (_nudgedSet.contains(member.id)) return;
    setState(() => _nudgedSet.add(member.id));
    try {
      await sendNudge(ref, widget.challengeId, member.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.nickname}님에게 콕 찔렀어요!'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _nudgedSet.remove(member.id));
      final msg = e.toString().contains('ALREADY_NUDGED')
          ? '오늘 이미 콕 찔렀어요'
          : e.toString().contains('ALREADY_VERIFIED')
              ? '이미 인증을 완료했어요'
              : '콕 찌르기에 실패했어요';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  List<_CharacterSlot> _buildSlots(int count) {
    switch (count) {
      case 1:
        return [const _CharacterSlot(0.50, 0.55)];
      case 2:
        return [
          const _CharacterSlot(0.35, 0.62),
          const _CharacterSlot(0.65, 0.62),
        ];
      case 3:
        return [
          const _CharacterSlot(0.50, 0.52),
          const _CharacterSlot(0.28, 0.70),
          const _CharacterSlot(0.72, 0.70),
        ];
      case 4:
        return [
          const _CharacterSlot(0.25, 0.55),
          const _CharacterSlot(0.75, 0.55),
          const _CharacterSlot(0.30, 0.75),
          const _CharacterSlot(0.70, 0.75),
        ];
      case 5:
        return [
          const _CharacterSlot(0.50, 0.50),
          const _CharacterSlot(0.22, 0.58),
          const _CharacterSlot(0.78, 0.58),
          const _CharacterSlot(0.33, 0.76),
          const _CharacterSlot(0.67, 0.76),
        ];
      case 6:
        return [
          const _CharacterSlot(0.22, 0.50),
          const _CharacterSlot(0.50, 0.50),
          const _CharacterSlot(0.78, 0.50),
          const _CharacterSlot(0.22, 0.73),
          const _CharacterSlot(0.50, 0.73),
          const _CharacterSlot(0.78, 0.73),
        ];
      case 7:
        return [
          const _CharacterSlot(0.18, 0.48),
          const _CharacterSlot(0.40, 0.48),
          const _CharacterSlot(0.62, 0.48),
          const _CharacterSlot(0.84, 0.48),
          const _CharacterSlot(0.26, 0.72),
          const _CharacterSlot(0.50, 0.72),
          const _CharacterSlot(0.74, 0.72),
        ];
      default: // 8+: 4x2
        return [
          const _CharacterSlot(0.15, 0.47),
          const _CharacterSlot(0.38, 0.47),
          const _CharacterSlot(0.62, 0.47),
          const _CharacterSlot(0.85, 0.47),
          const _CharacterSlot(0.20, 0.72),
          const _CharacterSlot(0.40, 0.72),
          const _CharacterSlot(0.60, 0.72),
          const _CharacterSlot(0.80, 0.72),
        ];
    }
  }

  void _sortGroup(List<CalendarMember> group) {
    group.sort((a, b) {
      final aCreator = a.id == widget.creatorId;
      final bCreator = b.id == widget.creatorId;
      final aSelf = a.id == widget.currentUserId;
      final bSelf = b.id == widget.currentUserId;
      if (aCreator && !bCreator) return -1;
      if (!aCreator && bCreator) return 1;
      if (aSelf && !bSelf) return -1;
      if (!aSelf && bSelf) return 1;
      return 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final myCharacter = ref.watch(myCharacterProvider).valueOrNull;
    final speechParams = _speechParams;
    final speechController = speechParams != null
        ? ref.watch(roomSpeechProvider(speechParams))
        : null;

    // Sort: unverified → back rows (lower y), verified → front rows (higher y)
    final verified = widget.members
        .where((m) => widget.verifiedMemberIds.contains(m.id))
        .toList();
    final unverified = widget.members
        .where((m) => !widget.verifiedMemberIds.contains(m.id))
        .toList();
    _sortGroup(verified);
    _sortGroup(unverified);

    // unverified first in list = lower slots (back), verified = higher slots (front)
    final ordered = [...unverified, ...verified];
    final displayCount = math.min(ordered.length, 8);
    final slots = _buildSlots(displayCount);

    final verifiedCount = widget.verifiedMemberIds.length;
    final totalCount = widget.members.length;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final pxW = w / 32;
          final pxH = h / 24;

          final wallTint = Color.lerp(
            ChallengeRoomColors.wallBase,
            Theme.of(context).colorScheme.primary,
            0.15,
          )!;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: Size(w, h),
                  painter: _ChallengeRoomBackgroundPainter(
                    pxW: pxW,
                    pxH: pxH,
                    wallTint: wallTint,
                  ),
                ),
              ),

              // Characters (paint back-to-front)
              for (int i = 0; i < displayCount; i++)
                _buildCharacterWidget(
                  context,
                  ordered[i],
                  slots[i],
                  w,
                  h,
                  myCharacter,
                  speechController,
                ),

              // Mini calendar tap overlay
              if (widget.onCalendarTap != null)
                Positioned(
                  left: 11 * pxW,
                  top: 3 * pxH,
                  width: 7 * pxW,
                  height: 6 * pxH,
                  child: GestureDetector(
                    onTap: widget.onCalendarTap,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),

              // Celebration overlay
              CelebrationOverlay(
                trigger: widget.allCompletedToday,
                roomSize: Size(w, h),
              ),

              // Summary badge
              Positioned(
                bottom: 6,
                right: 10,
                child: _SummaryBadge(
                  verifiedCount: verifiedCount,
                  totalCount: totalCount,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCharacterWidget(
    BuildContext context,
    CalendarMember member,
    _CharacterSlot slot,
    double w,
    double h,
    CharacterData? myCharacter,
    RoomSpeechController? speechController,
  ) {
    final isSelf = widget.currentUserId != null &&
        member.id.trim().toLowerCase() ==
            widget.currentUserId!.trim().toLowerCase();
    final isCreator = member.id == widget.creatorId;
    final isVerified = widget.verifiedMemberIds.contains(member.id);
    final baseSize = math.min(w, h) * 0.18;
    final size = isSelf ? baseSize * 1.1 : baseSize;

    final effectiveCharacter =
        isSelf ? (myCharacter ?? member.character) : member.character;

    final left = slot.xRatio * w - size / 2;
    final top = slot.yRatio * h - size * 0.85;

    final isSpeaking = speechController?.activeSpeakerId == member.id;
    final speechText = isSpeaking ? speechController?.activeText : null;
    final bubbleOpacity = isSpeaking ? (speechController?.bubbleOpacity ?? 0.0) : 0.0;
    final bubbleScale = isSpeaking ? (speechController?.bubbleScale ?? 1.0) : 1.0;

    return Positioned(
      left: left,
      top: top,
      width: size,
      child: RoomCharacter(
        character: effectiveCharacter,
        size: size,
        isVerified: isVerified,
        isSelf: isSelf,
        isCreator: isCreator,
        nickname: member.nickname,
        celebrationJump: widget.allCompletedToday,
        onTap: isSelf
            ? null
            : isVerified
                ? null // wave handled internally
                : () => _onNudge(member),
        speechText: speechText,
        bubbleOpacity: bubbleOpacity,
        bubbleScale: bubbleScale,
      ),
    );
  }
}

// ─── Background Painter ────────────────────────────────────────────────────

class _ChallengeRoomBackgroundPainter extends CustomPainter {
  final double pxW;
  final double pxH;
  final Color wallTint;

  _ChallengeRoomBackgroundPainter({
    required this.pxW,
    required this.pxH,
    required this.wallTint,
  });

  void _drawPx(Canvas canvas, Color color, int x, int y) {
    canvas.drawRect(
      Rect.fromLTWH(x * pxW, y * pxH, pxW, pxH),
      Paint()..color = color,
    );
  }

  void _drawRect(Canvas canvas, Color color, int x, int y, int w, int h) {
    canvas.drawRect(
      Rect.fromLTWH(x * pxW, y * pxH, w * pxW, h * pxH),
      Paint()..color = color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawCeilingMolding(canvas);
    _drawWall(canvas);
    _drawBaseboard(canvas);
    _drawFloor(canvas);
    _drawWindow(canvas);
    _drawClock(canvas);
    _drawMiniCalendar(canvas);
    _drawBulletinBoard(canvas);
    _drawSofaRug(canvas);
  }

  void _drawCeilingMolding(Canvas canvas) {
    _drawRect(canvas, ChallengeRoomColors.moldingTop, 0, 0, 32, 1);
    _drawRect(canvas, ChallengeRoomColors.baseboard, 0, 1, 32, 1);
  }

  void _drawWall(Canvas canvas) {
    _drawRect(canvas, wallTint, 0, 2, 32, 8);
    final shadow = Color.lerp(wallTint, ChallengeRoomColors.wallShadow, 0.5)!;
    _drawRect(canvas, shadow, 0, 10, 32, 2);
  }

  void _drawBaseboard(Canvas canvas) {
    _drawRect(canvas, ChallengeRoomColors.baseboard, 0, 12, 32, 1);
  }

  void _drawFloor(Canvas canvas) {
    // Horizontal wood grain stripes
    for (int y = 13; y < 24; y++) {
      final base = y.isEven
          ? ChallengeRoomColors.woodFloorLight
          : ChallengeRoomColors.woodFloorDark;
      _drawRect(canvas, base, 0, y, 32, 1);
      if (y % 3 == 0) {
        for (int x = 2; x < 32; x += 4) {
          _drawPx(canvas, ChallengeRoomColors.woodFloorGrain, x, y);
        }
      }
    }
  }

  void _drawWindow(Canvas canvas) {
    _drawRect(canvas, ChallengeRoomColors.windowFrame, 2, 3, 7, 6);
    _drawRect(canvas, ChallengeRoomColors.windowGlass, 3, 4, 5, 4);
    _drawRect(canvas, ChallengeRoomColors.skyBlue, 3, 4, 5, 2);
    _drawRect(canvas, ChallengeRoomColors.windowPane, 5, 4, 1, 4);
    _drawRect(canvas, ChallengeRoomColors.windowPane, 3, 6, 5, 1);
    _drawPx(canvas, ChallengeRoomColors.windowPane, 4, 5);
    _drawPx(canvas, ChallengeRoomColors.windowPane, 7, 5);
    _drawRect(canvas, ChallengeRoomColors.windowFrame, 2, 8, 7, 1);
  }

  void _drawClock(Canvas canvas) {
    _drawRect(canvas, ChallengeRoomColors.clockFace, 17, 3, 3, 3);
    _drawPx(canvas, ChallengeRoomColors.woodDark, 17, 3);
    _drawPx(canvas, ChallengeRoomColors.woodDark, 19, 3);
    _drawPx(canvas, ChallengeRoomColors.woodDark, 17, 5);
    _drawPx(canvas, ChallengeRoomColors.woodDark, 19, 5);
    _drawPx(canvas, ChallengeRoomColors.clockHand, 18, 3);
    _drawPx(canvas, ChallengeRoomColors.clockHand, 18, 4);
    _drawPx(canvas, ChallengeRoomColors.clockHand, 19, 4);
  }

  void _drawMiniCalendar(Canvas canvas) {
    // Cols 11-17, rows 3-8: wood frame + white bg + date marker
    _drawRect(canvas, ChallengeRoomColors.woodDark, 11, 3, 7, 6);
    _drawRect(canvas, ChallengeRoomColors.calendarBg, 12, 4, 5, 4);
    _drawPx(canvas, ChallengeRoomColors.calendarRed, 14, 5);
    for (int c = 0; c < 5; c++) {
      if (c == 2) continue; // skip today
      _drawPx(canvas, ChallengeRoomColors.calendarText, 12 + c, 5);
      _drawPx(canvas, ChallengeRoomColors.calendarText, 12 + c, 6);
    }
  }

  void _drawBulletinBoard(Canvas canvas) {
    _drawRect(canvas, ChallengeRoomColors.corkBoard, 20, 3, 11, 7);
    _drawRect(canvas, ChallengeRoomColors.corkBoardDark, 20, 3, 11, 1);
    _drawRect(canvas, ChallengeRoomColors.corkBoardDark, 20, 9, 11, 1);
    _drawPx(canvas, ChallengeRoomColors.pinRed, 21, 4);
    _drawPx(canvas, ChallengeRoomColors.pinYellow, 29, 4);
    _drawPx(canvas, ChallengeRoomColors.pinRed, 21, 8);
    _drawPx(canvas, ChallengeRoomColors.pinYellow, 29, 8);
    _drawRect(canvas, ChallengeRoomColors.memoWhite, 22, 4, 3, 4);
    _drawRect(canvas, ChallengeRoomColors.memoBlue, 26, 5, 3, 3);
  }

  void _drawSofaRug(Canvas canvas) {
    // Rug
    _drawRect(canvas, const Color(0xFFF8BBD0), 8, 20, 16, 3);
    _drawRect(canvas, const Color(0xFFF48FB1), 9, 21, 14, 1);
    // Sofa
    _drawRect(canvas, ChallengeRoomColors.woodLight, 9, 17, 14, 3);
    _drawRect(canvas, ChallengeRoomColors.woodDark, 9, 19, 14, 1);
    _drawPx(canvas, ChallengeRoomColors.woodDark, 16, 17);
    _drawPx(canvas, ChallengeRoomColors.woodDark, 16, 18);
    _drawRect(canvas, ChallengeRoomColors.woodDark, 9, 16, 1, 4);
    _drawRect(canvas, ChallengeRoomColors.woodDark, 22, 16, 1, 4);
  }

  @override
  bool shouldRepaint(_ChallengeRoomBackgroundPainter old) =>
      old.wallTint != wallTint;
}

// ─── Summary Badge ─────────────────────────────────────────────────────────

class _SummaryBadge extends StatelessWidget {
  final int verifiedCount;
  final int totalCount;

  const _SummaryBadge({
    required this.verifiedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Text(
        '$verifiedCount/$totalCount명 인증',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: verifiedCount == totalCount
              ? ChallengeRoomColors.verifiedGreen
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
