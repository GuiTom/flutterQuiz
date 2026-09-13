import 'package:flutter/material.dart';

/// ============================================================
/// HitTestBehavior 学习 Demo
/// ============================================================
///
/// 背景知识：什么是「命中测试（Hit Test）」？
/// 当手指按下屏幕时，Flutter 会从根节点开始，自顶向下递归地询问渲染树：
/// 「这个坐标有没有落在你的范围内？有没有落在你子节点的范围内？」
/// 沿途被命中的 RenderObject 会被收集成一条 HitTestResult 路径（从下到上），
/// 之后指针事件才会沿着这条路径分发下去。
///
/// HitTestBehavior 就是控制「一个 RenderProxyBox 该如何参与命中测试」的属性。
/// 它只有三个取值：
///
/// 1. deferToChild（默认）
///    只有当「子节点」被命中时，自己才算被命中。
///    推论：如果一个容器本身没画任何东西（透明）、里面也没有可命中的子 Widget，
///    那么点上去不会有任何反应 —— 这是最常见的踩坑点。
///
/// 2. opaque（不透明）
///    只要坐标落在自己的 size 范围内，自己就算被命中（不看子节点结果）。
///    并且它会「遮挡」同一父节点下、位于其下方的兄弟节点，让下面收不到事件。
///
/// 3. translucent（半透明）
///    只要坐标落在自己的 size 范围内，自己就算被命中，但「不遮挡」下方的兄弟节点。
///    所以如果它本身没有命中到子节点，下面一层的节点也能一起收到事件。
///
/// 本 Demo 用两个重叠的方块来观察三者的差异，并用 Listener 打印原始的命中结果
/// （Listener 只监听指针事件、不参与手势竞争，所以能最真实地反映「谁被命中了」）。
///
/// 注意：日常开发里更常用 GestureDetector，但 GestureDetector 内部也是先做命中测试，
/// 再让命中的识别器进入「手势竞技场」竞争，所以本 Demo 的结论同样适用。
class HitTestBehaviorPage extends StatefulWidget {
  const HitTestBehaviorPage({super.key});

  @override
  State<HitTestBehaviorPage> createState() => _HitTestBehaviorPageState();
}

class _HitTestBehaviorPageState extends State<HitTestBehaviorPage> {
  /// 顶层方块 A 当前使用的命中测试行为（可切换）
  HitTestBehavior _topBehavior = HitTestBehavior.deferToChild;

  /// 命中日志（最新的在最前面）
  final List<String> _logs = [];

