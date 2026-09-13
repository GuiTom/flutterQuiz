import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// ============================================================
// 核心：命中测试追踪器
// ============================================================

/// 记录一次完整的命中测试过程，分三个阶段：
///
/// **阶段一：询问（自顶向下）**
/// 从 RenderView 开始，父节点把坐标传给子节点，问「你命中了吗？」。
/// 对应 [RenderBox.hitTest] 的递归下行。
///
/// **阶段二：收集（由内到外）**
/// 命中的节点是在递归「返回」的路上被 [HitTestResult.add] 的，
/// 所以路径里最内层的节点排在第一个。
///
/// **阶段三：分发（由内到外）**
/// 指针事件沿 HitTestResult.path 顺序依次调用 handleEvent，
/// 也就是说「最内层最早收到事件」。
///
/// 注意「询问方向」和「路径方向」是相反的，这正是最容易记混的一点。
class HitTestTracer extends ChangeNotifier {
  static const int _maxLines = 120;

  /// 当前这次命中测试的追踪内容（还没提交到可见日志）
  final List<String> _buffer = [];

  /// 已提交的可见日志（按时间先后排列，最新的在最后）
  final List<String> _lines = [];

  /// 本次命中的探针，按「加入 HitTestResult」的顺序 —— 即由内到外
  final List<String> _pendingPath = [];

  List<String> _path = const [];
  int _depth = 0;

  List<String> get lines => List.unmodifiable(_lines);

  /// 最近一次完整的命中路径（由内到外）
  List<String> get path => _path;

  int get depth => _depth;

  /// 进入一层，返回该层的缩进前缀（让「进入」和「结果」两行对齐）
  String enter(String name) {
    if (_depth == 0) {
      _buffer
        ..clear()
        ..add('───── ① 命中测试：自顶向下询问 ─────');
      _pendingPath.clear();
    }
    final indent = '  ' * _depth;
    _buffer.add('$indent▽ 询问 $name');
    _depth++;
    return indent;
  }

  void leave(String indent, String result) {
    if (_depth > 0) _depth--;
    _buffer.add('$indent$result');
  }

  void markHit(String name) => _pendingPath.add(name);

  /// 阶段三：事件沿路径分发（由内到外）
  void dispatch(String name) {
    final index = _pendingPath.indexOf(name);
    final ordinal = index >= 0 ? index + 1 : 0;
    _buffer.add('📥 分发到 $name（路径第 $ordinal 个，由内向外）');
  }

  /// 由最外层探针在「收到 PointerDown」时调用：
  /// 此刻命中测试与全部分发都已完成，把缓冲区提交为可见日志。
  ///
  /// 用「提交」而不是「实时写日志」，是为了过滤鼠标 hover：
  /// hover 也会触发命中测试，但不会产生 PointerDown，因此不会提交，
  /// 桌面 / 浏览器上用鼠标调试时日志才不会被刷屏。
  void commit() {
    _path = List.unmodifiable(_pendingPath);
    _lines
      ..add('')
      ..add('───── 新的命中测试 ─────')
      ..addAll(_buffer);
    _buffer.clear();
    while (_lines.length > _maxLines) {
      _lines.removeAt(0);
    }
    notifyListeners();
  }

  void clear() {
    _buffer.clear();
    _lines.clear();
    _pendingPath.clear();
    _path = const [];
    _depth = 0;
    notifyListeners();
  }
}

// ============================================================
// 探针：一个会「说出自己怎么被问到」的 RenderObject
// ============================================================

/// 把 [RenderHitTestProbe] 塞进 widget 树。
class HitTestProbe extends SingleChildRenderObjectWidget {
  const HitTestProbe({
    super.key,
    required this.name,
    required this.tracer,
    this.selfHittable = false,
    this.isRoot = false,
    super.child,
  });

  final String name;
  final HitTestTracer tracer;

  /// 对应 [RenderBox.hitTestSelf] 的返回值：
  /// true 表示「只要坐标在我范围内，我自己就算命中」，
  /// 现实中相当于 Listener(behavior: opaque) 或有实心背景的盒子。
  final bool selfHittable;

  /// 最外层探针：负责在 PointerDown 分发时提交日志。
  final bool isRoot;

  @override
  RenderHitTestProbe createRenderObject(BuildContext context) =>
      RenderHitTestProbe(
        name: name,
        tracer: tracer,
        selfHittable: selfHittable,
        isRoot: isRoot,
      );

