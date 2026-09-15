import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// ============================================================
/// CrashReporter —— 一个"能真的跑起来"的最小崩溃上报实现
/// ============================================================
///
/// 对应第八章讲的几条链路，全部落成可以点的代码：
///   1. 两条官方通道的接线（FlutterError / PlatformDispatcher）
///   2. 崩溃回调里**只做同步写**，绝不 await、绝不发网络
///   3. 下次启动补发 + 指数退避 + TTL 丢弃
///   4. 指纹去重 / 采样 / 单端单日限流
///   5. 上下文（当前路由、系统信息）必须自己带
///
/// 整个文件**零第三方依赖**，方便你直接读。
/// 生产环境需要替换这四处（文件里都有 TODO 标注）：
///   · _resolveDir()      → path_provider
///   · _send()            → dio / http
///   · fingerprint()      → crypto 的 sha1
///   · context()          → device_info_plus / package_info_plus

/// 错误是从哪条通道进来的。
enum Channel {
  framework, // FlutterError.onError   （框架 try 住的同步异常）
  platform, // PlatformDispatcher.onError（逃逸到事件循环的异步错误）
  isolate, // 子 isolate 手动搬回来的
  manual, // 业务代码主动调用 report()
}

extension ChannelLabel on Channel {
  String get label {
    return switch (this) {
      Channel.framework => 'FlutterError.onError',
      Channel.platform => 'PlatformDispatcher.onError',
      Channel.isolate => 'Isolate 手动搬回',
      Channel.manual => '手动 report()',
    };
  }

  Color get color {
    return switch (this) {
      Channel.framework => const Color(0xFF3D5A80),
      Channel.platform => const Color(0xFF5C6BC0),
      Channel.isolate => const Color(0xFF2E7D32),
      Channel.manual => const Color(0xFF9A6700),
    };
  }
}

/// 一条"本该被上报、但因为没装通道而丢了"的错误。
/// 真实项目里它就是后台永远看不到的那些崩溃，这里专门列出来给你看。
class LostEvent {
  const LostEvent({
    required this.time,
    required this.channel,
    required this.type,
    required this.message,
  });

  final DateTime time;
  final Channel channel;
  final String type;
  final String message;
}

/// flush 的结果。
class FlushResult {
  const FlushResult({
    required this.sent,
    required this.failed,
    required this.total,
    required this.merged,
  });

  final int sent;
  final int failed;
  final int total;
  final int merged;

  @override
  String toString() =>
      '发送成功 $sent 条 / 失败 $failed 条（共 $total 条，去重后合并了 $merged 条）';
}

class CrashReporter {
  CrashReporter._();

  static final CrashReporter instance = CrashReporter._();

  // ============================================================
  // 可调参数
  // ============================================================

  /// 采样率：1.0 = 全量。大流量 App 一般 0.1 ~ 0.3。
  double sampleRate = 1.0;

  /// 单端单日上报上限，防止一个死循环把后台刷爆。
  int maxPerDay = 200;

  /// 一条日志最多重试几次，超过就丢弃。
  int maxRetry = 3;

  /// 日志最长存活时间，超过就丢弃（用户一个月没打开 App 就别补发了）。
  Duration ttl = const Duration(days: 7);

  /// 演示用：模拟"网络不可用"，让你看到补发失败 + 重试的完整过程。
  bool simulateNetworkFailure = false;

  /// 队列所在目录名。测试里改成带 pid 的名字，避免多个测试进程互相踩文件。
  String queueDirName = 'error_report_demo';

  // ============================================================
  // 内部状态
  // ============================================================

  /// 当前路由，由 [ReporterRouteObserver] 维护，上报时当上下文带上。
  String currentRoute = '/';

  File? _queueFile;
  bool _frameworkOn = false;
  bool _platformOn = false;

  final List<VoidCallback> _listeners = <VoidCallback>[];
  final List<LostEvent> _lost = <LostEvent>[];
  final List<Map<String, Object?>> _sent = <Map<String, Object?>>[];