  void _log(String who) {
    final now = DateTime.now();
    final t = '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    setState(() {
      _logs.insert(0, '[$t]  被命中 →  $who');
      if (_logs.length > 20) _logs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HitTestBehavior')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntro(),
          const SizedBox(height: 16),
          _buildSelector(),
          const SizedBox(height: 12),
          _buildPlayground(),
          const SizedBox(height: 12),
          _buildExpectation(),
          const SizedBox(height: 16),
          _buildLogPanel(),
          const SizedBox(height: 16),
          _buildSummary(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 一、概念说明
  // ----------------------------------------------------------
  Widget _buildIntro() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('HitTestBehavior 是什么？'),
          SizedBox(height: 8),
          Text(
            '手指按下时，Flutter 会先做「命中测试」收集一条被命中的 RenderObject 路径，'
            '再把事件分发下去。HitTestBehavior 决定一个渲染对象如何参与这个过程。',
            style: TextStyle(height: 1.6),
          ),
          SizedBox(height: 8),
          Text(
            '共有三个取值：deferToChild（默认）、opaque、translucent。'
            '下面切换取值并点击方块，观察右侧日志里谁被命中。',
            style: TextStyle(height: 1.6, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 二、行为切换
  // ----------------------------------------------------------
  Widget _buildSelector() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('顶层方块 A 的 behavior'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HitTestBehavior.values.map((behavior) {
              final selected = behavior == _topBehavior;
              return ChoiceChip(
                label: Text(_behaviorName(behavior)),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _topBehavior = behavior;
                    _logs.clear();
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _behaviorName(HitTestBehavior b) {
    switch (b) {
      case HitTestBehavior.deferToChild:
        return 'deferToChild';
      case HitTestBehavior.opaque:
        return 'opaque';
      case HitTestBehavior.translucent:
        return 'translucent';
    }
  }

  // ----------------------------------------------------------
  // 三、交互实验区
  // ----------------------------------------------------------
  Widget _buildPlayground() {
    return Container(
      height: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          // 底层 B：红色实心块（自带背景色），天生可被命中
          Positioned(
            left: 8,
            top: 80,
            child: _hitBox(
              size: 150,
              color: Colors.red,
              label: '底层 B（红）',
              behavior: HitTestBehavior.opaque,
              onHit: () => _log('底层 B（红）'),
            ),
          ),
          // 顶层 A：透明容器 + 一个可命中的蓝色子 Widget
          Positioned(
            left: 90,
            top: 16,
            child: _hitBox(
              size: 150,
              color: null, // 透明：deferToChild 时自身不可命中
              label: '顶层 A（透明）',
              behavior: _topBehavior,
              onHit: () => _log('顶层 A（蓝）'),
              child: Container(
                width: 64,
                height: 64,
                color: Colors.blue,
                alignment: Alignment.center,
                child: const Text(
                  '子\nWidget',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建一个参与命中测试的方块。
  ///
  /// - 真正参与命中测试的是外层 [Listener]，它的 [HitTestBehavior] 决定命中规则；
  /// - 若 [color] 不为空，用带背景色的 Container 作子节点（有背景色 → 自身可命中）；
  /// - 若 [color] 为空，则用一个透明容器 + [child]（子 Widget 才是可命中的目标）；
  /// - 最外层的边框与文字用 [IgnorePointer] 包住，保证「只用于展示、不参与命中」。
  Widget _hitBox({
    required double size,
    required Color? color,
    required String label,
    required HitTestBehavior behavior,
    required VoidCallback onHit,
    Widget? child,
  }) {
    final borderColor = color ?? Colors.blue;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: behavior,
            onPointerDown: (_) => onHit(),
            child: color != null
                ? Container(color: color)
                : Align(alignment: Alignment.topRight, child: child),
          ),
          // 仅用于可视化边界和标签，不参与命中测试
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: borderColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 四、当前取值的预期结果
  // ----------------------------------------------------------
  Widget _buildExpectation() {
    return _card(
      color: Colors.blue.withValues(alpha: 0.06),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _expectationText(),
              style: const TextStyle(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  String _expectationText() {
    switch (_topBehavior) {
      case HitTestBehavior.deferToChild:
        return '默认行为。A 自身是透明的，所以只有点到它里面的「蓝色子 Widget」时，'
            'A 才会被命中；点到 A 的透明空白处不会命中，事件会穿透到下面的 B。';
      case HitTestBehavior.opaque:
        return 'A 整个 150×150 区域都算命中，而且会「遮挡」下面的 B。'
            '所以只要落在 A 的范围内，就只有 A 收到事件，重叠区的 B 收不到。';
      case HitTestBehavior.translucent:
        return 'A 整个区域都算命中，但「不遮挡」B。'
            '所以在 A 的透明空白处（没盖住蓝色子 Widget）点击时，A 和 B 会同时收到事件。';
    }
  }

  // ----------------------------------------------------------
  // 五、命中日志
  // ----------------------------------------------------------
  Widget _buildLogPanel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle('命中日志'),
              TextButton.icon(
                onPressed: _logs.isEmpty ? null : () => setState(_logs.clear),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 150,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      '点击上方方块，查看命中结果…',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) => Text(
                      _logs[index],
                      style: const TextStyle(
                        color: Color(0xFF7CE38B),
                        fontSize: 13,
                        fontFamily: 'monospace',
                        height: 1.7,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 六、对照总结
  // ----------------------------------------------------------
  Widget _buildSummary() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('三者对比'),
          const SizedBox(height: 12),
          const _SummaryHeader(),
          const Divider(height: 1),
          const _SummaryRow(
            behavior: 'deferToChild',
            self: '否（看子节点）',
            block: '否',
            useCase: '默认值，随子节点',
          ),
          const Divider(height: 1),
          const _SummaryRow(
            behavior: 'opaque',
            self: '是',
            block: '是（遮挡下层）',
            useCase: '抢占点击、吸底遮罩',
          ),
          const Divider(height: 1),
          const _SummaryRow(
            behavior: 'translucent',
            self: '是',
            block: '否（放行下层）',
            useCase: '既要自己响应、又不挡下面',
          ),
          const SizedBox(height: 12),
          const Text(
            '小结：想让「看不见的容器」也能响应点击 → 用 opaque；'
            '想让点击既能落在自己身上、又能继续传给下层 → 用 translucent；'
            '只依赖子节点决定是否可点 → 保持默认 deferToChild。',
            style: TextStyle(height: 1.6, color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 通用小组件
  // ----------------------------------------------------------
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

/// 对比表格的表头
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Colors.black54,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('取值', style: style)),
          Expanded(flex: 3, child: Text('自身命中', style: style)),
          Expanded(flex: 3, child: Text('遮挡下层', style: style)),
          Expanded(flex: 4, child: Text('典型用途', style: style)),
        ],
      ),
    );
  }
}

/// 对比表格的一行：自身是否命中 / 是否遮挡下层 / 典型用途
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.behavior,
    required this.self,
    required this.block,
    required this.useCase,
  });

  final String behavior;
  final String self;
  final String block;
  final String useCase;

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
    const cellStyle = TextStyle(fontSize: 12, color: Colors.black87, height: 1.4);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(behavior, style: headerStyle),
          ),
          Expanded(
            flex: 3,
            child: Text(self, style: cellStyle),
          ),
          Expanded(
            flex: 3,
            child: Text(block, style: cellStyle),
          ),
          Expanded(
            flex: 4,
            child: Text(useCase, style: cellStyle),
          ),
        ],
      ),
    );
  }
}