  @override
  void updateRenderObject(BuildContext context, RenderHitTestProbe renderObject) {
    renderObject
      ..probeName = name
      ..tracer = tracer
      ..selfHittable = selfHittable
      ..isRoot = isRoot;
  }
}

/// 逐字复刻 [RenderBox.hitTest] 的流程，只是每一步都记一笔日志：
///
/// ```dart
/// bool hitTest(BoxHitTestResult result, {required Offset position}) {
///   if (size.contains(position)) {
///     if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
///       result.add(BoxHitTestEntry(this, position));
///       return true;
///     }
///   }
///   return false;
/// }
/// ```
class RenderHitTestProbe extends RenderProxyBox {
  RenderHitTestProbe({
    required String name,
    required HitTestTracer tracer,
    required bool selfHittable,
    required bool isRoot,
    RenderBox? child,
  })  : _name = name,
        _tracer = tracer,
        _selfHittable = selfHittable,
        _isRoot = isRoot,
        super(child);

  String _name;
  HitTestTracer _tracer;
  bool _selfHittable;
  bool _isRoot;

  String get probeName => _name;
  set probeName(String value) {
    if (_name == value) return;
    _name = value;
  }

  HitTestTracer get tracer => _tracer;
  set tracer(HitTestTracer value) {
    if (identical(_tracer, value)) return;
    _tracer = value;
  }

  bool get selfHittable => _selfHittable;
  set selfHittable(bool value) {
    if (_selfHittable == value) return;
    _selfHittable = value;
  }

  bool get isRoot => _isRoot;
  set isRoot(bool value) {
    if (_isRoot == value) return;
    _isRoot = value;
  }

  @override
  bool hitTestSelf(Offset position) => _selfHittable;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final tracer = _tracer;
    final indent = tracer.enter(_name);

    // 第一步：坐标落在自己的 size 内吗？不在就直接返回 false，不会再问子节点。
    if (!size.contains(position)) {
      tracer.leave(
        indent,
        '✗ $_name 未命中 → false [坐标不在 '
        '${size.width.toInt()}×${size.height.toInt()} 范围内]',
      );
      return false;
    }

    // 第二步：先问子节点，再问自己（|| 短路，但这里都要求值以便打印）
    final childHit = hitTestChildren(result, position: position);
    final selfHit = hitTestSelf(position);

    // 第三步：任意一方命中，就把自己加进路径，并向上返回 true
    if (childHit || selfHit) {
      result.add(BoxHitTestEntry(this, position));
      tracer.markHit(_name);
      tracer.leave(
        indent,
        '✔ $_name 命中 → 加入 HitTestResult 【子节点=$childHit 自身=$selfHit】',
      );
      return true;
    }

    tracer.leave(
      indent,
      '✗ $_name 未命中 → false 【子节点=$childHit 自身=$selfHit】',
    );
    return false;
  }

  /// 阶段三：事件沿路径分发到达自己。
  /// 路径顺序是「由内到外」，所以内层会先收到。
  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _tracer.dispatch(_name);
      if (_isRoot) {
        // 最外层最后收到，此时本次流程已全部走完 → 提交日志
        _tracer.commit();
      }
    }
    super.handleEvent(event, entry);
  }
}

// ============================================================
// 页面
// ============================================================

/// Hit Test 流程机制演示。
///
/// 和同章的 `hit_test_behavior_page.dart` 互补：
/// - 那一页讲 **HitTestBehavior**（deferToChild / opaque / translucent 的差异）
/// - 本页讲 **hitTest 的执行流程**：自顶向下询问 → 由内到外收集路径 → 由内到外分发
class HitTestPage extends StatefulWidget {
  const HitTestPage({super.key});

  @override
  State<HitTestPage> createState() => _HitTestPageState();
}

class _HitTestPageState extends State<HitTestPage> {
  /// 实验一：嵌套层级（A ⊃ B ⊃ C）
  final HitTestTracer _nestedTracer = HitTestTracer();

  /// 实验一：A、B 的 `hitTestSelf` 返回值（对应 [HitTestProbe.selfHittable]）。
  ///
  /// false = 透明转发层，自己不作表态；
  /// true  = 只要坐标落在自己的 size 内就自己算命中（相当于 opaque / 有实心背景）。
  bool _abSelfHittable = false;

