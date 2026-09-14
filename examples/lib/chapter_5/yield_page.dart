import 'dart:async';

import 'package:flutter/material.dart';

/// ============================================================
/// yield / 生成器（Generator）学习 Demo
/// ============================================================
///
/// `yield` 不是「返回一个值」，而是**挂起当前函数**。
///
/// 带 `yield` 的函数叫生成器，它被 Dart 编译器改写成一个状态机：
/// 每次执行到 `yield` 就停住、把值交出去，下次被要求「继续」时
/// 从这一行之后接着跑 —— 局部变量、循环进度、try 块全都保留着。
///
/// 所以生成器的本质是「**能暂停、能恢复的函数**」，
/// 而不是「一次算完的函数」。
///
/// Dart 有两种生成器，靠星号区分：
///
/// | 写法 | 返回类型 | 谁来「继续」它 | 能 await 吗 |
/// |---|---|---|---|
/// | `sync*`  | `Iterable<T>` | 调用方主动 `moveNext()` | 不能 |
/// | `async*` | `Stream<T>`   | 订阅者 / 事件循环 | 能 |
///
/// 三个关键字的分工：
/// - `yield x`  ：产出一个元素
/// - `yield* s` ：把另一个序列的**全部元素**逐个插进来（不是产出 s 本身）
/// - `return`   ：结束生成器（`async*` 里只能裸 `return;`）
///
/// 本页四个实验依次验证：
/// 一、`sync*` 是惰性的 —— 不 moveNext 就一行都不执行
/// 二、`async*` 驱动 Stream —— yield 之间能让出事件循环，取消时能清理
/// 三、`yield*` 委托 —— 把子序列摊平，不产生嵌套
/// 四、实战 —— 用 `sync*` 递归遍历树，把「递归 + 收集」写成一条直线
class YieldPage extends StatefulWidget {
  const YieldPage({super.key});

  @override
  State<YieldPage> createState() => _YieldPageState();
}

// ============================================================
// 一、生成器函数
// ============================================================

/// 同步生成器：每 yield 一次就挂起，等下一次 moveNext 才从这里继续。
///
/// 注意函数体里的三处 `trace` —— 它们的位置就是「执行点」，
/// 实验一靠它们把挂起 / 恢复画出来。
Iterable<int> _lazyRange(int max, void Function(String) trace) sync* {
  trace('▶ 函数体开始执行（这是第 1 次 moveNext() 触发的）');
  for (int i = 0; i < max; i++) {
    trace('  · 执行到 `yield $i` → 挂起，把 $i 交给调用方');
    yield i;
    trace('  · 从 `yield $i` 之后恢复执行');
  }
  trace('■ 循环结束 → 函数返回 → 下一次 moveNext() 会返回 false');
}

/// 异步生成器：yield 之间可以 await。
///
/// `async*` 的函数体要等**订阅发生**才开始跑；
/// 每次 yield 相当于向内部 StreamController 推一个值。
///
/// `finally` 在这里很重要：Stream 被取消时，生成器会在 yield 处
/// 被「掐断」，并保证 finally 块执行 —— 这就是用 async* 封装
/// 资源清理型数据流（轮询、长连接）的依据。
Stream<int> _countdown(int from, void Function(String) trace) async* {
  trace('▶ 订阅触发了函数体开始执行');
  try {
    for (int i = from; i > 0; i--) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      trace('  · yield $i（前面的 await 已经把控制权交还给事件循环）');
      yield i;
    }
  } finally {
    trace('■ finally 执行 —— 正常跑完或被取消订阅都会走到这里');
  }
}

/// 子序列：产出 0 .. end-1。
Iterable<int> _zeroTo(int end, String indent, void Function(String) trace) sync* {
  for (int i = 0; i < end; i++) {
    trace('$indent└ 子序列产出 $i');
    yield i;
  }
}

/// 倒计时：自己产 n，剩下的整块委托给子序列。
///
/// 结果 `(5, 0, 1, 2, 3)` —— `yield*` 不长出嵌套层，
/// 它等价于把子序列的每个元素手写成一串 `yield`。
Iterable<int> _countDownFrom(int n, void Function(String) trace) sync* {
  if (n > 0) {
    trace('yield $n');
    yield n;
    trace('yield* _zeroTo(${n - 1})  ← 把子序列的每个元素原样插进来');
    yield* _zeroTo(n - 1, '  ', trace);
  }
}