  DateTime _today = DateTime.now();
  int _sentToday = 0;

  /// 已丢失的错误（倒序）。
  List<LostEvent> get lost => List<LostEvent>.unmodifiable(_lost);

  /// 已成功上报的事件（倒序）。
  List<Map<String, Object?>> get sent =>
      List<Map<String, Object?>>.unmodifiable(_sent);

  bool get frameworkOn => _frameworkOn;

  bool get platformOn => _platformOn;

  File? get queueFile => _queueFile;

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final VoidCallback listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  // ============================================================
  // 初始化与接线
  // ============================================================

  /// 必须在 runApp 之前调用，且必须在 [WidgetsFlutterBinding.ensureInitialized]
  /// 之后（因为要拿目录、要装 PlatformDispatcher 的钩子）。
  Future<void> init() async {
    final Directory dir = await _resolveDir();
    _queueFile = File('${dir.path}/crash_queue.jsonl');
    debugPrint('[CrashReporter] 队列文件: ${_queueFile!.path}');
  }

  /// TODO(生产): 换成 path_provider 的 getApplicationDocumentsDirectory()。
  /// 这里用系统临时目录，是为了让 demo 零依赖跑起来。
  Future<Directory> _resolveDir() async {
    final Directory dir = Directory('${Directory.systemTemp.path}/$queueDirName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// 安装/切换通道。演示"少装一条通道，就少看见一整类崩溃"。
  ///
  /// 注意 [PlatformDispatcher.instance.onError] 无论装不装都必须 return true ——
  /// 返回 false 等于告诉框架"没人处理"，框架会直接杀进程。
  void setChannels({
    required bool framework,
    required bool platform,
    required bool friendlyErrorWidget,
  }) {
    _frameworkOn = framework;
    _platformOn = platform;

    // ---- 通道一：框架 try 住的同步异常 ----
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        // presentError 是个静态**字段**，默认是 dumpErrorToConsole，
        // 不会递归回 onError。留着它，控制台才有输出。
        FlutterError.presentError(details);
      }
      if (_frameworkOn) {
        report(
          details.exception,
          details.stack,
          channel: Channel.framework,
          fatal: false,
        );
      } else {
        _drop(Channel.framework, details.exception, details.stack);
      }
    };

    // ---- 通道二：逃逸到事件循环的异步错误 ----
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (_platformOn) {
        report(error, stack, channel: Channel.platform, fatal: true);
      } else {
        _drop(Channel.platform, error, stack);
      }
      return true; // ← 这一行是整段代码里最关键的
    };

    // ---- 红屏兜底：它不收集，只决定用户看到什么 ----
    ErrorWidget.builder = friendlyErrorWidget
        ? (FlutterErrorDetails details) =>
            _FriendlyErrorBox(message: '${details.exception}')
        : (FlutterErrorDetails details) => ErrorWidget(details.exception);

