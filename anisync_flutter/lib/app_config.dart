import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// 多环境 BaseUrl 配置
///
/// 各平台策略：
/// - Web:            当前页面 hostname（同源代理）
/// - Windows/macOS:  127.0.0.1（本机后端）
/// - Android 模拟器: 10.0.2.2（映射宿主机 localhost）
/// - Android 真机:   局域网 IP（见下方 [真机调试] 区域）
class AppConfig {
  // ┌─────────────────────────────────────────────────────────┐
  // │  真机调试时，将 _useEmulator 改为 false，               │
  // │  并把 _lanIp 改为你电脑的局域网 IP（如 192.168.1.5）。  │
  // │  查看方法: 终端执行 ipconfig / ifconfig                  │
  // └─────────────────────────────────────────────────────────┘
  static const bool _useEmulator = true;
  static const String _lanIp = '192.168.1.100';

  static const int port = 8080;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$port';
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'http://127.0.0.1:$port';
    }
    if (Platform.isAndroid) {
      // 模拟器: 10.0.2.2 映射宿主机 localhost
      // 真机:   使用局域网 IP（需修改 _useEmulator 和 _lanIp）
      final host = _useEmulator ? '10.0.2.2' : _lanIp;
      return 'http://$host:$port';
    }
    // 其他平台 fallback
    return 'http://$_lanIp:$port';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
