import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

/// ============================================================
/// 线程模型（Thread Model）学习 Demo
/// ============================================================
///
/// 核心结论先摆在这：**Dart 只有一个线程在跑你的代码**。
/// 所谓「异步」不是开了新线程，而是把任务排进队列，由事件循环轮流执行；
/// 真正能并行的只有一件事 —— 开一个新的 isolate。
///
/// 本页四块内容：
/// 一、事件循环：同步栈 → microtask 队列 → event 队列，三级优先级
/// 二、阻塞实验：主 isolate 忙等 vs 丢给后台 isolate，看动画有没有卡住
/// 三、显式 Isolate：SendPort / ReceivePort 通信，以及「内存不共享」
/// 四、概念澄清：Flutter 引擎的四个线程，以及 isolate 和线程不是一回事
class ThreadModelPage extends StatefulWidget {
  const ThreadModelPage({super.key});

  @override
  State<ThreadModelPage> createState() => _ThreadModelPageState();
}

// ============================================================
// 一、演示用的函数（isolate 入口必须顶层 / 静态）
// ============================================================

/// 模拟一次「计算密集型」任务。
///
/// 先用忙等占用 [ms] 毫秒（纯同步 while，不让出事件循环，等价于一段 CPU 硬算），
/// 再顺势算出 1..n 的和返回。
///
/// 它在哪个 isolate 上被调用，就占满哪个 isolate 的事件循环 ——
/// 所以同一个函数，放主线程会卡 UI，放后台 isolate 就没事。
///
/// 返回 record `(实际耗时 ms, 累加结果)`。
(int, int) _heavyTask((int, int) args) {
  final (int ms, int n) = args;
  final Stopwatch stopwatch = Stopwatch()..start();
  // 忙等：一个纯同步循环，谁跑它谁就被占住
  while (stopwatch.elapsedMilliseconds < ms) {
    // 故意什么都不做，就是不放控制权
  }
  int sum = 0;
  for (int i = 1; i <= n; i++) {
    sum += i;
  }
  return (stopwatch.elapsedMilliseconds, sum);
}

/// 演示「isolate 之间内存不共享」用的全局变量。
///
/// 每个 isolate 都持有它自己的这份副本：子 isolate 把它改成 true，
/// 主 isolate 读到的仍然是 false。
bool _mainIsolateFlag = false;

/// 显式 isolate 的入口函数。
///
/// 必须是**顶层函数或静态方法** —— 不能传闭包 / 实例方法，
/// 因为它们带着对主 isolate 里对象的引用，跨 isolate 发送时会直接报错。
///
/// 入口只能收一个参数，所以要传多个东西时打包成 record / List / Map 都行；
/// 想把结果送回去，就在参数里带一个 [SendPort]。
void _isolateEntry(SendPort replyTo) async {
  const int steps = 8;
  int sum = 0;
  replyTo.send('子 isolate 启动（它有自己的内存和事件循环）');

  for (int i = 1; i <= steps; i++) {
    // 子 isolate 也能 await —— 它有自己的事件循环，不会拖住主 isolate
    await Future<void>.delayed(const Duration(milliseconds: 320));
    sum += i * i;
    replyTo.send('第 $i 步 → 累计 $sum');
  }

  // 改的是**子 isolate 自己的**那份全局变量，主 isolate 看不到
  _mainIsolateFlag = true;
  replyTo.send('子 isolate 里 _mainIsolateFlag = $_mainIsolateFlag');

  replyTo.send(sum); // 最后发一个 int 代表最终结果
}

// ============================================================
// 二、轨迹日志
// ============================================================

/// 记录执行轨迹的小容器。
///
/// 线程 / 事件循环的行为看不见摸不着，只能靠「打印执行点」来观察 ——
/// 代码里打一行 trace，UI 上就看到到底轮到谁跑了。
class _Trace extends ChangeNotifier {
  final List<String> _lines = <String>[];

  bool _disposed = false;

  List<String> get lines => List<String>.unmodifiable(_lines);

  void add(String line) {
    // 页面销毁后，迟到的异步 / isolate 回调还会往这里写，直接丢掉
    if (_disposed) return;
    _lines.insert(0, line);
    if (_lines.length > 200) _lines.removeLast();
    notifyListeners();
  }

