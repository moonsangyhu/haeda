import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'app.dart';
import 'core/config/kakao_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(nativeAppKey: KakaoConfig.nativeAppKey);
  runApp(const ProviderScope(child: HaedaApp()));
}
