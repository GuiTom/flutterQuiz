import 'dart:async';

import 'package:flutter/material.dart';

/// ============================================================
/// 第八章：错误日志收集
/// ============================================================
///
/// 一个线上 App 最尴尬的状态不是"有 bug"，而是"用户崩了你不知道"。
/// Flutter 的异常分好几种，它们走的通道**互不相同**——只装一个
/// `FlutterError.onError`，你能看到的可能还不到全部崩溃的一半。
///
/// 本页内容：
/// 一、总览：一次崩溃，四条通道
/// 二、实验：4 种异常，试试 try/catch 到底能抓到几个
/// 三、实验：build 里抛错，为什么 Zone 抓不到
/// 四、main() 里该怎么接线（可直接抄的代码）
/// 五、上报链路：崩溃时进程快死了，日志怎么发出去
/// 六、符号化：为什么线上堆栈还原不出方法名
/// 七、常见坑 + 三条通道对照表
class ErrorCapturePage extends StatelessWidget {
  const ErrorCapturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('错误日志收集'),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _OverviewCard(),
          SizedBox(height: 16),
          _ChannelCard(),
          SizedBox(height: 16),
          _LabCard(),
          SizedBox(height: 16),
          _BuildErrorCard(),
          SizedBox(height: 16),
          _WireUpCard(),
          SizedBox(height: 16),
          _ReportCard(),
          SizedBox(height: 16),
          _SymbolCard(),
          SizedBox(height: 16),
          _TrapCard(),
          SizedBox(height: 16),
          _CompareCard(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================
// 配色常量
// ============================================================

const Color _kNeutral = Color(0xFF3D5A80);
const Color _kGood = Color(0xFF2E7D32);
const Color _kWarn = Color(0xFF9A6700);
const Color _kBad = Color(0xFFC62828);

// ============================================================
// 一、总览
// ============================================================

class _OverviewCard extends StatelessWidget {
  const _OverviewCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('先记住一句话：一次崩溃，四条通道'),
          SizedBox(height: 8),
          Text(
            'Flutter 没有"全局异常钩子"这种东西。异常按它被抛出的位置，'
            '分别落到不同的兜底点。少装一个通道，就少看见一整类崩溃。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 14),
          _PipelineStep(
            ordinal: '1',
            title: '框架同步异常 → FlutterError.onError',
            desc: 'build / layout / paint 里抛的错，Flutter 自己 try 住了，'
                '交给 FlutterError 分发，然后把子树换成 ErrorWidget（红屏）。'
                '**它不会跑到 Zone，也不会跑到 PlatformDispatcher。**',
            color: Color(0xFF3D5A80),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '2',
            title: '未捕获的异步异常 → PlatformDispatcher.onError',
            desc: '没人 await 的 Future、Timer 回调、addPostFrameCallback 里抛的错。'
                'Flutter 3.3 之后这是官方推荐的兜底点，'
                '**它的返回值决定 App 会不会被杀掉**。',
            color: Color(0xFF5C6BC0),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '3',
            title: 'Zone 内异常 → runZonedGuarded',
            desc: '历史做法，把 runApp 整个包进一个错误 Zone。'
                '3.3 之后**不再推荐**，而且它和上面两条会互相打架（见第七节）。',
            color: Color(0xFF9A6700),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '4',
            title: '原生崩溃 → Dart 侧一律看不见',
            desc: 'OOM、JNI 崩溃、插件里 native 层的野指针、系统杀进程。'
                '这些必须靠原生 SDK（Bugly / Firebase / Sentry）采集，'
                '**Dart 代码在进程死之前根本没机会执行**。',
            color: _kBad,
          ),
          SizedBox(height: 14),
          _TipRow(
            icon: Icons.lightbulb_outline,
            text: '所以"接了崩溃收集"和"接全了"是两件事。'
                '判断标准很简单：你能不能在后台看到"某个页面 build 报错"这一条？'
                '看不到，说明第 1 条通道没接。',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 二、三条通道的分工
// ============================================================

class _ChannelCard extends StatelessWidget {
  const _ChannelCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('通道的分工：谁管谁'),
          SizedBox(height: 8),
          _BulletLine(
            'FlutterError.onError —— 只管"Flutter 框架主动 try 住"的那些同步异常。'
            '典型来源：widget build 抛错、RenderObject 布局断言、手势回调里的断言。',
          ),
          _BulletLine(
            'PlatformDispatcher.instance.onError —— 只管"逃逸到事件循环"的异步错误。'
            '典型来源：未 await 的 Future、Future.delayed 回调、Stream 未监听的错误。',
          ),
          _BulletLine(
            'ErrorWidget.builder —— 它不是收集通道，只决定"红屏长什么样"。'
            '但它能兜住 UI：把崩溃范围限制在那一个子树，而不是整页白屏。',
          ),
          _BulletLine(
            'Isolate 里抛的错 —— root isolate 的 onError 抓不到别的 isolate。'
            'compute / Isolate.spawn 里的异常必须自己捕获后传回来，'
            '否则它只会打印一行然后让那个 isolate 静默死掉。',
          ),
          SizedBox(height: 12),
          _CodeHint(
            '// Isolate 里的异常必须自己搬出来\n'
            'final result = await compute(parseBigJson, raw);   // ✅ compute 会自动把错误抛回\n\n'
            '// 自己 spawn 的 isolate 就要手动传\n'
            'final port = ReceivePort();\n'
            'port.listen((msg) {\n'
            '  if (msg is List && msg.length == 2) {\n'
            '    reportError(msg[0] as Object, msg[1] as StackTrace);   // ✅ 手动上报\n'
            '  }\n'
            '});\n'
            'await Isolate.spawn(worker, port.sendPort);',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 三、实验：4 种异常，try/catch 能抓到几个
// ============================================================

typedef _ScenarioBody = FutureOr<void> Function();

class _Scenario {
  const _Scenario({
    required this.name,
    required this.hint,
    required this.run,
  });

  final String name;
  final String hint;
  final _ScenarioBody run;
}

final List<_Scenario> _scenarios = <_Scenario>[
  _Scenario(
    name: '① 同步 throw',
    hint: '发生在当前同步栈里，await 不 await 都能抓到。',
    run: () {
      throw StateError('sync boom');
    },
  ),
  _Scenario(
    name: '② await 后 throw',
    hint: 'throw 发生在 50ms 后，原来的同步栈早就没了；'
        '是 await 把 Future 的错误重新抛在 try 块内的挂起点，才抓得到。',
    run: () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      throw StateError('awaited boom');
    },
  ),
  _Scenario(
    name: '③ 未 await 的 Future',
    hint: '没人 await，错误在事件循环里变成"未捕获异步错误"。',
    run: () {
      Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
        throw StateError('orphan boom');
      });
    },
  ),
  _Scenario(
    name: '④ 定时回调里 throw',
    hint: '回调早已脱离原来的调用栈，try/catch 早就执行完了。',
    run: () {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        throw StateError('timer boom');
      });
    },
  ),
];

class _LabCard extends StatefulWidget {
  const _LabCard();

  @override
  State<_LabCard> createState() => _LabCardState();
}

class _LabCardState extends State<_LabCard> {
  bool _useTryCatch = false;
  bool _disposed = false;
  final List<_LogEntry> _logs = <_LogEntry>[];

  void _add(String scene, String text, Color color) {
    if (_disposed) {
      return;
    }
    setState(() {
      _logs.insert(
        0,
        _LogEntry(scene: scene, text: text, color: color),
      );
    });
  }

  void _clear() {
    setState(_logs.clear);
  }

  void _run(_Scenario scenario) {
    // 这里用 runZonedGuarded 扮演"全局兜底"的角色：
    // 它的 onError 收到的就是「逃逸到事件循环、没人处理的错误」，
    // 和 PlatformDispatcher.instance.onError 站的是同一个位置。
    runZonedGuarded(
      () async {
        if (_useTryCatch) {
          try {
            await scenario.run();
            _add(scenario.name, 'try/catch：没等到任何异常', _kWarn);
          } catch (error) {
            _add(scenario.name, 'try/catch 捕获：$error', _kGood);
          }
        } else {
          await scenario.run();
          _add(scenario.name, '同步调用正常返回，没抛', _kWarn);
        }
      },
      (Object error, StackTrace stack) {
        _add(scenario.name, '全局兜底捕获：$error', _kNeutral);
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验：4 种异常，try/catch 能抓到几个'),
          const SizedBox(height: 8),
          const Text(
            '打开/关闭下面的开关，然后逐个点按钮。'
            '注意看 ③④ —— 即使开着 try/catch，日志里也只有"没等到任何异常"，'
            '真正的错误要等 50ms 后才被兜底收到。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '调用处用 try/catch 包裹',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              Switch(
                value: _useTryCatch,
                onChanged: (bool value) =>
                    setState(() => _useTryCatch = value),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final _Scenario scenario in _scenarios)
                ActionChip(
                  avatar: const Icon(Icons.play_arrow, size: 16),
                  label: Text(scenario.name),
                  onPressed: () => _run(scenario),
                ),
              ActionChip(
                avatar: const Icon(Icons.clear_all, size: 16),
                label: const Text('清空日志'),
                onPressed: _logs.isEmpty ? null : _clear,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final _Scenario scenario in _scenarios)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${scenario.name} ${scenario.hint}',
                style: const TextStyle(fontSize: 11.5, height: 1.5),
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            '"同步栈"到底断没断 —— 看堆栈就知道：',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const _CodeHint(
            '// ① 同步 throw：真实调用栈，帧与帧之间连续\n'
            '#0  syncCase      ← throw 在这里\n'
            '#1  onPressed     ← 一直挂在同一个栈上\n'
            '#2  main\n'
            '#3  _RawReceivePort._handleMessage\n'
            '\n'
            '// ② await 后 throw：栈断了，靠挂起链拼回来\n'
            '#0  awaitedCase\n'
            '<asynchronous suspension>          ← 分界线\n'
            '#1  onPressed                      ← 是重建出来的，不是还在栈上\n'
            '<asynchronous suspension>',
          ),
          const SizedBox(height: 8),
          const _TipRow(
            icon: Icons.info_outline,
            text: '所以 ② 的 try/catch 能抓到，不是因为"还在同步栈里"，'
                '而是因为 await 把 Future 的错误重新抛在了 try 块内的挂起点。'
                '一旦跨了 Isolate 边界、或回调由 C++ 侧直接发起，这条挂起链就断了 —— '
                '别指望堆栈，路由等上下文必须上报时自己带（见第六节）。',
          ),
          const SizedBox(height: 12),
          _buildLogArea(),
        ],
      ),
    );
  }

  Widget _buildLogArea() {
    if (_logs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          '点上面的按钮，观察日志',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black38),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (final _LogEntry entry in _logs) _LogRow(entry: entry),
        ],
      ),
    );
  }
}