  void clear() {
    if (_disposed) return;
    _lines.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ============================================================
// 三、页面
// ============================================================

class _ThreadModelPageState extends State<ThreadModelPage>
    with SingleTickerProviderStateMixin {
  // ---------- 实验一：事件循环顺序 ----------
  final _Trace _loopTrace = _Trace();

  List<String> _loopOrder = <String>[];

  String _loopStatus = '还没跑。点上面按钮，看「同步 → 微任务 → 事件」这个顺序。';

  // ---------- 实验二：阻塞主 isolate vs 后台 isolate ----------
  final _Trace _blockTrace = _Trace();

  /// 一直转的圆环 —— 它就是 UI 有没有卡住的「体温计」。
  late final AnimationController _spinner;

  /// 动画每走一帧就 +1，用来量化「主线程还有没有空画帧」。
  final ValueNotifier<int> _frames = ValueNotifier<int>(0);

  bool _blockRunning = false;

  String _blockStatus =
      '先盯住圆环在转，再分别用「主线程」和「后台 isolate」跑同一段重计算。';

  // ---------- 实验三：显式 Isolate ----------
  final _Trace _isolateTrace = _Trace();

  Isolate? _worker;

  ReceivePort? _workerPort;

  bool _flagTouched = false;

  String _isolateStatus = '还没启动。点「spawn 一个后台 isolate」，看进度消息逐条回来。';

  @override
  void initState() {
    super.initState();
    _spinner = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _spinner.addListener(() {
      // 只有主线程有空渲染这一帧，动画才会前进 —— 这就是心跳
      _frames.value++;
    });
  }

  @override
  void dispose() {
    _stopWorker();
    _spinner.dispose();
    _frames.dispose();
    _loopTrace.dispose();
    _blockTrace.dispose();
    _isolateTrace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('线程模型')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntro(),
          const SizedBox(height: 16),
          _buildEventLoopSection(),
          const SizedBox(height: 16),
          _buildBlockSection(),
          const SizedBox(height: 16),
          _buildIsolateSection(),
          const SizedBox(height: 16),
          _buildEngineThreadSection(),
          const SizedBox(height: 16),
          _buildTrapSection(),
          const SizedBox(height: 16),
          _buildCheatSheet(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 概念
  // ----------------------------------------------------------
  Widget _buildIntro() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('为什么「单线程」也能异步？'),
          SizedBox(height: 8),
          Text(
            'Dart 是「单线程 + 事件循环（Event Loop）」模型。'
            '你写下的所有 Dart 代码 —— 包括 async/await 拆出来的每一段 —— '
            '都在同一个线程上排队执行。所谓异步，只是把任务排进队列，'
            '由事件循环一项一项取出来跑。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 10),
          _BulletLine('事件循环一次只做一件事：取一个任务 → 跑完 → 再取下一个'),
          _BulletLine('异步 = 排队，不是并行；await 让出的是「当前函数的执行权」，不是线程'),
          _BulletLine('想真正并行（多核同时算）只有一条路：开一个新的 isolate'),
          SizedBox(height: 16),
          _SectionTitle('一次事件循环的三级梯队'),
          SizedBox(height: 10),
          _PipelineStep(
            ordinal: '1',
            title: '同步栈 —— 当前正在跑的那段代码',
            desc: '事件循环绝不会打断它。所以一段死循环能把整个 UI 冻住，'
                '因为后面的微任务、事件、帧调度全排在了它后面。',
            color: Color(0xFF3D5A80),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '2',
            title: 'microtask 队列 —— 清空它才继续',
            desc: 'Future.microtask / scheduleMicrotask / await 之后的续跑都进这里。'
                '优先级高于 event 队列，而且会一直清到空为止 —— '
                '在里面无限再排微任务，会饿死 event 队列。',
            color: Color(0xFF5C6BC0),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '3',
            title: 'event 队列 —— 常规事件',
            desc: 'Future(...)、Timer、I/O、手势、绘制帧、其他 isolate 发来的消息都在这里。'
                '每取一个 event 之前，事件循环都会先把 microtask 清空。',
            color: Color(0xFF2E7D32),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 实验一：事件循环顺序
  // ----------------------------------------------------------
  Widget _buildEventLoopSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验一：三支队伍的出场顺序'),
          const SizedBox(height: 8),
          const Text(
            '下面同时排两个微任务、两个普通事件，中间再插一行同步代码。'
            '点按钮看结果 —— 同步代码永远第一，接着清空微任务，最后才是普通事件。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            r'''scheduleMicrotask(() => print('M1'));   // microtask 队列
Future.microtask(()    => print('M2'));   // microtask 队列
Future(()              => print('E1'));   // event 队列
Future(()              => print('E2'));   // event 队列
print('S1');                              // 同步代码，立刻跑

// 输出：S1 → M1 → M2 → E1 → E2''',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _runEventLoopOrder,
                icon: const Icon(Icons.playlist_play, size: 16),
                label: const Text('跑一次，看输出顺序'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _loopTrace.clear();
                  setState(() {
                    _loopOrder = <String>[];
                    _loopStatus = '已清空。再点一次看完整顺序。';
                  });
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statusRow(_loopStatus),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final String tag in _loopOrder)
                Chip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.indigo.withValues(alpha: 0.10),
                  side: BorderSide(color: Colors.indigo.withValues(alpha: 0.3)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '调度轨迹（最新的在最上面）',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _TracePanel(trace: _loopTrace, height: 176, empty: '还没跑'),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.lightbulb_outline,
            text: '顺序背后只有一条规则：事件循环在取下一个 event 之前，'
                '一定会把 microtask 队列清空。'
                '所以 await 之后的代码总是「插队」到普通事件之前 —— '
                '这也解释了为什么大量 await 连起来的代码，会把帧调度一直往后拖。'
                '另外记住：这三支队伍的活全都在同一个线程上，'
                '排得再花哨也不会变快，只是排队方式不同。',
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 实验二：阻塞 vs 后台 isolate
  // ----------------------------------------------------------
  Widget _buildBlockSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验二：阻塞主 isolate vs 交给后台 isolate'),
          const SizedBox(height: 8),
          const Text(
            '同一个「重计算」任务放在两个地方跑：一是直接在主 isolate 上同步跑，'
            '二是用 compute() 丢到后台 isolate。看下面这个圆环 —— '
            '它就是 UI 有没有卡住的体温计。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          _buildHeartbeat(),
          const SizedBox(height: 12),
          const _CodeHint(
            r'''// ① 直接在主 isolate 上同步跑：UI 会被冻住
final result = _heavyTask((1200, 1000000));   // 这 1.2 秒一帧都画不出来

// ② 丢给后台 isolate：UI 照常刷新
final result = await compute(_heavyTask, (1200, 1000000));''',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _blockRunning ? null : _runOnMainThread,
                icon: const Icon(Icons.warning_amber_rounded, size: 16),
                label: const Text('① 主线程同步跑 1.2s'),
              ),
              FilledButton.icon(
                onPressed: _blockRunning ? null : _runOnIsolate,
                icon: const Icon(Icons.rocket_launch, size: 16),
                label: const Text('② compute() 丢后台'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statusRow(_blockStatus),
          const SizedBox(height: 12),
          const Text(
            '轨迹',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _TracePanel(trace: _blockTrace, height: 140, empty: '还没跑'),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.insights_outlined,
            text: '两种写法的结果一模一样，差别只在「谁被占用」：\n'
                '· 主线程跑：这 1.2 秒里渲染 0 帧，动画停转、点击无响应 —— '
                '用户体感就是「App 卡死了」。\n'
                '· compute()：算的是同一段代码，但跑在另一个 isolate 上，'
                '主 isolate 只等结果回来，帧照画。\n'
                '注意 compute 不是零成本：每次调用都要新建 isolate、传参、回传结果。'
                '几十毫秒以内的小任务反而更慢，常驻 worker 才划算。',
          ),
        ],
      ),
    );
  }

  /// 「体温计」：转动的小圆环 + 累计渲染帧数。
  Widget _buildHeartbeat() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: RotationTransition(
              turns: _spinner,
              child: const Icon(
                Icons.autorenew,
                size: 40,
                color: Color(0xFF3D5A80),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UI 心跳（圆环在转 = 主线程还有空画帧）',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<int>(
                  valueListenable: _frames,
                  builder: (BuildContext context, int frames, Widget? child) {
                    return Text(
                      '累计渲染 $frames 帧 —— 按钮按下后如果数字不再涨，说明主线程被占住了',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: Colors.black54,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 实验三：显式 Isolate
  // ----------------------------------------------------------
  Widget _buildIsolateSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验三：显式 Isolate + 双端口通信'),
          const SizedBox(height: 8),
          const Text(
            'compute() 是隐式调用（框架帮你 spawn、收结果、kill）。'
            '想自己掌控生命周期、想持续回传进度，就用 '
            'Isolate.spawn + ReceivePort / SendPort。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            r'''// 主 isolate：开一个收信口，把「寄信地址」交给子 isolate
final ReceivePort reply = ReceivePort();
final Isolate worker = await Isolate.spawn(_entry, reply.sendPort);
reply.listen((msg) => print('收到：$msg'));

// 子 isolate 的入口（必须是顶层函数或静态方法）
void _entry(SendPort replyTo) async {
  for (int i = 1; i <= 8; i++) {
    await Future.delayed(const Duration(milliseconds: 320));
    replyTo.send('第 $i 步');   // 只能发「可复制」的对象
  }
  replyTo.send(sum);           // 最终结果
}''',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _spawnWorker,
                icon: const Icon(Icons.hub_outlined, size: 16),
                label: const Text('spawn 一个后台 isolate'),
              ),
              OutlinedButton.icon(
                onPressed: _stopWorkerPressed,
                icon: const Icon(Icons.stop_circle_outlined, size: 16),
                label: const Text('kill 掉'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statusRow(_isolateStatus),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
            ),
            child: Text(
              _flagTouched
                  ? '主 isolate 里读 _mainIsolateFlag = $_mainIsolateFlag'
                        ' —— 子 isolate 那边已经把它改成 true 了，这边却看不到。'
                        '这就是「内存不共享」最直接的证据。'
                  : '主 isolate 里读 _mainIsolateFlag = $_mainIsolateFlag'
                        '（跑完实验后子 isolate 会去改它，但主 isolate 不受影响）',
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '消息轨迹',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _TracePanel(trace: _isolateTrace, height: 170, empty: '还没收到消息'),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.insights_outlined,
            text: '三个必须记住的限制：\n'
                '· 内存不共享：每个 isolate 有自己的堆和全局变量，'
                '上面那行 _mainIsolateFlag 就是证据。'
                '要共享数据只有两条路 —— 传消息（会复制）或用 '
                'TransferableTypedData / Isolate.exit 搬运大块二进制。\n'
                '· 消息要「可发送」：num / String / bool / null / List / Map / '
                'record / SendPort 都可以；闭包、含 native 资源的对象会被拒绝。\n'
                '· 入口只能是顶层函数或静态方法，不能传实例方法 / 闭包。',
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 概念澄清：引擎的线程
  // ----------------------------------------------------------
  Widget _buildEngineThreadSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('澄清：Isolate ≠ 线程，Flutter 引擎有自己的线程'),
          SizedBox(height: 8),
          Text(
            'Dart 的 isolate 是「语言层面的并发单元」：独立内存 + 独立事件循环。'
            '它跑在哪个 OS 线程上是 VM 的事（通常来自线程池）。'
            '而 Flutter 引擎在原生侧有一组固定线程，各管一段：',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 14),
          _EngineThreadRow(
            thread: 'Platform Thread',
            role: '原生主线程',
            desc: '处理平台消息、插件回调、PlatformView。Dart 的 main isolate 通常也在这里跑。',
          ),
          _EngineThreadRow(
            thread: 'UI Thread',
            role: 'Dart 逻辑',
            desc: '执行你的 Dart 代码：build / layout / 生成绘制指令（Layer Tree）。卡在这里 = 掉帧。',
          ),
          _EngineThreadRow(
            thread: 'Raster Thread',
            role: 'GPU 光栅化',
            desc: '把绘制指令交给 GPU 合成上屏。卡在这里同样掉帧，但你的 Dart 代码是无辜的。',
          ),
          _EngineThreadRow(
            thread: 'IO Thread',
            role: 'IO 任务',
            desc: '图片解码、文件读写等。所以 Image 解码不会阻塞 UI。',
            last: true,
          ),
          SizedBox(height: 14),
          _SectionTitle('记住这三句'),
          SizedBox(height: 10),
          _BulletLine('你的 Dart 代码 = main isolate = 跑在 UI 线程上，一次只能专心做一件事'),
          _BulletLine('等 IO（网络 / 文件）不会占用它 —— 那是非阻塞调用 + 事件循环在干活'),
          _BulletLine('真正耗 CPU 的活（解析大 JSON、加解密、图像处理）必须下放到新 isolate'),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 陷阱
  // ----------------------------------------------------------
  Widget _buildTrapSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('线程模型相关的坑速查'),
          SizedBox(height: 6),
          Text(
            '这些全是面试会问、写代码会真咬人的地方。',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          SizedBox(height: 14),
          _TrapRow(
            scene: '在 main isolate 里做重计算（大 JSON 解析、加解密、图像处理）',
            symptom: 'UI 卡死几秒，动画停转、点击无响应，单帧耗时远超 16ms',
            solution: '下放到 isolate：一次性任务用 compute()，要进度 / 要复用用 Isolate.spawn。'
                '目标是把单帧耗时压回 16ms 以内。',
          ),
          _TrapRow(
            scene: '以为 await 会「开一个新线程」去跑',
            symptom: 'await 之后代码顺序变了，但耗时操作依然卡 UI',
            solution: 'await 只是把控制权交还事件循环，CPU 工作仍然在同一个 isolate 上。'
                'IO 类操作天然非阻塞；CPU 密集操作必须用 isolate。',
          ),
          _TrapRow(
            scene: 'Isolate.spawn 传了实例方法或闭包',
            symptom: 'ArgumentError: Illegal argument in isolate message',
            solution: '入口必须是顶层函数或 static 方法。需要参数就打包成对象 / record 传进去，'
                '需要回传就顺带传一个 SendPort。',
          ),
          _TrapRow(
            scene: '往 SendPort 里发闭包、含 native 资源的对象',
            symptom: 'Invalid argument(s): Illegal argument in isolate message',
            solution: '只能发「可复制的值」：num / String / bool / null / List / Map / '
                'record / SendPort 等。大块二进制用 TransferableTypedData，避免整份拷贝。',
          ),
          _TrapRow(
            scene: 'spawn 之后忘了 kill / 忘了 close(ReceivePort)',
            symptom: '后台 isolate 一直活着，内存缓慢上涨；页面退出后还在跑',
            solution: '用完 Isolate.kill()，并 close 掉 ReceivePort；在 dispose 里统一清理。',
          ),
          _TrapRow(
            scene: '把 compute() 用在几十毫秒以内的小任务上，或高频循环调用',
            symptom: '总耗时反而更高，甚至比同步跑还慢',
            solution: 'spawn isolate 本身就有毫秒级开销。任务太小就别开，'
                '或者常驻一个 worker isolate 复用（靠 SendPort 长期通信）。',
          ),
          _TrapRow(
            scene: '在 isolate 里期待共享内存 / 修改全局变量生效',
            symptom: '改了全局变量，另一边读到的还是旧值',
            solution: 'isolate 之间内存完全隔离，全局变量是各自一份副本。'
                '要共享只能传消息，或改用 Isolate.exit / TransferableTypedData 这类搬运手段。',
          ),
          _TrapRow(
            scene: '在微任务里无限再排微任务',
            symptom: 'event 队列被饿死，Timer、手势、绘制长时间得不到执行',
            solution: '事件循环会「清空」微任务队列才处理 event。'
                '递归排微任务必须加终止条件，或改用 Timer / Future 让出到 event 队列。',
            last: true,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 对照表
  // ----------------------------------------------------------
  Widget _buildCheatSheet() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('三种「异步」手段对照'),
          SizedBox(height: 10),
          _CompareTable(
            headers: <String>['', 'await / Future', 'compute()', 'Isolate.spawn'],
            rows: <List<String>>[
              <String>['并行吗', '不并行，只是让出', '真并行', '真并行'],
              <String>['开新线程', '不会', '会（框架代管）', '会（自己管）'],
              <String>['内存', '共享', '隔离', '隔离'],
              <String>['通信方式', '直接改对象', '传参 + 返回值', 'SendPort / ReceivePort 双向'],
              <String>['进度回传', '可以（分段 await）', '不行（一次一个结果）', '可以，随手 send'],
              <String>['开销', '极低', '每次新建，偏高', '可控，可复用'],
              <String>['适合场景', 'IO、等待、纯异步', '一次性重计算', '常驻 worker、流式进度'],
            ],
          ),
          SizedBox(height: 14),
          _SectionTitle('决策顺序'),
          SizedBox(height: 8),
          _BulletLine('第一步：这件事是「等外部结果」还是「占 CPU 硬算」？只是等 → await 就够了'),
          _BulletLine('第二步：占 CPU、一次性、只要最终结果 → compute()'),
          _BulletLine('第三步：占 CPU、要进度 / 要复用 / 要双向通信 → Isolate.spawn + 端口'),
          _BulletLine(
            '任何情况下都别把长任务写在主 isolate 上 —— 16ms 的帧预算经不起一次 1 秒的忙等',
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 交互辅助
  // ----------------------------------------------------------

  Widget _statusRow(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.6,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  // ---------- 实验一 ----------

  void _runEventLoopOrder() {
    _loopTrace.clear();
    setState(() {
      _loopOrder = <String>[];
      _loopStatus = '正在调度…（先注册队列，再执行同步代码）';
    });

    void record(String tag, String queue) {
      _loopTrace.add('$tag  ← $queue');
      _loopOrder = <String>[..._loopOrder, tag];
      if (!mounted) return;
      setState(() {
        _loopStatus = '当前顺序：${_loopOrder.join(' → ')}';
      });
    }

    _loopTrace.add('── 1. 先注册两个微任务、两个普通事件 ──');
    scheduleMicrotask(() => record('M1', 'microtask 队列'));
    Future<void>.microtask(() => record('M2', 'microtask 队列'));
    Future<void>(() => record('E1', 'event 队列'));
    Future<void>(() => record('E2', 'event 队列'));

    _loopTrace.add('── 2. 同步代码继续往下跑（它会插在所有人前面）──');
    record('S1', '同步栈');
    _loopTrace.add('── 3. 同步片段结束，事件循环开始工作 ──');

    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {
        _loopStatus =
            '最终顺序：${_loopOrder.join(' → ')}。'
            '同步 → 微任务 → 普通事件，三级梯队一目了然。';
      });
    });
  }

  // ---------- 实验二 ----------

  Future<void> _runOnMainThread() async {
    _blockTrace.clear();
    _blockTrace.add('── ① 在主 isolate 上同步执行 _heavyTask ──');
    setState(() {
      _blockRunning = true;
      _blockStatus = '正在主 isolate 上跑…… 盯住圆环和帧数，它们应该冻住了。';
    });

    // 先让 UI 把「正在跑」这一帧画出来，再开始阻塞，效果才看得见
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final int framesBefore = _frames.value;
    final Stopwatch watch = Stopwatch()..start();
    final (_, int sum) = _heavyTask((1200, 1000000)); // 同步 → 直接卡住主线程
    watch.stop();
    final int framesDuring = _frames.value - framesBefore;

    if (!mounted) return;
    _blockTrace.add('✔ 主线程算完：耗时 ${watch.elapsedMilliseconds} ms，sum = $sum');
    _blockTrace.add('⚠ 这期间只渲染了 $framesDuring 帧');
    setState(() {
      _blockRunning = false;
      _blockStatus =
          '主 isolate 被占住约 ${watch.elapsedMilliseconds} ms，'
          '期间只渲染了 $framesDuring 帧 —— 圆环停转、帧数不涨就是证据。';
    });
  }

  Future<void> _runOnIsolate() async {
    _blockTrace.clear();
    _blockTrace.add('── ② compute(_heavyTask, ...) → 后台 isolate ──');
    setState(() {
      _blockRunning = true;
      _blockStatus = '后台 isolate 正在算…… 圆环应该还在转，帧数继续涨。';
    });

    final int framesBefore = _frames.value;
    final Stopwatch watch = Stopwatch()..start();
    final (_, int sum) =
        await compute<(int, int), (int, int)>(_heavyTask, (1200, 1000000));
    watch.stop();
    final int framesDuring = _frames.value - framesBefore;

    if (!mounted) return;
    _blockTrace.add('✔ 后台算完：耗时 ${watch.elapsedMilliseconds} ms，sum = $sum');
    _blockTrace.add('✔ 这期间照样渲染了 $framesDuring 帧');
    setState(() {
      _blockRunning = false;
      _blockStatus =
          '同样的任务、几乎同样的耗时（约 ${watch.elapsedMilliseconds} ms），'
          '但这期间渲染了 $framesDuring 帧 —— UI 全程没卡。';
    });
  }

  // ---------- 实验三 ----------

  Future<void> _spawnWorker() async {
    _stopWorker();
    _isolateTrace.clear();
    _flagTouched = false;
    _isolateTrace.add('── Isolate.spawn(_isolateEntry, replyPort.sendPort) ──');

    final ReceivePort replyPort = ReceivePort();
    _workerPort = replyPort;

    replyPort.listen((Object? message) {
      if (!mounted) return;
      if (message is int) {
        _isolateTrace.add('✔ 子 isolate 发来最终结果：$message');
        setState(() {
          _isolateStatus = '算完了，最终结果 $message。'
              'isolate 已经用不上了，「kill 掉」可以释放它。';
        });
        _stopWorker();
        return;
      }
      final String text = '$message';
      if (text.contains('_mainIsolateFlag')) _flagTouched = true;
      _isolateTrace.add('  ← $text');
      setState(() {});
    });

    setState(() {
      _isolateStatus = '正在启动后台 isolate……（它会每 320ms 回传一条进度）';
    });

    final Isolate isolate =
        await Isolate.spawn(_isolateEntry, replyPort.sendPort);
    if (!mounted) {
      isolate.kill(priority: Isolate.immediate);
      replyPort.close();
      return;
    }
    _worker = isolate;
  }

  void _stopWorkerPressed() {
    if (_worker == null && _workerPort == null) {
      _isolateTrace.add('✗ 当前没有活跃的 isolate');
      setState(() {});
      return;
    }
    _stopWorker();
    _isolateTrace.add('✗ 调用了 Isolate.kill()，并 close 掉 ReceivePort');
    setState(() {
      _isolateStatus = '已 kill。注意 kill 之后不能复用，要重新 spawn 一个新的。';
    });
  }

  void _stopWorker() {
    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
    _workerPort?.close();
    _workerPort = null;
  }
}

// ============================================================
// 四、通用小组件
// ============================================================

/// 黑底等宽轨迹面板。
class _TracePanel extends StatelessWidget {
  const _TracePanel({
    required this.trace,
    this.height = 150,
    this.empty = '还没有轨迹',
  });

  final _Trace trace;

  final double height;

  final String empty;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: trace,
      builder: (BuildContext context, Widget? _) {
        final List<String> lines = trace.lines;
        return Container(
          height: height,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF12161C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: lines.isEmpty
              ? Center(
                  child: Text(
                    empty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final String line in lines)
                      Text(
                        line,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          height: 1.7,
                          color: _lineColor(line),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Color _lineColor(String line) {
    if (line.startsWith('✗') || line.contains('StateError')) {
      return const Color(0xFFFF8A80);
    }
    if (line.startsWith('✔') || line.startsWith('■')) {
      return const Color(0xFF7CE38B);
    }
    if (line.startsWith('⚠')) return const Color(0xFFFFD166);
    if (line.startsWith('──')) return const Color(0x8AFFFFFF);
    if (line.startsWith('▶')) return const Color(0xFF9FE8FF);
    if (line.contains('←')) return const Color(0xFF9FE8FF);
    return const Color(0xFFD5D5D5);
  }
}

Widget _card({required Widget child, Color? color}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color ?? Colors.white,
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
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.6,
          color: Color(0xFF3D5A80),
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
          child: Text(text, style: const TextStyle(height: 1.6, fontSize: 12.5)),
        ),
      ],
    );
  }
}

/// 流程步骤（编号 + 标题 + 说明）
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

/// 引擎线程的一行：线程名 + 角色标签 + 说明。
class _EngineThreadRow extends StatelessWidget {
  const _EngineThreadRow({
    required this.thread,
    required this.role,
    required this.desc,
    this.last = false,
  });

  final String thread;

  final String role;

  final String desc;

  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: last ? 0 : 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                thread,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D5A80),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF3D5A80),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
    );
  }
}

/// 坑速查的一行：写法 / 报错表现 / 正确做法
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
              const Icon(
                Icons.error_outline,
                size: 15,
                color: Colors.redAccent,
              ),
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
              const Icon(
                Icons.check_circle_outline,
                size: 15,
                color: Colors.teal,
              ),
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

/// 简易对照表（列宽按列数自适应）。
class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.headers, required this.rows});

  final List<String> headers;

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade200),
      columnWidths: <int, TableColumnWidth>{
        for (int i = 0; i < headers.length; i++)
          i: FlexColumnWidth(i == 0 ? 0.85 : 1.2),
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
