import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../character/models/character_data.dart';
import '../../character/providers/character_provider.dart';
import '../models/verification_data.dart';
import '../providers/verification_provider.dart';

/// 렌더링 대상 유저가 현재 로그인 유저면 myCharacterProvider의 라이브 상태를,
/// 그렇지 않으면 응답에 임베드된 character를 사용한다.
/// 캐릭터 샵에서 외형을 바꾼 직후에도 인증 화면이 최신 외형을 보여준다.
CharacterData? _resolveCharacter(
  WidgetRef ref,
  String renderedUserId,
  CharacterData? embedded,
) {
  final myId = ref.watch(authStateProvider).valueOrNull?.id;
  if (myId != null && myId == renderedUserId) {
    final mine = ref.watch(myCharacterProvider).valueOrNull;
    if (mine != null) return mine;
  }
  return embedded;
}

class VerificationDetailScreen extends ConsumerWidget {
  final String verificationId;

  const VerificationDetailScreen({super.key, required this.verificationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(verificationDetailProvider(verificationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('인증 상세'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: detailAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, _) => AppErrorWidget(
          error: error,
          onRetry: () =>
              ref.invalidate(verificationDetailProvider(verificationId)),
        ),
        data: (detail) => _buildBody(context, detail),
      ),
    );
  }

  Widget _buildBody(BuildContext context, VerificationDetail detail) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AuthorSection(detail: detail),
        const SizedBox(height: 16),
        if (detail.photoUrls != null && detail.photoUrls!.isNotEmpty) ...[
          _PhotoSection(photoUrls: detail.photoUrls!),
          const SizedBox(height: 16),
        ],
        _DiarySection(diaryText: detail.diaryText),
      ],
    );
  }
}

class _AuthorSection extends ConsumerWidget {
  final VerificationDetail detail;

  const _AuthorSection({required this.detail});

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return '${parsed.year}년 ${parsed.month}월 ${parsed.day}일';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = detail.user;
    final character = _resolveCharacter(ref, user.id, user.character);

    return Row(
      children: [
        CharacterAvatar(
          character: character,
          size: 48,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.nickname,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _formatDate(detail.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoSection extends StatefulWidget {
  final List<String> photoUrls;

  const _PhotoSection({required this.photoUrls});

  @override
  State<_PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends State<_PhotoSection> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          widget.photoUrls.first,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: Icon(Icons.broken_image, size: 48)),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 200,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      );
    }

    // Multiple images — PageView with dot indicators
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.photoUrls.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  widget.photoUrls[index],
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 48),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.photoUrls.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == _currentPage
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiarySection extends StatelessWidget {
  final String diaryText;

  const _DiarySection({required this.diaryText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      diaryText,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        height: 1.6,
      ),
    );
  }
}