    _notify();
  }

  // ============================================================
  // 上报入口
  // ============================================================

  /// 唯一的落地点。**这个方法里不能 await 任何东西。**
  void report(
    Object error,
    StackTrace? stack, {
    Channel channel = Channel.manual,
    bool fatal = false,
    Map<String, Object?>? extra,
  }) {
    _rollDayIfNeeded();

    if (!_hitSample()) {
      debugPrint('[CrashReporter] 采样未命中，丢弃: $error');
      return;
    }
    if (_sentToday >= maxPerDay) {
      debugPrint('[CrashReporter] 已达单日上限 $maxPerDay，丢弃: $error');
      return;
    }

    final Map<String, Object?> event = <String, Object?>{
      'v': 1,
      'ts': DateTime.now().toIso8601String(),
      'channel': channel.name,
      'type': error.runtimeType.toString(),
      'message': '$error',
      'fp': fingerprint(error, stack),
      // 堆栈截断：一条日志控制在几 KB，别把整个队列撑爆
      'stack': _trim(stack?.toString() ?? '', 24),
      'route': currentRoute,
      'fatal': fatal,
      'count': 1,
      'retry': 0,
      'ctx': context(),
      if (extra != null) 'extra': extra,
    };

    _persistSync(event);
    debugPrint('[CrashReporter] 已落地 <${channel.name}> $error');
    _notify();
  }

  /// 同步 append 写一行 JSONL。
  ///
  /// 这里是整个上报链路里唯一允许做 IO 的地方，而且必须是同步的：
  /// 崩溃回调执行时进程可能马上就被杀掉，任何 await 都等不到结果。
  void _persistSync(Map<String, Object?> event) {
    final File? file = _queueFile;
    if (file == null) {
      return;
    }
    try {
      file.writeAsStringSync(
        '${jsonEncode(event)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } on Object {
      // 连本地都写不进去（磁盘满 / 权限），只能放弃。
      // 注意：这里绝不能再抛异常，否则会把业务代码带崩。
    }
  }

  /// 指纹：异常类型 + 堆栈前 3 帧。
  ///
  /// 为什么只取前 3 帧？行号和地址每次构建都会抖，
  /// 取太多帧会导致同一类问题被拆成几十条，去重彻底失效。
  ///
  /// TODO(生产): demo 里用 hashCode 简化，生产环境请用 crypto 的 sha1，
  /// 因为 String.hashCode 不保证跨版本稳定。
  String fingerprint(Object error, StackTrace? stack) {
    final List<String> frames =
        (stack?.toString() ?? '').split('\n').take(3).toList();
    return '${error.runtimeType}|${frames.join('|')}'.hashCode
        .toRadixString(16);
  }

  /// 上报时自带的上下文。
  ///
  /// 为什么非要自己带？因为异步错误的堆栈里根本没有触发它的那一帧
  /// （见 demo 里"未 await 的 Future"那条的堆栈），光看堆栈你不知道用户在哪个页面。
  ///
  /// TODO(生产): 换成 device_info_plus + package_info_plus，
  /// 补上 App 版本、构建号、Flutter 版本、用户 id、网络类型。
  Map<String, Object?> context() {
    return <String, Object?>{
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'dart': Platform.version.split(' ').first,
      'locale': Platform.localeName,
      'route': currentRoute,
    };
  }

  static String _trim(String text, int maxLines) {
    final List<String> lines = text.split('\n');
    if (lines.length <= maxLines) {
      return text;
    }
    return '${lines.take(maxLines).join('\n')}\n... (已截断 ${lines.length - maxLines} 帧)';
  }

  bool _hitSample() {
    if (sampleRate >= 1.0) {
      return true;
    }
    return DateTime.now().microsecondsSinceEpoch % 1000 < sampleRate * 1000;
  }

  void _rollDayIfNeeded() {
    final DateTime now = DateTime.now();
    if (now.year != _today.year ||
        now.month != _today.month ||
        now.day != _today.day) {
      _today = now;
      _sentToday = 0;
    }
  }

  void _drop(Channel channel, Object error, StackTrace? stack) {
    _lost.insert(
      0,
      LostEvent(
        time: DateTime.now(),
        channel: channel,
        type: error.runtimeType.toString(),
        message: '$error',
      ),
    );
    _notify();
  }

  // ============================================================
  // 队列读取 / 补发 / 清空
  // ============================================================

  /// 读取本地队列。启动时和刷新 UI 时调用，可以同步。
  List<Map<String, Object?>> readQueue() {
    final File? file = _queueFile;
    if (file == null || !file.existsSync()) {
      return const <Map<String, Object?>>[];
    }
    try {
      return file
          .readAsStringSync()
          .split('\n')
          .where((String line) => line.trim().isNotEmpty)
          .map((String line) =>
              (jsonDecode(line) as Map<Object?, Object?>).cast<String, Object?>())
          .toList();
    } on Object {
      // 文件写坏了一行就整个队列读不出来？生产环境这里要做"逐行容错"，
      // 坏行跳过，别把好日志一起丢了。
      return const <Map<String, Object?>>[];
    }
  }

  /// 补发。App 启动时调一次，之后可以在网络恢复时再调。
  ///
  /// 流程：读队列 → 按指纹聚合去重 → 逐条发送 → 成功的删掉，
  /// 失败的 retry+1 并留在队列里（超过 maxRetry 或 ttl 就丢弃）。
  Future<FlushResult> flush() async {
    final List<Map<String, Object?>> all = readQueue();
    if (all.isEmpty) {
      return const FlushResult(sent: 0, failed: 0, total: 0, merged: 0);
    }

    // ---- 按指纹聚合：同一类问题只发一条，count 累加 ----
    final Map<String, Map<String, Object?>> merged = <String, Map<String, Object?>>{};
    for (final Map<String, Object?> event in all) {
      final String fp = event['fp'] as String? ?? '';
      final Map<String, Object?>? exist = merged[fp];
      if (exist == null) {
        merged[fp] = Map<String, Object?>.of(event);
      } else {
        exist['count'] = ((exist['count'] as int?) ?? 0) + 1;
      }
    }

    int ok = 0;
    int failed = 0;
    final List<Map<String, Object?>> remain = <Map<String, Object?>>[];

    for (final Map<String, Object?> event in merged.values) {
      // TTL：太老的日志没有分析价值，直接丢
      final DateTime ts =
          DateTime.tryParse(event['ts'] as String? ?? '') ?? DateTime.now();
      if (DateTime.now().difference(ts) > ttl) {
        continue;
      }

      final bool success = await _send(event);
      if (success) {
        ok++;
        _sentToday++;
        _sent.insert(0, Map<String, Object?>.of(event));
      } else {
        final int retry = ((event['retry'] as int?) ?? 0) + 1;
        if (retry > maxRetry) {
          continue; // 重试次数用尽，丢弃
        }
        event['retry'] = retry;
        remain.add(event);
        failed++;
      }
    }

    _rewrite(remain);
    _notify();
    return FlushResult(
      sent: ok,
      failed: failed,
      total: merged.length,
      merged: all.length - merged.length,
    );
  }

  /// TODO(生产): 换成真实的 HTTP 上报。这里用延迟 + 开关模拟成功/失败。
  Future<bool> _send(Map<String, Object?> event) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (simulateNetworkFailure) {
      debugPrint('[CrashReporter] 发送失败(模拟): ${event['message']}');
      return false;
    }
    debugPrint(
        '[CrashReporter] 发送成功 x${event['count']}: ${event['message']}');
    return true;
  }

  void _rewrite(List<Map<String, Object?>> events) {
    final File? file = _queueFile;
    if (file == null) {
      return;
    }
    final StringBuffer buffer = StringBuffer();
    for (final Map<String, Object?> event in events) {
      buffer.writeln(jsonEncode(event));
    }
    file.writeAsStringSync(buffer.toString(), flush: true);
  }

  void clearQueue() {
    final File? file = _queueFile;
    if (file != null && file.existsSync()) {
      file.writeAsStringSync('', flush: true);
    }
    _lost.clear();
    _sent.clear();
    _sentToday = 0;
    _notify();
  }
}

/// 记录当前路由，供上报时当上下文用。
///
/// 用法：MaterialApp(navigatorObservers: [ReporterRouteObserver()])
class ReporterRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _apply(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _apply(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _apply(previousRoute);

  void _apply(Route<dynamic>? route) {
    if (route == null) {
      return;
    }
    CrashReporter.instance.currentRoute =
        route.settings.name ?? route.runtimeType.toString();
  }
}

/// 线上给玩家看的兜底 UI。
///
/// 铁律：这个 widget **绝对不能抛异常**。
/// 不要读 context、不要访问任何状态、不要做网络请求 ——
/// 它一崩就是无限递归，直接白屏。
class _FriendlyErrorBox extends StatelessWidget {
  const _FriendlyErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.healing_outlined, color: Color(0xFFE65100)),
          const SizedBox(height: 6),
          const Text(
            '这块内容加载失败了',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
