import 'dart:async';

/// 防抖工具类
///
/// 用于延迟执行高频率触发的操作（如搜索输入）。
/// 在指定延迟时间内如果再次触发，则重新计时。
///
/// 使用示例：
/// ```dart
/// final debounce = Debounce(delay: const Duration(milliseconds: 500));
/// textField.onChanged = (value) => debounce.run(() => doSearch(value));
/// ```
class Debounce {
  final Duration delay;
  Timer? _timer;

  Debounce({required this.delay});

  /// 执行目标操作，若计时器已存在则先取消
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// 取消 pending 的计时器
  void cancel() {
    _timer?.cancel();
  }

  /// 释放资源
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
