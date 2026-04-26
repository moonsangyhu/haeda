import '../api/api_client.dart';

/// Backend 가 반환하는 `/uploads/...` 같은 상대경로를 절대 URL 로 변환한다.
/// 이미 http(s):// 로 시작하면 그대로 반환.
String mediaUrl(String pathOrUrl) {
  if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
    return pathOrUrl;
  }
  if (pathOrUrl.startsWith('/')) return '$apiOrigin$pathOrUrl';
  return '$apiOrigin/$pathOrUrl';
}
