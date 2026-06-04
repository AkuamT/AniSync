import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// 多环境 BaseUrl 配置
/// - Web: 使用当前页面的 hostname（同源代理）
/// - Windows 本地调试: 127.0.0.1
/// - Android 模拟器: 10.0.2.2
/// - 真机/局域网: 可手动配置
class AppConfig {
  // 手动配置局域网 IP（真机调试时修改此项）
  static const String _lanIp = '192.168.1.100';
  static const int port = 8080;

  static String get baseUrl {
    // Web 平台走同源代理或当前 host
    if (kIsWeb) {
      return 'http://127.0.0.1:$port';
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'http://127.0.0.1:$port';
    }
    if (Platform.isAndroid) {
      // Android 模拟器映射宿主机 localhost
      return 'http://10.0.2.2:$port';
    }
    // 其他平台（真机等）使用局域网 IP
    return 'http://$_lanIp:$port';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
