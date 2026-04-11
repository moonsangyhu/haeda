import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../character/models/character_data.dart';
import '../../character/providers/character_provider.dart';
import '../models/comment_data.dart';
import '../providers/comment_provider.dart';
import '../providers/verification_provider.dart';

/// 렌더링 대상 유저가 현재 로그인 유저면 myCharacterProvider의 라이브 상태를,
/// 그렇지 않으면 응답에 임베드된 character를 사용한다.
/// 캐릭터 샵에서 외형을 바꾼 직후에도 인증/댓글 화면이 최신 외형을 보여준다.
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

class VerificationDetailScreen extends ConsumerStatefulWidget {
  final String verificationId;

  const VerificationDetailScreen({super.key, required this.verificationId});

  @override
  ConsumerState<VerificationDetailScreen> createState() =>
      _VerificationDetailScreenState();
}

class _VerificationDetailScreenState
    extends ConsumerState<VerificationDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(verificationDetailProvider(widget.verificationId));

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
              ref.invalidate(verificationDetailProvider(widget.verificationId)),
        ),
        data: (detail) => _buildBody(context, detail),
      ),
    );
  }

  Widget _buildBody(BuildContext context, VerificationDetail detail) {
    final submitState =
        ref.watch(commentSubmitProvider(widget.verificationId));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AuthorSection(detail: detail),
              const SizedBox(height: 16),
              if (detail.photoUrls != null && detail.photoUrls!.isNotEmpty) ...[
                _PhotoSection(photoUrls: detail.photoUrls!),
                const SizedBox(height: 16),
              ],
              _DiarySection(diaryText: detail.diaryText),
              const Divider(height: 32),
              _CommentsSection(comments: detail.comments),
            ],
          ),
        ),
        _CommentInputBar(
          controller: _commentController,
          isLoading: submitState.isLoading,
          errorMessage: submitState.errorMessage,
          onSend: () => _onSendComment(),
        ),
      ],
    );
  }

  Future<void> _onSendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final notifier =
        ref.read(commentSubmitProvider(widget.verificationId).notifier);
    final success = await notifier.submit(content);
    if (success) {
      _commentController.clear();
      final detail =
          ref.read(verificationDetailProvider(widget.verificationId)).value;
      ref.invalidate(verificationDetailProvider(widget.verificationId));
      if (detail != null) {
        ref.invalidate(dailyVerificationsProvider(
          DailyVerificationParams(
            challengeId: detail.challengeId,
            date: detail.date,
          ),
        ));
      }
    }
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

class _CommentsSection extends StatelessWidget {
  final List<CommentItem> comments;

  const _CommentsSection({required this.comments});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '댓글 ${comments.length}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                '첫 댓글을 남겨보세요.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...comments.map((comment) => _CommentItemTile(comment: comment)),
      ],
    );
  }
}

class _CommentItemTile extends ConsumerWidget {
  final CommentItem comment;

  const _CommentItemTile({required this.comment});

  String _formatTime(String createdAt) {
    try {
      final parsed = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(parsed);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '${diff.inDays}일 전';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final author = comment.author;
    final character = _resolveCharacter(ref, author.id, author.character);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CharacterAvatar(
            character: character,
            size: 32,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      author.nickname,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(comment.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
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

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSend;

  const _CommentInputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.errorContainer,
              child: Text(
                errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      hintText: '댓글을 입력하세요...',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                const SizedBox(width: 8),
                isLoading
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: onSend,
                        icon: const Text('💬', style: TextStyle(fontSize: 20)),
                        color: theme.colorScheme.primary,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
