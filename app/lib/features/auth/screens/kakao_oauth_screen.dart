import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';
import '../../../core/api/api_exception.dart';

class KakaoConfig {
  static const appKey = String.fromEnvironment(
    'KAKAO_APP_KEY',
    defaultValue: 'KAKAO_APP_KEY_NOT_SET',
  );
  static const redirectUri = 'https://haeda.app/auth/kakao/callback';
}

class KakaoOAuthScreen extends ConsumerStatefulWidget {
  const KakaoOAuthScreen({super.key});

  @override
  ConsumerState<KakaoOAuthScreen> createState() => _KakaoOAuthScreenState();
}

class _KakaoOAuthScreenState extends ConsumerState<KakaoOAuthScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: _handleNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(_buildAuthUrl()));
  }

  String _buildAuthUrl() {
    return 'https://kauth.kakao.com/oauth/authorize'
        '?response_type=token'
        '&client_id=${KakaoConfig.appKey}'
        '&redirect_uri=${Uri.encodeComponent(KakaoConfig.redirectUri)}';
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final url = request.url;
    if (url.startsWith(KakaoConfig.redirectUri) &&
        url.contains('access_token=')) {
      _processCallback(url);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _processCallback(String url) async {
    final uri = Uri.parse(url);
    // 카카오는 access_token을 URL fragment에 넣어서 반환
    final fragment = uri.fragment;
    final params = Uri.splitQueryString(fragment);
    final accessToken = params['access_token'];

    if (accessToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오 로그인에 실패했습니다.')),
        );
      }
      return;
    }

    try {
      final user = await ref
          .read(authStateProvider.notifier)
          .loginWithKakao(accessToken);
      if (!mounted) return;
      if (user.isNew) {
        context.go('/profile-setup');
      } else {
        context.go('/my-page');
      }
    } on Exception catch (e) {
      if (!mounted) return;
      String message = '로그인 중 오류가 발생했습니다.';
      if (e is ApiException) {
        message = e.message;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('카카오 로그인'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
