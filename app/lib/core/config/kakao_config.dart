class KakaoConfig {
  static const appKey = String.fromEnvironment(
    'KAKAO_APP_KEY',
    defaultValue: 'KAKAO_APP_KEY_NOT_SET',
  );
  static const nativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: 'KAKAO_NATIVE_APP_KEY_NOT_SET',
  );
  static const redirectUri = 'https://haeda.app/auth/kakao/callback';
}