class _LogEntry {
  const _LogEntry({
    required this.scene,
    required this.text,
    required this.color,
  });

  final String scene;
  final String text;
  final Color color;
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final _LogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: entry.color, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.scene,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.text,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: entry.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 四、build 异常：Zone 抓不到
// ============================================================

class _BuildErrorCard extends StatelessWidget {
  const _BuildErrorCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('build 里抛错：一条独立的通道'),
          const SizedBox(height: 8),
          const Text(
            'widget 的 build 是由框架调用的，框架在 ComponentElement 里'
            '已经 try 住了 —— 所以这类异常**永远不会**逃逸到 Zone 或 '
            'PlatformDispatcher，只会走 FlutterError.onError。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          _CodeHint(
            '// framework 内部（简化）\n'
            'try {\n'
            '  built = build();                       // ← 你写的 build\n'
            '} catch (e, stack) {\n'
            '  FlutterError.reportError(...);         // → FlutterError.onError\n'
            '  built = ErrorWidget.builder(details);  // → 红屏\n'
            '}',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _ThrowingPage(),
                  ),
                );
              },
              icon: const Icon(Icons.warning_amber_rounded, size: 18),
              label: const Text('制造一次 build 异常'),
            ),
          ),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.info_outline,
            text: '点进去你会看到：只有那一块子树变成红屏，页面其它部分照常工作，'
                'App 也没崩。这正是 ErrorWidget 的价值 —— 把崩溃范围限制在最小子树。'
                '但代价是：如果你没接 FlutterError.onError，这次崩溃**一条日志都不会有**。',
          ),
        ],
      ),
    );
  }
}