  /// 实验一：B 的边框是否用 [IgnorePointer] 排除在命中测试之外。
  /// 切换它可以对比「同一个点击位置、两种实现」的差别。
  bool _bBorderIgnoresPointer = true;

  static const TextStyle _toggleLabelStyle =
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);

  /// 实验二：兄弟节点叠加（L1 / L2 / L3）
  final HitTestTracer _siblingTracer = HitTestTracer();

  @override
  void dispose() {
    _nestedTracer.dispose();
    _siblingTracer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hit Test 流程机制')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPipeline(),
          const SizedBox(height: 16),
          _buildNestedSection(),
          const SizedBox(height: 16),
          _buildSiblingSection(),
          const SizedBox(height: 16),
          _buildDirectionSection(),
          const SizedBox(height: 16),
          _buildPitfallSection(),
          const SizedBox(height: 16),
          _buildApiSection(),
          const SizedBox(height: 16),
          _buildRelationSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 一、三段式流程
  // ----------------------------------------------------------
  Widget _buildPipeline() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('一次点击，其实分三步'),
          SizedBox(height: 8),
          Text(
            '很多人以为「谁画在上面谁就响应」，其实 Flutter 是严格按下面三步走的。'
            '本页用自定义 RenderObject「探针」把每一步都打印出来。',
            style: TextStyle(height: 1.6),
          ),
          SizedBox(height: 14),
          _PipelineStep(
            ordinal: '1',
            title: '询问：自顶向下（top-down）',
            desc: '从 RenderView 开始，父节点把同一个坐标传给子节点，'
                '问「这个坐标落在你或你子节点的范围内吗？」'
                '这就是 RenderBox.hitTest() 的递归下行。',
            color: Colors.orange,
          ),
          SizedBox(height: 10),
          _PipelineStep(
            ordinal: '2',
            title: '收集：由内到外（bottom-up）',
            desc: '命中的节点是在递归「返回」的路上被加入 HitTestResult 的，'
                '所以路径里最内层的节点排在第 0 位，最外层排在最后。',
            color: Colors.teal,
          ),
          SizedBox(height: 10),
          _PipelineStep(
            ordinal: '3',
            title: '分发：由内到外',
            desc: '指针事件沿 HitTestResult.path 顺序依次调用 handleEvent。'
                '结论就是：最内层最先收到事件，最外层最后收到。',
            color: Colors.indigo,
          ),
          SizedBox(height: 14),
          _CodeHint(
            '// RenderBox.hitTest —— 本页演示的就是括号里这个流程\n'
            'bool hitTest(BoxHitTestResult result, {required Offset position}) {\n'
            '  if (size.contains(position)) {                      // ① 坐标在我范围内吗\n'
            '    if (hitTestChildren(result, position: position)   // ② 先问子节点\n'
            '        || hitTestSelf(position)) {                   // ③ 再问自己\n'
            '      result.add(BoxHitTestEntry(this, position));    // ④ 命中 → 加入路径\n'
            '      return true;\n'
            '    }\n'
            '  }\n'
            '  return false;\n'
            '}',
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 二、实验一：嵌套层级
  // ----------------------------------------------------------
  Widget _buildNestedSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验一：嵌套层级 A ⊃ B ⊃ C'),
          const SizedBox(height: 6),
          Text(
            _abSelfHittable
                ? '当前 A、B 的 hitTestSelf = true：它们和「有实心背景的盒子」一样，'
                    '只要坐标落在自己的 220×220 / 140×140 范围内，自己就算命中。\n'
                    '把开关切回 false，它们才会变回「透明的转发层」。'
                : 'A、B 是「透明的转发层」：它们自己的 hitTestSelf 返回 false（自己不作表态），'
                    '只有在子树里有人命中时，才会顺着返回的路被带进路径。\n'
                    'C 里面有实心色块，是最内层真正可命中的那个。',
            style: const TextStyle(height: 1.6, fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: HitTestProbe(
                name: '根容器',
                tracer: _nestedTracer,
                selfHittable: true,
                isRoot: true,
                child: Container(
                  color: const Color(0xFFF7F7FA),
                  child: Center(
                    child: _frame(
                      tracer: _nestedTracer,
                      name: 'A（外层）',
                      size: 220,
                      color: Colors.orange,
                      label: 'A',
                      selfHittable: _abSelfHittable,
                      child: Center(
                        child: _frame(
                          tracer: _nestedTracer,
                          name: 'B（中层）',
                          size: 140,
                          color: Colors.green,
                          label: 'B',
                          selfHittable: _abSelfHittable,
                          borderIgnoresPointer: _bBorderIgnoresPointer,
                          child: Center(
                            child: HitTestProbe(
                              name: 'C（内层）',
                              tracer: _nestedTracer,
                              child: Container(
                                width: 70,
                                height: 70,
                                color: Colors.deepOrange,
                                alignment: Alignment.center,
                                child: const Text(
                                  'C',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildNestedToggles(),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.touch_app_outlined,
            text: '① 点中间橙色的 C：A / B / C 全部命中，路径是「由内到外」。\n'
                '② 默认（hitTestSelf = false）点 A、B 框内的空白：两个都「未命中」，'
                '事件穿透到根容器 —— 这就是「透明转发层」。\n'
                '③ 把开关①切到 true，再点 A 的内框（B 之外）和 B 的内框（C 之外）：'
                '它们会「分别」命中 A 和 B（日志里是「自身=true」）—— '
                '「透明」说的只是 hitTestSelf 的返回值，不等于这个盒子不会进路径。\n'
                '④ 开关①保持 false，只把开关②切成「裸 Container(decoration:)」：'
                '点 B 的空白会命中 B 和 A，但日志里是「子节点=true 自身=false」—— '
                '这是绕道子节点进路径的另一种方式。',
          ),
          const SizedBox(height: 14),
          _TracePanel(
            title: '追踪日志（实验一）',
            tracer: _nestedTracer,
            hint: '点击上面的示例区，这里会打印完整的「询问 → 收集 → 分发」过程',
          ),
          const SizedBox(height: 8),
          _PathPanel(tracer: _nestedTracer),
        ],
      ),
    );
  }

  /// 实验一的两个对照开关。
  ///
  /// 它们刚好对应「一个节点进入命中路径」的两种方式：
  /// - ① `hitTestSelf` 返回 true → **自身命中**（坐标落在自己的 size 内就算了）
  /// - ② 子节点命中 → **被顺路带进路径**
  ///
  /// 同一个点击位置，只改这两处，日志就会完全不同。
  Widget _buildNestedToggles() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '让 A / B 命中的两种方式（切完重新点一下框内的空白处）',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text('① A、B 自己的 hitTestSelf', style: _toggleLabelStyle),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('false（透明转发层）'),
                selected: !_abSelfHittable,
                onSelected: (_) => _switchAbSelfHittable(false),
              ),
              ChoiceChip(
                label: const Text('true（实心，自身可命中）'),
                selected: _abSelfHittable,
                onSelected: (_) => _switchAbSelfHittable(true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('② B 的边框怎么画（子节点替它命中）', style: _toggleLabelStyle),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('IgnorePointer 包住边框'),
                selected: _bBorderIgnoresPointer,
                onSelected: (_) => _switchBBorder(ignoresPointer: true),
              ),
              ChoiceChip(
                label: const Text('裸 Container(decoration:)'),
                selected: !_bBorderIgnoresPointer,
                onSelected: (_) => _switchBBorder(ignoresPointer: false),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _toggleSummary(),
            style: const TextStyle(fontSize: 12, height: 1.6, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  String _toggleSummary() {
    final self = _abSelfHittable
        ? 'A、B 的 hitTestSelf = true：点框内任何位置，它们自己就算命中（日志「自身=true」）。'
        : 'A、B 的 hitTestSelf = false：它们自己不作表态，只有子树里有人命中才会被带进路径。';
    final border = _bBorderIgnoresPointer
        ? 'B 的边框被 IgnorePointer 排除，不会替 B 命中。'
        : 'B 的边框是普通 DecoratedBox（矩形下恒可命中），会替 B 命中（日志「子节点=true 自身=false」）。';
    return '$self\n$border';
  }

  void _switchAbSelfHittable(bool value) {
    if (_abSelfHittable == value) return;
    setState(() => _abSelfHittable = value);
    _nestedTracer.clear();
  }

  void _switchBBorder({required bool ignoresPointer}) {
    if (_bBorderIgnoresPointer == ignoresPointer) return;
    setState(() => _bBorderIgnoresPointer = ignoresPointer);
    _nestedTracer.clear();
  }

  /// 构造一个「带边框外观」的透明转发层。
  ///
  /// 结构要点（顺序很重要）：
  /// 1. [HitTestProbe] 必须是最外层，这样坐标落在框外时它才有机会打印
  ///    「坐标不在范围内 → false」；如果把它塞进 SizedBox 里面，
  ///    外层 SizedBox 会先返回 false，探针根本不会被问到。
  /// 2. 里面是一个透明转发用的 SizedBox + Stack，探针自身 hitTestSelf 为 false。
  /// 3. 边框和标签用 [IgnorePointer] 单独绘制，从而排除在命中测试之外。
  ///
  /// 第 3 点是关键：如果直接用 `Container(decoration: BoxDecoration(border: ...))`，
  /// 由于 [RenderDecoratedBox.hitTestSelf] 会直接返回 BoxDecoration.hitTest(...)，
  /// 而后者在矩形下恒为 true，整块区域都会变成可命中的（见「顺带一个真实的坑」）。
  ///
  /// [selfHittable] 对应 [RenderBox.hitTestSelf]：false 时这一层只负责转发，
  /// true 时只要坐标落在自己的 size 内，自己就算命中（和 opaque 一个效果）。
  ///
  /// [borderIgnoresPointer] 就是用来切换这两种画法的开关：
  /// - true ：边框包在 [IgnorePointer] 里，只负责画，不参与命中（推荐）
  /// - false：边框就是普通 DecoratedBox，于是整个框内都变成可命中的
  Widget _frame({
    required HitTestTracer tracer,
    required String name,
    required double size,
    required Color color,
    required String label,
    Widget? child,
    bool selfHittable = false,
    bool borderIgnoresPointer = true,
  }) {
    final Widget frameVisual = Container(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.all(6),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );

    return HitTestProbe(
      name: name,
      tracer: tracer,
      selfHittable: selfHittable,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.expand(),
            if (borderIgnoresPointer)
              IgnorePointer(child: frameVisual)
            else
              frameVisual,
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // 三、实验二：兄弟节点（从后往前 + 命中即停）
  // ----------------------------------------------------------
  Widget _buildSiblingSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验二：兄弟节点的遍历顺序'),
          const SizedBox(height: 6),
          const Text(
            'Stack 里叠了三个兄弟节点。hitTestChildren 用的是 '
            'defaultHitTestChildren，它会「从最后一个子节点往前」遍历，'
            '并且一旦命中就立刻停止，不再问下面的兄弟。',
            style: TextStyle(height: 1.6, fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Text(
            '绘制顺序：L1 → L2 → L3（后画的盖在上面）\n'
            '询问顺序：L3 → L2 → L1（从后往前，命中即停）',
            style: TextStyle(
              height: 1.6,
              fontSize: 12.5,
              fontFamily: 'monospace',
              color: Color(0xFF3D5A80),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: HitTestProbe(
                name: '根容器',
                tracer: _siblingTracer,
                selfHittable: true,
                isRoot: true,
                child: Container(
                  color: const Color(0xFFF7F7FA),
                  child: Stack(
                    children: [
                      _siblingBox(
                        tracer: _siblingTracer,
                        name: 'L1（最底层）',
                        label: 'L1',
                        color: Colors.blue,
                        left: 8,
                        top: 8,
                      ),
                      _siblingBox(
                        tracer: _siblingTracer,
                        name: 'L2（中间）',
                        label: 'L2',
                        color: Colors.green,
                        left: 56,
                        top: 56,
                      ),
                      _siblingBox(
                        tracer: _siblingTracer,
                        name: 'L3（最上层）',
                        label: 'L3',
                        color: Colors.orange,
                        left: 104,
                        top: 104,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.layers_outlined,
            text: '① 只被 L3 盖住的地方（右下角）：日志里只有 L3，'
                'L1 / L2 根本没被询问过 —— 这就是「命中即停」。\n'
                '② 只被 L1 盖住的地方（左上角）：L3、L2 先后返回 false，'
                '最后才轮到 L1 命中。',
          ),
          const SizedBox(height: 14),
          _TracePanel(
            title: '追踪日志（实验二）',
            tracer: _siblingTracer,
            hint: '点击上方三个方块的不同区域，对比日志差异',
          ),
          const SizedBox(height: 8),
          _PathPanel(tracer: _siblingTracer),
        ],
      ),
    );
  }

  /// 实心方块：可命中的是它内部的 ColoredBox（behavior 相当于 opaque）。
  Widget _siblingBox({
    required HitTestTracer tracer,
    required String name,
    required String label,
    required Color color,
    required double left,
    required double top,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: HitTestProbe(
        name: name,
        tracer: tracer,
        child: Container(
          width: 120,
          height: 120,
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.all(6),
          color: color.withValues(alpha: 0.75),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // 四、方向对照
  // ----------------------------------------------------------
  Widget _buildDirectionSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('最容易记混的一点：方向'),
          SizedBox(height: 8),
          _DirectionRow(
            label: '询问 hitTest',
            arrow: '父 → 子（自顶向下）',
            desc: '父节点并不知道谁会被命中，只能挨个问下去',
            color: Colors.orange,
          ),
          SizedBox(height: 10),
          _DirectionRow(
            label: '收集路径',
            arrow: '子 → 父（由内到外）',
            desc: '命中是在递归返回的路上 add 的，所以最内层排最前',
            color: Colors.teal,
          ),
          SizedBox(height: 10),
          _DirectionRow(
            label: '事件分发',
            arrow: '子 → 父（由内到外）',
            desc: '沿 path 顺序调用 handleEvent，最内层最先收到',
            color: Colors.indigo,
          ),
          SizedBox(height: 14),
          Text(
            '还有一点：只有 PointerDown 会做新的一次命中测试，'
            '后续的 Move / Up 会复用这条已经算好的路径 —— '
            '所以按下之后手指滑出这个控件，它依然能收到 Move / Up。',
            style: TextStyle(height: 1.6, fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 五、一个真实的坑
  // ----------------------------------------------------------
  Widget _buildPitfallSection() {
    return _card(
      color: Colors.red.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('顺带一个真实的坑：「只画了边框」也能点'),
          SizedBox(height: 8),
          Text(
            '实验一里 B 之所以「点到空白就穿透」，唯一的原因是那圈边框被包在 '
            'IgnorePointer 里 —— 而不是因为「边框中间是透明的」。'
            '一旦老老实实写成下面这样，行为立刻反转：',
            style: TextStyle(height: 1.6, fontSize: 13),
          ),
          SizedBox(height: 10),
          _CodeHint(
            "// 看起来只是画了条边框，中间全透明\n"
            "Container(\n"
            "  decoration: BoxDecoration(border: Border.all(color: Colors.red)),\n"
            "  child: ...,\n"
            ")\n"
            "// 但它整块区域都变成可命中的 —— 下层收不到点击了",
          ),
          SizedBox(height: 10),
          Text(
            '原因：Container 带 decoration 时会生成 RenderDecoratedBox，'
            '它的 hitTestSelf 直接返回 BoxDecoration.hitTest(...)，'
            '而该方法在 shape 为 rectangle 时恒为 true。\n'
            '注意措辞：B 自己没有作任何表态，是它的「子节点（那圈边框）」命中了，'
            'B 才被顺路带进路径 —— 日志里会写成「子节点=true、自身=false」。',
            style: TextStyle(height: 1.6, fontSize: 13),
          ),
          SizedBox(height: 8),
          Text(
            '结论：hitTest 只看 hitTestSelf 和子树，完全不管你「看起来」有没有填充。'
            '所以「只画了边框」不代表「中间是空的、可以点穿」；'
            '要让它不参与命中就用 IgnorePointer 包住 —— '
            '实验一顶部那个开关可以直接对比这两种结果。',
            style: TextStyle(height: 1.6, fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 六、关键 API
  // ----------------------------------------------------------
  Widget _buildApiSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('关键 API 速查'),
          SizedBox(height: 10),
          _ApiRow(
            'hitTest(result, position)',
            '入口。返回「自己或子树」是否被命中；命中时把自己加入 result',
          ),
          _ApiRow(
            'hitTestChildren(result)',
            '询问子节点。defaultHitTestChildren 会从最后一个子节点往前遍历，命中即停',
          ),
          _ApiRow(
            'hitTestSelf(position)',
            '自己是否算命中。默认 false；ColoredBox / Image / 有 decoration 的盒子为 true',
          ),
          _ApiRow(
            'result.add(entry)',
            '把命中的节点登记进 HitTestResult，登记顺序即「由内到外」',
          ),
          _ApiRow(
            'addWithPaintOffset / addWithPaintTransform',
            '先把坐标换算到子节点坐标系再问子节点 —— 所以 offset / transform 会影响命中',
          ),
          _ApiRow(
            'HitTestResult.path',
            '最终的命中路径；dispatchEvent 就是按这个顺序逐个调用 handleEvent',
          ),
          SizedBox(height: 14),
          Divider(),
          SizedBox(height: 10),
          Text(
            '排查「点不动 / 点到了不该点的」问题时，'
            '第一步永远是确认 hitTestSelf 返回了什么、'
            '以及是不是有 opaque 的兄弟把事件抢走了。',
            style: TextStyle(height: 1.6, fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 七、与 HitTestBehavior 页面的关系
  // ----------------------------------------------------------
  Widget _buildRelationSection() {
    return _card(
      color: Colors.blue.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('和 HitTestBehavior 页面的关系'),
          SizedBox(height: 8),
          Text(
            '本页讲的是「流程」：什么时候问、按什么顺序收集、按什么顺序分发。\n'
            'HitTestBehavior 页面讲的是「规则」：一个渲染对象在流程中'
            '如何表态（deferToChild / opaque / translucent）。',
            style: TextStyle(height: 1.6),
          ),
          SizedBox(height: 8),
          Text(
            '一句话把两者串起来：behavior 影响的是 hitTestSelf 的返回值'
            '和「要不要把自己加进路径」，而整套询问 / 收集 / 分发的骨架不变。',
            style: TextStyle(height: 1.6, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 通用小组件
// ============================================================

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
          child: Text(text, style: const TextStyle(height: 1.6, fontSize: 13)),
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

/// 方向对照的一行
class _DirectionRow extends StatelessWidget {
  const _DirectionRow({
    required this.label,
    required this.arrow,
    required this.desc,
    required this.color,
  });

  final String label;
  final String arrow;
  final String desc;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                arrow,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ApiRow extends StatelessWidget {
  const _ApiRow(this.name, this.description);

  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 7,
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 终端风格的追踪日志面板（按时间先后自上而下，自动停在最新处）
class _TracePanel extends StatelessWidget {
  const _TracePanel({
    required this.title,
    required this.tracer,
    required this.hint,
  });

  final String title;
  final HitTestTracer tracer;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle(title),
            ListenableBuilder(
              listenable: tracer,
              builder: (context, _) => TextButton.icon(
                onPressed: tracer.lines.isEmpty ? null : tracer.clear,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('清空'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ListenableBuilder(
          listenable: tracer,
          builder: (context, _) {
            final lines = tracer.lines;
            return Container(
              height: 250,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: lines.isEmpty
                  ? Center(
                      child: Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12.5,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      // reverse：初始停在底部，让最新的几行始终可见；
                      // 整体阅读顺序仍是「旧 → 新」，符合递归下行的直觉
                      reverse: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in lines)
                            Text(
                              line,
                              style: TextStyle(
                                color: _lineColor(line),
                                fontSize: 11,
                                fontFamily: 'monospace',
                                height: 1.6,
                              ),
                            ),
                        ],
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }

  Color _lineColor(String line) {
    if (line.contains('✔')) return const Color(0xFF7CE38B);
    if (line.contains('✗')) return const Color(0xFFFF8A80);
    if (line.contains('📥')) return const Color(0xFF7FD1FF);
    if (line.contains('───')) return const Color(0x8AFFFFFF);
    return const Color(0xFFD5D5D5);
  }
}

/// 最近一次的命中路径
class _PathPanel extends StatelessWidget {
  const _PathPanel({required this.tracer});

  final HitTestTracer tracer;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tracer,
      builder: (context, _) {
        final path = tracer.path;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '本次 HitTestResult.path（由内到外）',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 6),
              if (path.isEmpty)
                const Text(
                  '还没有命中记录。',
                  style: TextStyle(fontSize: 12, color: Colors.black38),
                )
              else
                ...path.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Colors.teal,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${e.key}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              e.value,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 8),
              const Text(
                '真实路径里还包含 Padding / Center / ColoredBox 等框架内部节点，'
                '这里只列出了本页埋的探针。',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black38,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
