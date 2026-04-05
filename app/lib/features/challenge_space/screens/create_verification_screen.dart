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
  XFile? _selectedPhoto;
  Uint8List? _photoBytes;
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _diaryController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        _selectedPhoto = photo;
        _photoBytes = bytes;
      });
    }
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
      photoBytes: _photoBytes,
      photoFileName: _selectedPhoto?.name,
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
        leading: const BackButton(),
      ),
      body: detailAsync.when(
        loading: () => const LoadingWidget(),
        error: (_, __) => const Center(child: Text('챌린지 정보를 불러올 수 없습니다.')),
        data: (detail) => _CreateVerificationBody(
          photoRequired: detail.photoRequired,
          photoBytes: _photoBytes,
          diaryController: _diaryController,
          isLoading: submitState.isLoading,
          onPickPhoto: _pickPhoto,
          onSubmit: () => _submit(detail.photoRequired),
        ),
      ),
    );
  }
}

class _CreateVerificationBody extends StatelessWidget {
  final bool photoRequired;
  final Uint8List? photoBytes;
  final TextEditingController diaryController;
  final bool isLoading;
  final VoidCallback onPickPhoto;
  final VoidCallback onSubmit;

  const _CreateVerificationBody({
    required this.photoRequired,
    required this.photoBytes,
    required this.diaryController,
    required this.isLoading,
    required this.onPickPhoto,
    required this.onSubmit,
  });

  bool get _canSubmit {
    if (isLoading) return false;
    if (photoRequired && photoBytes == null) return false;
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
          // 사진 추가 영역
          GestureDetector(
            onTap: isLoading ? null : onPickPhoto,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 1,
                ),
              ),
              child: photoBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        photoBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _PhotoPlaceholder(
                          hasPhoto: true,
                        ),
                      ),
                    )
                  : _PhotoPlaceholder(
                      hasPhoto: false,
                      isRequired: photoRequired,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            photoRequired ? '사진 필수' : '사진 선택 (선택 사항)',
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
                borderRadius: BorderRadius.circular(8),
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

class _PhotoPlaceholder extends StatelessWidget {
  final bool hasPhoto;
  final bool isRequired;

  const _PhotoPlaceholder({
    required this.hasPhoto,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          hasPhoto ? Icons.check_circle_outline : Icons.add_a_photo_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Text(
          hasPhoto ? '사진 변경' : '사진 추가',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (isRequired && !hasPhoto) ...[
          const SizedBox(height: 4),
          Text(
            '(필수)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
