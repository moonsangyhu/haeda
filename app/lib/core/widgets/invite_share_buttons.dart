import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';

class InviteShareButtons extends StatelessWidget {
  final String inviteCode;
  final String? challengeTitle;

  const InviteShareButtons({
    super.key,
    required this.inviteCode,
    this.challengeTitle,
  });

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 코드가 클립보드에 복사되었습니다.')),
      );
    }
  }

  Future<void> _shareViaKakao(BuildContext context) async {
    final isAvailable =
        await ShareClient.instance.isKakaoTalkSharingAvailable();

    if (!isAvailable) {
      await Clipboard.setData(ClipboardData(text: inviteCode));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('카카오톡이 설치되어 있지 않습니다. 초대 코드가 클립보드에 복사되었습니다.'),
          ),
        );
      }
      return;
    }

    final description = challengeTitle != null
        ? "'$challengeTitle' 챌린지에 초대합니다!\n초대 코드: $inviteCode"
        : '해다에서 함께 챌린지해요!\n초대 코드: $inviteCode';

    final template = FeedTemplate(
      content: Content(
        title: '해다 - 챌린지 초대',
        description: description,
        imageUrl: Uri.parse('https://haeda.app/og-image.png'),
        link: Link(
          webUrl: Uri.parse('https://haeda.app/invite/$inviteCode'),
          mobileWebUrl: Uri.parse('https://haeda.app/invite/$inviteCode'),
        ),
      ),
      buttons: [
        Button(
          title: '챌린지 참여하기',
          link: Link(
            webUrl: Uri.parse('https://haeda.app/invite/$inviteCode'),
            mobileWebUrl: Uri.parse('https://haeda.app/invite/$inviteCode'),
          ),
        ),
      ],
    );

    final uri =
        await ShareClient.instance.shareDefault(template: template);
    await ShareClient.instance.launchKakaoTalk(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          key: const Key('copy_code_button'),
          onPressed: () => _copyCode(context),
          icon: const Text('\u{1F4CB}', style: TextStyle(fontSize: 18)),
          label: const Text('코드 복사'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('kakao_share_button'),
          onPressed: () => _shareViaKakao(context),
          icon: const Text('\u{1F4AC}', style: TextStyle(fontSize: 18)),
          label: const Text('카카오톡으로 공유'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}