/// 树节点。
class _TreeNode {
  const _TreeNode(this.name, [this.children = const <_TreeNode>[]]);

  final String name;

  final List<_TreeNode> children;
}

/// 用 `sync*` 做深度优先遍历：递归交给 `yield*`，不用手写 flatMap。
///
/// 这是 `yield*` 最实用的场景 —— Flutter 里 `Element.visitChildren`
/// （回调版）、`RenderObject.visitChildren` 都是同一套思路。
Iterable<(int, _TreeNode)> _walkWithDepth(_TreeNode node, [int depth = 0])
    sync* {
  yield (depth, node);
  for (final _TreeNode child in node.children) {
    yield* _walkWithDepth(child, depth + 1);
  }
}

/// 演示用的树（照 Flutter 的 Widget 树编的）。
const _TreeNode _demoTree = _TreeNode(
  'MyApp',
  <_TreeNode>[
    _TreeNode(
      'MaterialApp',
      <_TreeNode>[
        _TreeNode(
          'MyHomePage',
          <_TreeNode>[
            _TreeNode('AppBar'),
            _TreeNode(
              'ListView',
              <_TreeNode>[
                _TreeNode('MenuItem 1.1'),
                _TreeNode('MenuItem 1.2'),
                _TreeNode('MenuItem 2.1'),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

// ============================================================
// 二、轨迹日志
// ============================================================

/// 记录执行轨迹的小容器。
///
/// 生成器的行为只能靠「打印执行点」来观察 —— 这正是本页的教学手段：
/// 代码里打一行 trace，UI 上就看到函数到底跑到哪了。
class _Trace extends ChangeNotifier {
  final List<String> _lines = <String>[];

  bool _disposed = false;

  List<String> get lines => List<String>.unmodifiable(_lines);

  void add(String line) {
    // 页面销毁后，迟到的异步回调还会往这里写，直接丢掉
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

class _YieldPageState extends State<YieldPage> {
  // ---------- 实验一：sync* 的惰性 ----------
  final _Trace _syncTrace = _Trace();

  Iterator<int>? _syncIterator;

  int _syncMoveNextCount = 0;

  int _syncValueCount = 0;

  String _syncStatus = '还没开始。先点「调用 _lazyRange(3)」，注意看日志区一片空白。';

  // ---------- 实验二：async* 与 Stream ----------
  final _Trace _streamTrace = _Trace();

  StreamSubscription<int>? _subscription;

  int _received = 0;

  final List<int> _receivedValues = <int>[];

  String _streamStatus = '还没订阅。点「订阅」后每秒产一个数，同时可以试试取消。';

  // ---------- 实验三：yield* 委托 ----------
  final _Trace _delegateTrace = _Trace();

  List<int> _delegated = <int>[];

  String _delegateStatus = '还没展开。点「展开 countDownFrom(5)」看结果和委托顺序。';

  // ---------- 实验四：递归遍历树 ----------
  List<(int, _TreeNode)> _walkResult = <(int, _TreeNode)>[];

  String _walkStatus = '还没展开。点「深度优先遍历」把树拍平成一维序列。';

  @override
  void dispose() {
    _subscription?.cancel();
    _syncTrace.dispose();
    _streamTrace.dispose();
    _delegateTrace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('yield 生成器')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntro(),
          const SizedBox(height: 16),
          _buildSyncStarSection(),
          const SizedBox(height: 16),
          _buildAsyncStarSection(),
          const SizedBox(height: 16),
          _buildYieldStarSection(),
          const SizedBox(height: 16),
          _buildWalkSection(),
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
          _SectionTitle('yield 到底做了什么'),
          SizedBox(height: 8),
          Text(
            '普通函数是「一次算完再交结果」；生成器把「算一部分 → 交出去 → '
            '等下一轮再接着算」写成了看起来同步的代码。'
            'yield 就是那条分界线：执行到它，函数带着全部局部状态停下来。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 10),
          _BulletLine('sync*  ：返回 Iterable，谁来继续由调用方的 moveNext() 决定'),
          _BulletLine('async* ：返回 Stream，谁来继续由订阅者和事件循环决定'),
          _BulletLine('yield* ：把另一个序列整个「摊平」接进来，不产生嵌套'),
          SizedBox(height: 16),
          _SectionTitle('生成器的一生'),
          SizedBox(height: 10),
          _PipelineStep(
            ordinal: '1',
            title: '调用 —— 只创建对象',
            desc: 'sync* 函数被调用时一行都不执行，只得到一个 Iterable；'
                'async* 连对象都只是「蓝图」，要等 listen 才启动。'
                '惰性和「副作用不触发」的坑都来自这一步。',
            color: Color(0xFF3D5A80),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '2',
            title: '驱动 —— 有人要求下一个值',
            desc: 'sync* 靠 iterator.moveNext()；async* 靠订阅（listen / await for）。'
                '没人驱动，函数就永远躺着。',
            color: Color(0xFF5C6BC0),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '3',
            title: '挂起 / 恢复 —— yield 是暂停点',
            desc: '跑到 yield 就把值交出去并停住；下次被驱动时从这一行之后继续。'
                '局部变量和循环进度都还在，这也是它和「普通函数返回 List」的本质区别。',
            color: Color(0xFF2E7D32),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '4',
            title: '结束 —— return 或跑完',
            desc: 'sync* 这边 moveNext() 转为返回 false；async* 那边 Stream 触发 onDone。'
                '提前取消订阅时，生成器在 yield 处被掐断，finally 依然会执行。',
            color: Color(0xFFC62828),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 实验一：sync* 的惰性
  // ----------------------------------------------------------
  Widget _buildSyncStarSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验一：sync* 是惰性的（单步看暂停点）'),
          const SizedBox(height: 8),
          const Text(
            '下面这个生成器每产一个值打一行日志。按顺序点按钮，'
            '你会看到一个反直觉的事实：调用函数时函数体一行都没跑。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            r'''Iterable<int> _lazyRange(int max) sync* {
  print('▶ 函数体开始执行');        // ← 第 1 次 moveNext 才打印
  for (int i = 0; i < max; i++) {
    print('  · 执行到 yield $i');
    yield i;                        // ← 挂起点
    print('  · 从 yield $i 之后恢复');
  }
}''',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _callGenerator,
                icon: const Icon(Icons.call_made, size: 16),
                label: const Text('1. 调用 _lazyRange(3)'),
              ),
              OutlinedButton.icon(
                onPressed: _syncIterator == null ? null : _stepOnce,
                icon: const Icon(Icons.skip_next, size: 16),
                label: const Text('2. moveNext() 一次'),
              ),
              OutlinedButton.icon(
                onPressed: _drainGenerator,
                icon: const Icon(Icons.fast_forward, size: 16),
                label: const Text('3. for-in 全跑一遍'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statusRow(_syncStatus),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '执行轨迹',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'moveNext $_syncMoveNextCount 次 · 产出 $_syncValueCount 个值',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _TracePanel(trace: _syncTrace, empty: '空 —— 正是因为函数体还没被执行'),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.lightbulb_outline,
            text:
                '关键结论：生成器是「按需计算」的。'
                '这也是 Iterable 函数式操作（map / where / take）能无限链式拼接的原因 —— '
                '只要没有消费者，一个元素都不会被算出来。'
                '反过来，如果你在 sync* 里写了「打点上报 / 注册监听」这类副作用，'
                '会发现它压根没执行，问题就出在这一步。',
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 实验二：async* 与 Stream
  // ----------------------------------------------------------
  Widget _buildAsyncStarSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验二：async* 驱动 Stream（能 await，能取消）'),
          const SizedBox(height: 8),
          const Text(
            'sync* 只能在有人 moveNext 时推进，中间没法等任何东西；'
            'async* 的 yield 之间可以 await —— 每产一个值都会把控制权交还事件循环，'
            'UI 不会被阻塞。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            r'''Stream<int> _countdown(int from) async* {
  try {
    for (int i = from; i > 0; i--) {
      await Future.delayed(const Duration(milliseconds: 900));  // ← 让出事件循环
      yield i;
    }
  } finally {
    print('生成器结束或被取消');
  }
}

// 消费：一次拿一个，await 等下一个
await for (final int value in _countdown(4)) {
  print(value);
}''',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _subscribe,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('订阅（产 4 个）'),
              ),
              OutlinedButton.icon(
                onPressed: _consumeTwoThenCancel,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('只拿 2 个就取消'),
              ),
              OutlinedButton.icon(
                onPressed: _cancelSubscription,
                icon: const Icon(Icons.stop_circle_outlined, size: 16),
                label: const Text('手动取消'),
              ),
              OutlinedButton.icon(
                onPressed: _listenTwiceDemo,
                icon: const Icon(Icons.error_outline, size: 16),
                label: const Text('同一 Stream listen 两次'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statusRow(_streamStatus),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final int value in _receivedValues)
                Chip(
                  label: Text('$value'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.teal.withValues(alpha: 0.12),
                  side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '执行轨迹',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '已收到 $_received 个值',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _TracePanel(
            trace: _streamTrace,
            empty: '空 —— async* 的函数体要等订阅才启动',
          ),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.insights_outlined,
            text:
                '要点：\n'
                '· async* 的函数体在「订阅发生」时才启动 —— 调用它只是拿到一个 Stream 蓝图。\n'
                '· 取消订阅后，生成器会在 yield 处被掐断并执行 finally，'
                '所以资源清理写在 finally 里是可靠的。\n'
                '· async* 产出的是**单订阅** Stream：同一个 Stream 对象只能 listen 一次，'
                '第二次会抛 StateError。想要多点消费，要么 asBroadcastStream()，'
                '要么重新调用生成器函数拿一个全新的 Stream（按钮 4 会演示这句报错）。\n'
                '· 和 Stream.fromIterable 的区别：后者把现成的集合包装一下，'
                'async* 是「边算边推」，天然适合分页、轮询、文件流解析。',
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 实验三：yield* 委托
  // ----------------------------------------------------------
  Widget _buildYieldStarSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验三：yield* 是「摊平」不是「嵌套」'),
          const SizedBox(height: 8),
          const Text(
            '最常被误解的一条：yield* 不等于 yield 一个序列对象，'
            '而是把那个序列的元素**逐个**插到当前位置，等价于手写一串 yield。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            r'''Iterable<int> _countDownFrom(int n) sync* {
  if (n > 0) {
    yield n;                 // 自己产一个
    yield* _zeroTo(n - 1);   // 剩下的全交给子序列（等价于 for + yield）
  }
}

// _countDownFrom(5) → (5, 0, 1, 2, 3)
// 注意这里是「委托给另一个生成器」，不是递归调用自己''',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _runDelegate,
                icon: const Icon(Icons.account_tree_outlined, size: 16),
                label: const Text('展开 _countDownFrom(5)'),
              ),
              OutlinedButton.icon(
                onPressed: _runDelegateWithList,
                icon: const Icon(Icons.list_alt, size: 16),
                label: const Text('yield* 直接接一个字面量 List'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statusRow(_delegateStatus),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final int value in _delegated)
                Chip(
                  label: Text('$value'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.orange.withValues(alpha: 0.12),
                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.35)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '委托顺序',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _TracePanel(
            trace: _delegateTrace,
            height: 132,
            empty: '还没展开',
          ),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.lightbulb_outline,
            text:
                '两种情况都能接在 yield* 后面：\n'
                '· Iterable —— 在 sync* 里用，逐元素展开。\n'
                '· Stream —— 在 async* 里用，会「转发」这个 Stream 的事件和错误，'
                '直到它结束；它自己的 finally / onDone 语义也一并转发过来。\n'
                '另外 yield* 传 null 是会出错的，想要「有则展开」得自己判空。',
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 实验四：递归遍历树
  // ----------------------------------------------------------
  Widget _buildWalkSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验四：实战 —— 用 sync* 递归遍历树'),
          const SizedBox(height: 8),
          const Text(
            '递归遍历的朴素写法是「传一个 List 进去往里 add」，'
            '调用方还得自己准备容器。换成 sync* 之后，'
            '递归点直接写成 yield* 递归调用，函数返回的就是可以直接 for-in 的序列。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            r'''Iterable<_TreeNode> _walk(_TreeNode node) sync* {
  yield node;                              // 先自己
  for (final child in node.children) {
    yield* _walk(child);                   // 递归点：一行摊平整棵子树
  }
}

// 调用方：不需要容器，for-in 直接消费
for (final node in _walk(root)) { print(node.name); }''',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _runWalk,
                icon: const Icon(Icons.account_tree, size: 16),
                label: const Text('深度优先遍历'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _walkResult.isEmpty
                    ? null
                    : () => setState(() {
                        _walkResult = <(int, _TreeNode)>[];
                        _walkStatus = '已收起。再点「深度优先遍历」重新展开。';
                      }),
                icon: const Icon(Icons.unfold_less, size: 16),
                label: const Text('收起'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statusRow(_walkStatus),
          const SizedBox(height: 12),
          if (_walkResult.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int index = 0; index < _walkResult.length; index++)
                    _buildWalkRow(index, _walkResult[index]),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.insights_outlined,
            text:
                '看输出顺序：父节点一被 yield 出来，紧接着就是整棵子树 —— '
                '这正是深度优先。'
                'Flutter 内部遍历 Element / RenderObject 树用的就是同一个形状，'
                '只是早期为了让调用方能「中断」（返回 false 停止遍历），'
                '选择了回调式 visitChildren；用 sync* 写则是换成调用方 break 来控制。',
          ),
        ],
      ),
    );
  }

  Widget _buildWalkRow(int index, (int, _TreeNode) item) {
    final (int depth, _TreeNode node) = item;
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, top: 3, bottom: 3),
      child: Row(
        children: [
          Text(
            '${index + 1}.',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.black38,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            depth == 0 ? '' : '└─ ',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Colors.black26,
            ),
          ),
          Expanded(
            child: Text(
              node.name,
              style: TextStyle(
                fontSize: 12.5,
                fontFamily: 'monospace',
                fontWeight: node.children.isEmpty
                    ? FontWeight.normal
                    : FontWeight.w600,
                color: node.children.isEmpty
                    ? Colors.black54
                    : const Color(0xFF3D5A80),
              ),
            ),
          ),
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
          _SectionTitle('生成器的坑速查'),
          SizedBox(height: 6),
          Text(
            '这些全是编译期或运行时会真实咬人的地方。',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          SizedBox(height: 14),
          _TrapRow(
            scene: '在 sync* 里写 await',
            symptom: "编译报错：The 'await' expression can't be used in a 'sync*' function",
            solution:
                'sync* 的「继续」时机掌握在调用方手里，框架没法给它接一个 Future。'
                '需要等待就改成 async* 返回 Stream。',
          ),
          _TrapRow(
            scene: '在 async* / sync* 里写 return 值',
            symptom: "编译报错：The 'return' expression can't be used in an 'async*' function",
            solution:
                '生成器的产出只能走 yield，return 只负责结束。'
                '要「带结束状态」就让元素类型自己带上（比如 T? 或一个 Result 包装）。',
          ),
          _TrapRow(
            scene: '忘了写星号，直接写 yield',
            symptom:
                "编译报错：The 'yield' expression can only be used in a 'sync*' or 'async*' function",
            solution:
                '检查函数签名：sync* / async* 必须同时出现在返回类型之后、函数体之前。',
          ),
          _TrapRow(
            scene: '在 sync* 函数里做副作用（打点、注册监听、跑网络）',
            symptom: '调用函数时什么都没发生，日志一行不打',
            solution:
                'sync* 是惰性的，函数体要等 moveNext。副作用要么搬到迭代循环里，'
                '要么改成普通函数返回 List —— 但那就失去了惰性。',
          ),
          _TrapRow(
            scene: '同一个 async* 产生的 Stream 被 listen 两次',
            symptom: 'StateError: Stream has already been listened to.',
            solution:
                'async* 生来是单订阅。用 asBroadcastStream() 共享，'
                '或者直接再调用一次生成器函数拿新的 Stream（通常是更省心的做法）。',
          ),
          _TrapRow(
            scene: '想「有则展开」写成 yield* maybeNull',
            symptom: '运行时报错，序列为 null 时直接崩',
            solution:
                'yield* 不做判空。要写 yield* ? 不存在，只能手写 '
                'if (list != null) yield* list;，或者换成 for-in 加判空。',
          ),
          _TrapRow(
            scene: '在生成器里修改变量后再 yield，期望调用方拿到快照',
            symptom: '外部的 Iterable 每次 for-in 结果都可能不一样',
            solution:
                'Iterable 是「可重复遍历」的，每次 .iterator 都是从头跑一遍生成器，'
                '结果取决于函数里读到的外部状态。要稳定结果就先 toList() 固化。',
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
          _SectionTitle('sync* / async* 对照'),
          SizedBox(height: 10),
          _CompareTable(
            headers: <String>['', 'sync*', 'async*'],
            rows: <List<String>>[
              <String>['返回类型', 'Iterable<T>', 'Stream<T>'],
              <String>['谁来驱动', '调用方 moveNext()', '订阅者 / 事件循环'],
              <String>['函数体何时开始', '第一次 moveNext()', '第一次 listen()'],
              <String>['能否 await', '不能', '能'],
              <String>['能否 yield*', '能（接 Iterable）', '能（接 Stream 或 Iterable）'],
              <String>['消费方式', 'for-in / .toList() / 惰性链式操作', 'await for / listen()'],
              <String>['可重复消费', '可以，每次拿新迭代器', '默认不行（单订阅）'],
              <String>['典型用途', '递归遍历、惰性视图、无限序列', '分页、轮询、流式解析'],
            ],
          ),
          SizedBox(height: 14),
          _SectionTitle('什么时候该用它'),
          SizedBox(height: 8),
          _BulletLine(
            '要写「递归展开 / 生成器式遍历」—— 用 sync*，递归点写 yield* 就行',
          ),
          _BulletLine(
            '要写「多次异步产出 + 中途可以让出」—— 用 async*，清理逻辑放 finally',
          ),
          _BulletLine(
            '只是把现成集合换个包装 —— 不需要生成器，Stream.fromIterable / Iterable.map 更快',
          ),
          _BulletLine(
            '元素数量巨大或无限，而调用方可能提前 break —— sync* 才是对的选择，'
            '它不会把整个序列先算完',
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

  void _callGenerator() {
    _syncTrace.clear();
    _syncTrace.add('── 调用 _lazyRange(3) ──');
    final Iterator<int> iterator = _lazyRange(3, _syncTrace.add).iterator;
    setState(() {
      _syncIterator = iterator;
      _syncMoveNextCount = 0;
      _syncValueCount = 0;
      _syncStatus =
          '拿到了 Iterable.iterator，但日志区只有「调用」这一行 —— '
          '函数体一行都没执行。';
    });
  }

  void _stepOnce() {
    final Iterator<int>? iterator = _syncIterator;
    if (iterator == null) return;

    final int nextCount = _syncMoveNextCount + 1;
    final bool hasValue = iterator.moveNext();
    final int? value = hasValue ? iterator.current : null;

    if (hasValue) {
      _syncTrace.add('✔ 第 $nextCount 次 moveNext() → true，current = $value');
    } else {
      _syncTrace.add('✔ 第 $nextCount 次 moveNext() → false，序列已耗尽');
    }

    setState(() {
      _syncMoveNextCount = nextCount;
      if (hasValue) _syncValueCount++;
      _syncStatus = hasValue
          ? '第 $nextCount 次 moveNext() 拿到 $value，'
                '函数又停在了下一个 yield 前。已产出 $_syncValueCount 个值。'
          : '第 $nextCount 次 moveNext() 返回 false —— 生成器结束了，'
                '之后再调也不会返回 true。';
    });
  }

  void _drainGenerator() {
    _syncTrace.add('── for (final v in _lazyRange(3)) 全跑一遍 ──');
    final List<int> values = <int>[];
    // for-in 内部就是反复 moveNext()，每次循环体之前先拿到下一个值
    for (final int value in _lazyRange(3, _syncTrace.add)) {
      values.add(value);
    }
    setState(() {
      _syncIterator = null;
      _syncStatus =
          'for-in 消费完：$values。它做的事和上面手点 moveNext 完全一样，'
          '只是把「取下一个 → 执行循环体」自动化了。';
    });
  }

  // ---------- 实验二 ----------

  void _resetStreamState() {
    _received = 0;
    _receivedValues.clear();
  }

  void _subscribe() {
    _subscription?.cancel();
    _streamTrace.clear();
    _streamTrace.add('── stream.listen(...) ──');

    _subscription = _countdown(4, _streamTrace.add).listen(
      (int value) {
        if (!mounted) return;
        setState(() {
          _received++;
          _receivedValues.add(value);
          _streamStatus = '收到第 $_received 个值：$value';
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _subscription = null;
          _streamStatus = 'onDone —— async* 函数自然跑完，Stream 自动关闭。';
        });
      },
      onError: (Object error) => _streamTrace.add('✗ onError: $error'),
    );

    setState(() {
      _resetStreamState();
      _streamStatus = '已订阅，等第一个值（约 900ms 后）…';
    });
  }

  void _cancelSubscription() {
    final StreamSubscription<int>? subscription = _subscription;
    if (subscription == null) {
      _streamTrace.add('✗ 当前没有活跃订阅');
      return;
    }
    subscription.cancel();
    _streamTrace.add('✗ 调用 subscription.cancel()');
    setState(() {
      _subscription = null;
      _streamStatus =
          '已取消订阅 —— 注意日志里紧接着出现了 finally，'
          '生成器在 yield 处被掐断时依然会清理。';
    });
  }

  void _consumeTwoThenCancel() {
    _subscription?.cancel();
    _streamTrace.clear();
    _streamTrace.add('── await for 消费 2 个值后 break ──');

    late StreamSubscription<int> subscription;
    subscription = _countdown(4, _streamTrace.add).listen((int value) {
      if (!mounted) return;
      final bool shouldStop = _received + 1 >= 2;
      setState(() {
        _received++;
        _receivedValues.add(value);
        _streamStatus = shouldStop
            ? '拿到第 $_received 个值就 break —— await for 会自动 cancel 订阅。'
            : '收到第 $_received 个值：$value';
      });
      if (shouldStop) {
        _streamTrace.add('✗ 达到 2 个值 → 停止消费 → 订阅被取消');
        subscription.cancel();
        if (mounted) setState(() => _subscription = null);
      }
    });

    setState(() {
      _resetStreamState();
      _subscription = subscription;
      _streamStatus = '开始消费，拿到 2 个值就退出循环…';
    });
  }

  void _listenTwiceDemo() {
    _streamTrace.clear();
    _streamTrace.add('── 同一个 Stream 对象 listen 两次 ──');

    final Stream<int> stream = _countdown(2, _streamTrace.add);
    stream.listen((int value) => _streamTrace.add('  第一个订阅收到 $value'));

    try {
      stream.listen((int value) => _streamTrace.add('  第二个订阅收到 $value'));
      _streamTrace.add('第二次 listen 居然没报错？');
    } on StateError catch (error) {
      _streamTrace.add('✗ 第二次 listen 抛出 StateError: ${error.message}');
    }

    _streamTrace.add('✔ 而重新调用 _countdown(2) 会得到**全新的 Stream**，可以再订阅一次');
  }

  // ---------- 实验三 ----------

  void _runDelegate() {
    _delegateTrace.clear();
    _delegateTrace.add('── 展开 _countDownFrom(5) ──');
    final List<int> values = _countDownFrom(5, _delegateTrace.add).toList();
    setState(() {
      _delegated = values;
      _delegateStatus =
          '结果：$values —— yield* 没有产生嵌套层，它把子序列摊平接了进来，'
          '等价于在当前位置手写一串 yield。';
    });
  }

  void _runDelegateWithList() {
    _delegateTrace.clear();
    _delegateTrace.add('── yield* <int>[7, 8, 9] ──');

    Iterable<int> literal() sync* {
      _delegateTrace.add('yield 0');
      yield 0;
      _delegateTrace.add('yield* <int>[7, 8, 9]');
      yield* <int>[7, 8, 9];
      _delegateTrace.add('yield 100');
      yield 100;
    }

    final List<int> values = literal().toList();
    setState(() {
      _delegated = values;
      _delegateStatus =
          '结果：$values —— 任何 Iterable 都能接在 yield* 后面，'
          '包括 collection-if / 展开运算符里那种临时字面量。';
    });
  }

  // ---------- 实验四 ----------

  void _runWalk() {
    final List<(int, _TreeNode)> flat = _walkWithDepth(_demoTree).toList();
    setState(() {
      _walkResult = flat;
      _walkStatus =
          '遍历出 ${flat.length} 个节点，顺序就是渲染顺序（父在前，子树紧随其后）。';
    });
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
    if (line.startsWith('──')) return const Color(0x8AFFFFFF);
    if (line.startsWith('▶')) return const Color(0xFF9FE8FF);
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

/// 简易对照表。
class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.headers, required this.rows});

  final List<String> headers;

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade200),
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(0.9),
        1: FlexColumnWidth(1.15),
        2: FlexColumnWidth(1.25),
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