class _ThrowingPage extends StatelessWidget {
  const _ThrowingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('build 异常演示'),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('↑ 上面的 AppBar 是正常的，只有下面这块崩了'),
            SizedBox(height: 16),
            _BoomWidget(),
          ],
        ),
      ),
    );
  }
}

class _BoomWidget extends StatelessWidget {
  const _BoomWidget();

  @override
  Widget build(BuildContext context) {
    throw StateError('boom in build');
  }
}

// ============================================================
// 五、main() 该怎么接线
// ============================================================

class _WireUpCard extends StatelessWidget {
  const _WireUpCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('main() 里该怎么接线（可直接抄）'),
          SizedBox(height: 8),
          _CodeHint(
            'void main() async {\n'
            '  // 1. 在 main 里做任何 await 之前，必须先初始化绑定\n'
            '  WidgetsFlutterBinding.ensureInitialized();\n'
            '\n'
            '  // 2. 通道一：框架同步异常（build / layout / paint）\n'
            '  FlutterError.onError = (FlutterErrorDetails details) {\n'
            '    // debug 下保留红屏，release 下只上报不弹\n'
            '    if (kDebugMode) {\n'
            '      FlutterError.presentError(details);\n'
            '    } else {\n'
            '      Zone.current.handleUncaughtError(\n'
            '        details.exception, details.stack ?? StackTrace.empty);\n'
            '    }\n'
            '    CrashReporter.report(details.exception, details.stack,\n'
            '        fatal: false, type: \'framework\');\n'
            '  };\n'
            '\n'
            '  // 3. 通道二：逃逸到事件循环的异步错误\n'
            '  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {\n'
            '    CrashReporter.report(error, stack, fatal: true, type: \'async\');\n'
            '    return true;   // ← 必须返回 true，表示"我处理了"\n'
            '  };\n'
            '\n'
            '  // 4. 红屏兜底：让线上用户看到一个体面的错误页\n'
            '  ErrorWidget.builder = (FlutterErrorDetails details) =>\n'
            '      kDebugMode ? ErrorWidget(details) : const _CrashPlaceholder();\n'
            '\n'
            '  // 5. 上次没发出去的日志，趁这次启动补发\n'
            '  unawaited(CrashReporter.flushPending());\n'
            '\n'
            '  runApp(const MyApp());\n'
            '}',
          ),
          SizedBox(height: 12),
          _TipRow(
            icon: Icons.priority_high,
            text: '第 3 步的 return true 是整段代码里最关键的一行。'
                '返回 false 等于告诉框架"没人处理"，框架会把它当致命错误直接杀掉进程 —— '
                '你上报了日志，但 App 还是崩了，且比不接还糟。',
          ),
          SizedBox(height: 8),
          _TipRow(
            icon: Icons.bug_report_outlined,
            text: '第 2 步里 release 分支把异常再丢回 Zone，是为了让 '
                'PlatformDispatcher.onError 也能收到一份，'
                '这样上报逻辑可以只写一处。不这么做也行，但别两个地方都上报（会重复计数）。',
          ),
          SizedBox(height: 12),
          _CodeHint(
            '// ❌ 这是 3.3 之前的写法，现在不要再抄\n'
            'runZonedGuarded(() async {\n'
            '  WidgetsFlutterBinding.ensureInitialized();\n'
            '  runApp(const MyApp());\n'
            '}, (error, stack) {\n'
            '  report(error, stack);\n'
            '});\n'
            '\n'
            '// 问题：Zone 会拦下 FlutterError 本该走的分发，\n'
            '// 导致 FlutterError.onError 收不到东西，红屏兜底也失效。',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 六、上报链路
// ============================================================

class _ReportCard extends StatelessWidget {
  const _ReportCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('上报链路：崩溃时进程快死了，日志怎么发得出去'),
          SizedBox(height: 8),
          Text(
            '这是新手最容易想错的地方：崩溃发生的那一刻，'
            '你**不可能**把日志发到服务器 —— 网络请求至少要几百毫秒，'
            '而进程可能几十毫秒后就没了。所以正确做法是「先落地，下次再发」。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 14),
          _PipelineStep(
            ordinal: '1',
            title: '同步写本地，不要发网络',
            desc: '崩溃回调里只做一件事：把 错误 + 堆栈 + 上下文 序列化，'
                '同步 append 到本地文件（或 shared_preferences）。'
                '这一步必须快，不能 await 任何东西。',
            color: Color(0xFF3D5A80),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '2',
            title: '下次启动补发',
            desc: 'App 启动后读本地队列，批量上报，成功一条删一条。'
                '失败走指数退避重试，超过 N 次或超过 7 天就丢弃。',
            color: Color(0xFF5C6BC0),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '3',
            title: '去重 + 采样 + 限流',
            desc: '按「异常类型 + 堆栈前 3 帧」算 hash 去重；'
                '同一个 hash 只保留计数和首次/末次时间。'
                '再叠加采样率（比如 30%）和单端单日上限，避免刷爆后台。',
            color: Color(0xFF9A6700),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '4',
            title: '带上足够的上下文',
            desc: '光有堆栈没用。至少要带：机型 / 系统版本 / App 版本 / '
                'Flutter 版本 / 构建号 / 用户 id / 当前路由 / 网络类型 / '
                '可用内存 / 磁盘剩余 / 前后台状态。',
            color: Color(0xFF2E7D32),
          ),
          SizedBox(height: 14),
          _TipRow(
            icon: Icons.privacy_tip_outlined,
            text: '上下文里很容易夹带敏感信息（用户手机号、URL 参数、日志里的 token）。'
                '上报前必须脱敏，尤其是自定义日志和 HTTP 错误里的 request body。',
          ),
          SizedBox(height: 12),
          _CodeHint(
            '// 去重键：只取前 3 帧，避免行号/地址抖动导致去重失效\n'
            'String _fingerprint(Object error, StackTrace? stack) {\n'
            '  final List<String> frames = (stack?.toString() ?? \'\')\n'
            '      .split(\'\\n\').take(3).toList();\n'
            '  return \'\${error.runtimeType}|\${frames.join(\'|\')}\';\n'
            '}\n'
            '\n'
            '// 队列落地：同步写，绝不 await\n'
            'void _persist(Map<String, dynamic> event) {\n'
            '  final File file = File(\'\${_dir.path}/crash_queue.jsonl\');\n'
            '  file.writeAsStringSync(\'\${jsonEncode(event)}\\n\',\n'
            '      mode: FileMode.append, flush: true);\n'
            '}',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 七、符号化
// ============================================================

class _SymbolCard extends StatelessWidget {
  const _SymbolCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('符号化：为什么线上堆栈全是 <optimized out>'),
          SizedBox(height: 8),
          Text(
            'Release 包做了混淆和裁剪，堆栈里的 Dart 方法名会被替换成短符号。'
            '想还原，必须在**构建时**把符号文件导出来并归档 —— '
            '这一步忘了，事后没有任何办法补救。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 12),
          _CodeHint(
            '# 构建时导出符号（必须和产物一起归档！）\n'
            'flutter build apk --release \\\n'
            '  --obfuscate \\\n'
            '  --split-debug-info=build/symbols\n'
            '\n'
            '# 还原堆栈\n'
            'flutter symbolize \\\n'
            '  -i crash_stack.txt \\\n'
            '  -d build/symbols/app.android-arm64.symbols',
          ),
          SizedBox(height: 12),
          _BulletLine(
            '--obfuscate 负责混淆名字，--split-debug-info 负责把映射表导出。'
            '两个必须一起用，只用前者等于把钥匙扔了。',
          ),
          _BulletLine(
            '符号文件和构建产物**一一对应**：每次发版都要归档，'
            '并且要用构建号（build number）标记清楚，否则线上多版本并行时会对不上。',
          ),
          _BulletLine(
            'iOS 除了 Dart 符号，还要处理原生 dSYM。'
            '原生崩溃（OOM、SIGSEGV）必须靠 dSYM 还原，Dart 符号文件管不了。',
          ),
          _BulletLine(
            'Web / 桌面平台的符号化机制不一样，不要照搬移动端流程。',
          ),
          SizedBox(height: 12),
          _TipRow(
            icon: Icons.warning_amber_outlined,
            text: '一个很常见的翻车现场：CI 里没配 --split-debug-info，'
                '上线后才发现堆栈全是地址。这时候除了重新发一版，没有别的办法。',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 八、常见坑
// ============================================================

class _TrapCard extends StatelessWidget {
  const _TrapCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('常见坑速查'),
          SizedBox(height: 10),
          _TrapRow(
            scene: 'PlatformDispatcher.onError 忘记 return true',
            symptom: '日志上报了，但 App 照样闪退，而且比不接还难排查。',
            solution: '必须显式 return true 表示"已处理"；'
                '返回 false 框架会认定为致命错误并杀进程。',
          ),
          _TrapRow(
            scene: '只装了 FlutterError.onError',
            symptom: '异步错误（未 await 的 Future、Timer 回调）一条都收不到。',
            solution: '两条通道都要装：FlutterError.onError + '
                'PlatformDispatcher.instance.onError。',
          ),
          _TrapRow(
            scene: '只装了 PlatformDispatcher.onError',
            symptom: 'widget build 里的报错一条都收不到，但用户看到了红屏。',
            solution: 'build 异常走的是 FlutterError.onError，两条都要装。',
          ),
          _TrapRow(
            scene: '还在用 runZonedGuarded 包 runApp',
            symptom: 'FlutterError.onError 收不到东西，ErrorWidget 兜底也失效。',
            solution: 'Flutter 3.3 之后改用 PlatformDispatcher.instance.onError，'
                '不要再包 Zone。',
          ),
          _TrapRow(
            scene: '崩溃回调里发网络请求',
            symptom: '请求根本发不出去，或者写到一半进程就被杀了。',
            solution: '只做同步本地写入，下次启动再补发。',
          ),
          _TrapRow(
            scene: '崩溃回调里做耗时同步 IO',
            symptom: '主线程被卡住，本来能恢复的 ANR 变成真崩溃。',
            solution: '单条日志控制在几 KB，append 写，不要遍历整个队列。',
          ),
          _TrapRow(
            scene: 'ErrorWidget.builder 里又抛异常',
            symptom: '无限递归，App 直接卡死或白屏。',
            solution: '兜底 widget 必须是"不可能崩"的纯静态 UI，'
                '里面不要读 context、不要访问状态。',
          ),
          _TrapRow(
            scene: 'main 里 await 之前没初始化绑定',
            symptom: 'ServicesBinding 未初始化，访问插件/平台通道直接抛错。',
            solution: 'main 第一行写 WidgetsFlutterBinding.ensureInitialized()。',
          ),
          _TrapRow(
            scene: '只在 debug 下测试崩溃收集',
            symptom: 'debug 和 release 的异常行为完全不同，线上还是收不到。',
            solution: '必须用 flutter run --release 或真机打 release 包验证。',
          ),
          _TrapRow(
            scene: 'release 包没带符号文件',
            symptom: '后台堆栈全是地址或 <optimized out>，无法定位。',
            solution: '构建时 --obfuscate --split-debug-info 并归档符号文件，'
                '按构建号一一对应。',
            last: true,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 九、对照表
// ============================================================

class _CompareCard extends StatelessWidget {
  const _CompareCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('三条通道 + 两个盲区，一张表看清'),
          SizedBox(height: 10),
          _CompareTable(
            headers: <String>['通道', '捕获范围', '典型来源', '备注'],
            rows: <List<String>>[
              <String>[
                'FlutterError.onError',
                '框架 try 住的同步异常',
                'build / layout / paint 抛错、断言失败',
                '不接就一条日志都没有',
              ],
              <String>[
                'PlatformDispatcher\n.onError',
                '逃逸到事件循环的异步错误',
                '未 await 的 Future、Timer 回调、Stream 错误',
                '3.3+ 官方推荐；必须 return true',
              ],
              <String>[
                'ErrorWidget.builder',
                '不收集，只管 UI 长相',
                'build 失败时替换子树',
                '兜住红屏范围，避免整页白屏',
              ],
              <String>[
                'runZonedGuarded',
                'Zone 内所有未捕获异常',
                '历史方案',
                '已不推荐，会和上面两条打架',
              ],
              <String>[
                '原生 SDK',
                'Dart 侧完全看不见的崩溃',
                'OOM、JNI、native 野指针、系统杀进程',
                'Bugly / Firebase / Sentry 原生侧接入',
              ],
              <String>[
                'Isolate 内部',
                '别的 isolate 的异常',
                'compute / Isolate.spawn 里的错误',
                'root isolate 抓不到，必须手动传回',
              ],
            ],
          ),
          SizedBox(height: 12),
          _TipRow(
            icon: Icons.checklist,
            text: '自检清单：build 报错能看到吗？未 await 的 Future 报错能看到吗？'
                '原生 OOM 能看到吗？三条都能看到，才算接全了。',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 通用小组件（与第七章保持一致的样式）
// ============================================================

Widget _card({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }
}

class _CodeHint extends StatelessWidget {
  const _CodeHint(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            height: 1.6,
            color: Color(0xFF3D5A80),
          ),
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('· ', style: TextStyle(fontSize: 13, height: 1.6)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.text});

  final IconData icon;

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(height: 1.6, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _PipelineStep extends StatelessWidget {
  const _PipelineStep({
    required this.ordinal,
    required this.title,
    required this.desc,
    required this.color,
  });

  final String ordinal;

  final String title;

  final String desc;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            ordinal,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrapRow extends StatelessWidget {
  const _TrapRow({
    required this.scene,
    required this.symptom,
    required this.solution,
    this.last = false,
  });

  final String scene;

  final String symptom;

  final String solution;

  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: last ? 0 : 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scene,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, size: 15, color: Colors.redAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  symptom,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 15, color: Colors.teal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  solution,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.headers, required this.rows});

  final List<String> headers;

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade200),
        columnWidths: <int, TableColumnWidth>{
          for (int i = 0; i < headers.length; i++)
            i: FixedColumnWidth(i == 0 ? 96 : 116),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: <TableRow>[
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF2F4F8)),
            children: <Widget>[
              for (final String header in headers) _cell(header, bold: true),
            ],
          ),
          for (final List<String> row in rows)
            TableRow(
              children: <Widget>[for (final String cell in row) _cell(cell)],
            ),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          height: 1.5,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
