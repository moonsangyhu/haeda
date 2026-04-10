import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/season_icons.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/verification_data.dart';
import '../providers/calendar_provider.dart';
import '../providers/challenge_detail_provider.dart';
import '../providers/verification_provider.dart';
import '../../my_page/providers/my_challenges_provider.dart';
import '../../status_bar/providers/user_stats_provider.dart';

class CreateVerificationScreen extends ConsumerStatefulWidget {
  final String challengeId;
  final String? date; // YYYY-MM-DD, null이면 오늘

  const CreateVerificationScreen({
    super.key,
    required this.challengeId,
    this.date,
  });

  @override
  ConsumerState<CreateVerificationScreen> createState() =>
      _CreateVerificationScreenState();
}

class _CreateVerificationScreenState
    extends ConsumerState<CreateVerificationScreen> {
  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return '${parsed.month}월 ${parsed.day}일';
    } catch (_) {
      return dateStr;
    }
  }

  final _diaryController = TextEditingController();
  final List<({XFile file, Uint8List bytes})> _selectedPhotos = [];
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _diaryController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final remaining = 3 - _selectedPhotos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최대 3장까지 가능합니다.')),
      );
      return;
    }
    final photos = await _imagePicker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
      limit: remaining,
    );
    if (photos.isNotEmpty) {
      final toAdd = photos.take(remaining);
      for (final photo in toAdd) {
        final bytes = await photo.readAsBytes();
        _selectedPhotos.add((file: photo, bytes: bytes));
      }
      setState(() {});
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<void> _submit(bool photoRequired) async {
    final diaryText = _diaryController.text.trim();
    if (diaryText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일기를 입력해주세요.')),
      );
      return;
    }

    final notifier =
        ref.read(verificationSubmitProvider(widget.challengeId).notifier);
    final result = await notifier.submit(
      diaryText: diaryText,
      photos: _selectedPhotos
          .map((p) => (bytes: p.bytes.toList(), fileName: p.file.name))
          .toList(),
      date: widget.date,
    );

    if (!mounted) return;

    if (result != null) {
      _showSuccessDialog(result);
    } else {
      final state = ref.read(verificationSubmitProvider(widget.challengeId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage ?? '인증 제출에 실패했습니다.')),
      );
    }
  }

  void _showSuccessDialog(VerificationCreateResult result) {
    final targetDate = widget.date != null
        ? DateTime.parse(widget.date!)
        : DateTime.now();
    final calendarParams = CalendarParams(
      challengeId: widget.challengeId,
      year: targetDate.year,
      month: targetDate.month,
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('인증 완료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (result.dayCompleted) ...[
              Text(
                '${SeasonIcons.getIcon(result.seasonIconType)} 오늘 모두가 인증했어요!',
                style: Theme.of(dialogContext).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '달력이 ${SeasonIcons.getIcon(result.seasonIconType)}으로 바뀌었어요!',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ] else
              const Text('달력에 내 썸네일이 추가됐어요!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // 달력 및 일별 인증 데이터 갱신 후 뒤로가기
              ref.invalidate(calendarProvider(calendarParams));
              if (widget.date != null) {
                ref.invalidate(dailyVerificationsProvider(
                  DailyVerificationParams(
                    challengeId: widget.challengeId,
                    date: widget.date!,
                  ),
                ));
              }
              ref.invalidate(myChallengesProvider);
              ref.invalidate(userStatsProvider);
              context.pop();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(challengeDetailProvider(widget.challengeId));
    final submitState =
        ref.watch(verificationSubmitProvider(widget.challengeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.date != null
            ? '${_formatDate(widget.date!)} 인증 작성'
            : '인증 작성'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: detailAsync.when(
        loading: () => const LoadingWidget(),
        error: (_, __) => const Center(child: Text('챌린지 정보를 불러올 수 없습니다.')),
        data: (detail) => _CreateVerificationBody(
          photoRequired: detail.photoRequired,
          photoBytesList: _selectedPhotos.map((p) => p.bytes).toList(),
          diaryController: _diaryController,
          isLoading: submitState.isLoading,
          onPickPhoto: _pickPhoto,
          onRemovePhoto: _removePhoto,
          onSubmit: () => _submit(detail.photoRequired),
        ),
      ),
    );
  }
}

class _CreateVerificationBody extends StatelessWidget {
  final bool photoRequired;
  final List<Uint8List> photoBytesList;
  final TextEditingController diaryController;
  final bool isLoading;
  final VoidCallback onPickPhoto;
  final void Function(int) onRemovePhoto;
  final VoidCallback onSubmit;

  const _CreateVerificationBody({
    required this.photoRequired,
    required this.photoBytesList,
    required this.diaryController,
    required this.isLoading,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    required this.onSubmit,
  });

  bool get _canSubmit {
    if (isLoading) return false;
    if (photoRequired && photoBytesList.isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 사진 추가 영역 — 항상 3칸 표시
          LayoutBuilder(
            builder: (context, constraints) {
              final boxSize = (constraints.maxWidth - 16) / 3;
              return Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    if (i < photoBytesList.length)
                      // 이미지가 있는 칸
                      SizedBox(
                        width: boxSize,
                        height: boxSize,
                        child: Stack(
                          children: [
                            GestureDetector(
                              onTap: isLoading ? null : onPickPhoto,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  photoBytesList[i],
                                  width: boxSize,
                                  height: boxSize,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap:
                                    isLoading ? null : () => onRemovePhoto(i),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // 빈 칸
                      GestureDetector(
                        onTap: isLoading ? null : onPickPhoto,
                        child: Container(
                          width: boxSize,
                          height: boxSize,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 32,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${i + 1}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            photoRequired ? '사진 필수 (최대 3장)' : '사진 선택 (최대 3장)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: photoRequired
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // 일기 입력
          Text(
            '오늘의 일기',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: diaryController,
            maxLines: 5,
            maxLength: 1000,
            enabled: !isLoading,
            decoration: InputDecoration(
              hintText: '오늘의 인증 내용을 자유롭게 적어주세요.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 제출 버튼
          ElevatedButton(
            onPressed: _canSubmit ? onSubmit : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('제출하기'),
          ),
        ],
      ),
    );
  }
}
