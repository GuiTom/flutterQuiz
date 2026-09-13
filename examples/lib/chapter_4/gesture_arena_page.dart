import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// ============================================================
/// 手势竞争（Gesture Arena）学习 Demo
/// ============================================================
///
/// 前面两页（4.1 点击测试、4.2 HitTestBehavior）回答的是「事件能到谁手里」；
/// 本页回答的是「到了之后，如果同一时刻有多个识别器都想要，归谁」。
///
/// ## 为什么需要竞技场
///
/// 一次手指按下，命中路径上往往不止一个识别器：
/// 内层按钮的 Tap、外层卡片的 Tap、列表的纵向拖拽、长按……
/// Flutter 不用「谁先响应谁赢」（那会导致抖动和不确定），
/// 而是给每个指针开一个 [GestureArenaManager] 里的「竞技场」，
/// 让所有候选者按同一套规则表态，最后只留一个赢家。
///
/// 注意区分两件事（这是最容易混淆的地方）：
/// - **能不能进竞技场**：由命中测试 + [HitTestBehavior] 决定（见 4.1 / 4.2）
/// - **进来之后谁赢**：由竞技场裁决，和 [HitTestBehavior] 完全无关
///
/// ## 一次竞技场的完整时序
///
/// 1. **入场**：`PointerDownEvent` 沿命中路径分发（由内到外），
///    路径上每个 [RawGestureDetector] 把自己持有的识别器 `addPointer` 进竞技场。
///    所以**入场顺序 = 命中路径顺序 = 由内到外**，这就是「内层优先」的来源。
/// 2. **关门**：down 分发完毕后，`GestureBinding` 调 `gestureArena.close(pointer)`，
///    此后不再接受新成员。
/// 3. **表态**：每个成员随时可以 [GestureRecognizer.resolve] 表态：
///    - `accepted`：认领这次手势，**立刻**成为唯一赢家（其他人马上出局）
///    - `rejected`：主动退出（例如拖动识别器发现自己不满足条件）
///    - `hold` / `release`：先攥住不表态，稍后再决定（双击识别器等第二次点击用的就是它）
/// 4. **清算**：`PointerUpEvent` 触发 `gestureArena.sweep(pointer)`。
///    如果此时还没人认领，就**让排队最靠前的那个赢**（`members.first`），其余全部出局。
///
/// ## 从时序能推出三个结论
///
/// - 「先到先得」只体现在第 4 步的 sweep：没人主动认领时，**最内层**的那个赢。
/// - 「主动认领」可以越级：外层挂 [EagerGestureRecognizer]，入场瞬间就 `resolve(accepted)`，
///   内层再靠内也抢不过 —— 实验一的开关就是这个。
/// - 「攥住不放」会造成延迟：挂了 `onDoubleTap` 之后，单击的 `onTap` 要等
///   [kDoubleTapTimeout]（300ms）才触发，因为双击识别器一直 hold 着竞技场 —— 实验二能测出来。
///
/// 本页用两种手段观察竞技场：
/// - 自己写探针识别器，把「入场 / 获胜 / 出局」三个时刻画成看板（实验一、二）
/// - 打开框架自己的 `debugPrintGestureArenaDiagnostics`，看 `GestureArenaManager` 的原话
class GestureArenaPage extends StatefulWidget {
  const GestureArenaPage({super.key});

  @override
  State<GestureArenaPage> createState() => _GestureArenaPageState();
}

// ============================================================
// 一、看板数据模型
// ============================================================

/// 识别器在竞技场里的三种状态。
///
/// 竞技场只暴露两个可观察的时刻（[GestureArenaMember] 接口）：
/// [GestureRecognizer.acceptGesture] 被调用 = 获胜，
/// [GestureRecognizer.rejectGesture] 被调用 = 出局；
/// 在此之前一律是「排队中」。
enum ArenaMemberState {
  /// 已入场，尚未裁决
  queued,

  /// 获胜（收到了 acceptGesture）
  won,

  /// 出局（收到了 rejectGesture）
  lost,
}

/// 竞技场里的一个成员（就是一个识别器实例）。
class ArenaMember {
  ArenaMember({required this.name, required this.kind, required this.order})
    : enteredAt = DateTime.now();

  /// 成员名字，例如「内层 Tap(B)」
  final String name;

  /// 识别器类型，例如 `TapGestureRecognizer`
  final String kind;

  /// 入场序号，从 1 开始 —— 也就是它在竞技场里的排队位置。
  ///
  /// 因为入场顺序 = 命中路径顺序（由内到外），所以序号 1 就是最内层那个，
  /// sweep 没人认领时赢的就是它。
  final int order;

  final DateTime enteredAt;

  ArenaMemberState state = ArenaMemberState.queued;

  /// 从入场到被裁决花的时间。
  ///
  /// 这个数字是「竞技场把裁决拖了多久」的直接证据：
  /// - 拖动 / 长按主动认领 → 几毫秒
  /// - 单击遇上 onDoubleTap → 300ms 上下
  Duration? elapsed;

  void settle(ArenaMemberState result) {
    state = result;
    elapsed = DateTime.now().difference(enteredAt);
  }
}

/// 记录「一次按下 → 裁决」的完整过程，供看板渲染。
class ArenaBoard extends ChangeNotifier {
  final List<ArenaMember> _members = <ArenaMember>[];
  final List<String> _log = <String>[];
  int? _pointer;
  int _round = 0;
  ArenaMember? _winner;

  List<ArenaMember> get members => List<ArenaMember>.unmodifiable(_members);

  /// 日志按时间倒序（最新的在下标 0）
  List<String> get log => List<String>.unmodifiable(_log);

  /// 当前竞技场绑定的指针 id —— 换一个指针就是新一轮
  int? get pointer => _pointer;

  int get round => _round;

  ArenaMember? get winner => _winner;

  bool get isEmpty => _members.isEmpty;

  /// 成员入场（在识别器的 `addAllowedPointer` 里上报）。
  void enter(String name, String kind, int pointer) {
    if (_pointer != pointer) {
      // 指针变了 = 上一轮已经结束，开一个新的竞技场
      _pointer = pointer;
      _round++;
      _members.clear();
      _winner = null;
      _log.insert(0, '──── 第 $_round 回合 · 指针 #$pointer 建立竞技场 ────');
    }
    _members.add(ArenaMember(name: name, kind: kind, order: _members.length + 1));
    _log.insert(0, '入场 ${_members.length}. $name  ($kind)');
    notifyListeners();
  }

  /// 获胜（在识别器的 `acceptGesture` 里上报）。
  void win(String name, int pointer) {
    final ArenaMember? member = _find(pointer, name);
    if (member == null) return;
    member.settle(ArenaMemberState.won);
    _winner = member;
    _log.insert(
      0,
      '✔ ${member.order}. $name 获胜 ← acceptGesture 被调用',
    );
    notifyListeners();
  }

  /// 出局（在识别器的 `rejectGesture` 里上报）。
  void lose(String name, int pointer) {
    final ArenaMember? member = _find(pointer, name);
    if (member == null) return;
    member.settle(ArenaMemberState.lost);
    _log.insert(
      0,
      '✗ ${member.order}. $name 出局 ← rejectGesture 被调用',
    );
    notifyListeners();
  }

  ArenaMember? _find(int pointer, String name) {
    // 上一回合迟到的回调（例如双击超时）直接丢掉
    if (_pointer != pointer) return null;
    for (final ArenaMember member in _members) {
      if (member.name == name) return member;
    }
    return null;
  }

  void clear() {
    _members.clear();
    _log.clear();
    _winner = null;
    _pointer = null;
    notifyListeners();
  }
}

/// 一个只负责「存行 + 通知刷新」的小容器，给框架日志面板用。
class LogStore extends ChangeNotifier {
  final List<String> _lines = <String>[];

  List<String> get lines => List<String>.unmodifiable(_lines);

  void add(String line) {
    _lines.add(line);
    if (_lines.length > 300) _lines.removeAt(0);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}

// ============================================================
// 二、带探针的识别器
// ============================================================

/// 给识别器装上「入场 / 获胜 / 出局」三个探针。
///
/// 入场只能自己上报（框架没有对应回调），
/// 而胜负只有 [acceptGesture] / [rejectGesture] 两个回调能观察到。
mixin _ArenaMemberLogger on GestureRecognizer {
  String get arenaName;

  String get arenaKind;

  ArenaBoard get arenaBoard;

  void _reportEnter(int pointer) =>
      arenaBoard.enter(arenaName, arenaKind, pointer);

  void _reportWin(int pointer) => arenaBoard.win(arenaName, pointer);

  void _reportLose(int pointer) => arenaBoard.lose(arenaName, pointer);
}

/// 普通 Tap 识别器：**不主动认领**，排队等裁决。
///
/// 它获胜的两种途径：
/// - 竞技场里只剩它一个 → 框架在微任务里判它赢（几乎无延迟）
/// - 一直没人认领，up 时 sweep 选中排在最前面的它（可能有延迟，见双击）
class _ProbeTap extends TapGestureRecognizer with _ArenaMemberLogger {
  _ProbeTap({
    required this.arenaName,
    required this.arenaBoard,
    VoidCallback? andThen,
  }) {
    onTap = andThen;
  }

  @override
  final String arenaName;

  @override
  final ArenaBoard arenaBoard;

  @override
  String get arenaKind => 'TapGestureRecognizer';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _reportEnter(event.pointer);
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    _reportWin(pointer);
    super.acceptGesture(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    _reportLose(pointer);
    super.rejectGesture(pointer);
  }
}

/// 抢跑型识别器：**入场瞬间就认领**（见 [EagerGestureRecognizer.addAllowedPointer]）。
///
/// 它的实战用途是 [AndroidView.gestureRecognizers]：让原生 View 里的 HTML / 原生控件
/// 拿到全部手势，不被 Flutter 的手势系统截胡。
///
/// 注意它抢到手之后什么都不做（没有任何回调），
/// 所以本轮手势会「凭空消失」—— 这正是实验一里内层 onTap 不再触发的原因。
class _ProbeEager extends EagerGestureRecognizer with _ArenaMemberLogger {
  _ProbeEager({required this.arenaName, required this.arenaBoard});

  @override
  final String arenaName;

  @override
  final ArenaBoard arenaBoard;

  @override
  String get arenaKind => 'EagerGestureRecognizer';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _reportEnter(event.pointer);
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    _reportWin(pointer);
    super.acceptGesture(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    _reportLose(pointer);
    super.rejectGesture(pointer);
  }
}

/// 双击识别器：它是「hold 住竞技场」的典型代表。
///
/// 第一次抬手时它不走，而是把竞技场攥在手里等第二次点击；
/// 这期间**所有其他成员都无法被裁决**，代价就是单击回调被推迟
/// [kDoubleTapTimeout]（300ms）。
class _ProbeDoubleTap extends DoubleTapGestureRecognizer
    with _ArenaMemberLogger {
  _ProbeDoubleTap({
    required this.arenaName,
    required this.arenaBoard,
    VoidCallback? andThen,
  }) {
    onDoubleTap = andThen;
  }

  @override
  final String arenaName;

  @override
  final ArenaBoard arenaBoard;

  @override
  String get arenaKind => 'DoubleTapGestureRecognizer';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _reportEnter(event.pointer);
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    _reportWin(pointer);
    super.acceptGesture(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    _reportLose(pointer);
    super.rejectGesture(pointer);
  }
}

/// 长按识别器：按住超过 [kLongPressTimeout]（500ms）就主动认领。
class _ProbeLongPress extends LongPressGestureRecognizer
    with _ArenaMemberLogger {
  _ProbeLongPress({
    required this.arenaName,
    required this.arenaBoard,
    VoidCallback? andThen,
  }) {
    onLongPress = andThen;
  }

  @override
  final String arenaName;

  @override
  final ArenaBoard arenaBoard;

  @override
  String get arenaKind => 'LongPressGestureRecognizer';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _reportEnter(event.pointer);
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    _reportWin(pointer);
    super.acceptGesture(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    _reportLose(pointer);
    super.rejectGesture(pointer);
  }
}

/// 水平拖动识别器：横向位移超过 [kTouchSlop]（18 逻辑像素）就主动认领。
class _ProbeHorizontalDrag extends HorizontalDragGestureRecognizer
    with _ArenaMemberLogger {
  _ProbeHorizontalDrag({
    required this.arenaName,
    required this.arenaBoard,
  });

  @override
  final String arenaName;

  @override
  final ArenaBoard arenaBoard;

  @override
  String get arenaKind => 'HorizontalDragGestureRecognizer';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _reportEnter(event.pointer);
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    _reportWin(pointer);
    super.acceptGesture(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    _reportLose(pointer);
    super.rejectGesture(pointer);
  }
}

/// 垂直拖动识别器。
class _ProbeVerticalDrag extends VerticalDragGestureRecognizer
    with _ArenaMemberLogger {
  _ProbeVerticalDrag({
    required this.arenaName,
    required this.arenaBoard,
  });

  @override
  final String arenaName;

  @override
  final ArenaBoard arenaBoard;

  @override
  String get arenaKind => 'VerticalDragGestureRecognizer';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _reportEnter(event.pointer);
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    _reportWin(pointer);
    super.acceptGesture(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    _reportLose(pointer);
    super.rejectGesture(pointer);
  }
}

// ============================================================
// 三、页面
// ============================================================

class _GestureArenaPageState extends State<GestureArenaPage> {
  static const TextStyle _toggleLabelStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
  );

  // ---------- 实验一：内外层抢 Tap ----------
  final ArenaBoard _nestedBoard = ArenaBoard();

  /// 外层用 EagerGestureRecognizer（入场即认领）还是普通 Tap（排队）
  bool _outerEager = false;

  String _nestedResult =
      '还没点过。先点内框 B，看内层怎么赢；再把外框切成 Eager 重来一次。';

  // ---------- 实验二：一个区域里五个手势 ----------
  final ArenaBoard _multiBoard = ArenaBoard();

  /// 是否挂载 DoubleTap —— 关掉它能明显看到单击回调变快
  bool _multiWithDoubleTap = true;

  String _multiResult = '在这个区域里点一下 / 双击 / 长按 / 横拖 / 竖拖，看板会实时刷新裁决过程。';

  // ---------- 进阶：框架内部日志 ----------
  final LogStore _frameworkLog = LogStore();

  bool _diagnostics = false;

  DebugPrintCallback _originalDebugPrint = debugPrint;

  bool _printHooked = false;

  @override
  void dispose() {
    // 退出页面务必还原，否则会影响整个 App 的日志输出
    _restorePrint();
    debugPrintGestureArenaDiagnostics = false;
    debugPrintRecognizerCallbacksTrace = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手势竞争（Gesture Arena）')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntro(),
          const SizedBox(height: 16),
          _buildNestedSection(),
          const SizedBox(height: 16),
          _buildMultiSection(),
          const SizedBox(height: 16),
          _buildConflictSection(),
          const SizedBox(height: 16),
          _buildDiagnosticsSection(),
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
          _SectionTitle('为什么要有「竞技场」'),
          SizedBox(height: 8),
          Text(
            '手指按下时，命中路径上可能同时有好几个识别器想要这根手指：'
            '内层按钮的 Tap、外层卡片的 Tap、列表的纵向拖拽、长按……'
            '如果靠「谁先响应谁赢」，行为会变得不确定。'
            'Flutter 的做法是给每个指针开一个竞技场（arena），'
            '让所有候选者按同一套规则表态，最后只留一个赢家。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 10),
          Text(
            '注意别把两件事混在一起：',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 6),
          _BulletLine('能不能进竞技场 —— 由命中测试和 HitTestBehavior 决定（4.1 / 4.2）'),
          _BulletLine('进来之后谁赢 —— 由竞技场裁决，和 HitTestBehavior 无关'),
          SizedBox(height: 16),
          _SectionTitle('一次竞技场的完整时序'),
          SizedBox(height: 10),
          _PipelineStep(
            ordinal: '1',
            title: '入场（PointerDown）',
            desc: 'down 事件沿命中路径分发。路径上每个 RawGestureDetector 把自己的识别器'
                '塞进竞技场。入场顺序 = 命中路径顺序 = 由内到外，'
                '这就是「内层优先」的根本原因。',
            color: Color(0xFF3D5A80),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '2',
            title: '关门（close）',
            desc: 'down 分发完毕后框架调用 gestureArena.close(pointer)，'
                '此后不再接受新成员，但已有的成员还都可以慢慢表态。',
            color: Color(0xFF5C6BC0),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '3',
            title: '表态：accept / reject / hold',
            desc: 'accept = 认领，立刻成为唯一赢家（其他人马上出局）；'
                'reject = 主动退出；hold = 先攥着不表态（双击识别器在等第二次点击时就这么干）。'
                '拖动超过 18px、长按满 500ms 都会触发 accept。',
            color: Color(0xFF2E7D32),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '4',
            title: '清算（PointerUp → sweep）',
            desc: '抬手时如果还没人认领，就让排队最靠前的那个赢（members.first），'
                '其余全部出局。所谓「先到先得」，只发生在这里。',
            color: Color(0xFFC62828),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 实验一：内层与外层抢同一个 Tap
  // ----------------------------------------------------------
  Widget _buildNestedSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验一：内层和外层抢同一个 Tap'),
          const SizedBox(height: 8),
          const Text(
            '外框 A 和内框 B 各自挂了一个 Tap。点 B 时两个识别器都在命中路径上，'
            '竞技场里就有两个成员 —— 谁能把这次手势拿走？',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 14),
          _buildNestedArena(),
          const SizedBox(height: 14),
          _buildNestedToggle(),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.touch_app_outlined,
            text:
                '① 默认（外层 = 普通 Tap）：点 B → 内层【获胜】、外层【出局】。'
                '两个识别器都入场了，但 Tap 从不主动认领，双方都只是排队。'
                '抬手时框架执行 sweep（清算），把收益判给排队最靠前的内层，外层当场出局。'
                '所以「内层优先」不是内层更主动，纯粹是入场顺序决定的。\n'
                '② 把外层换成 EagerGestureRecognizer：点 B → 外层【获胜】、内层【出局】。'
                '它入场的瞬间就 resolve(accepted) 主动认领，内层再靠内也来不及；'
                '而且它赢了之后没有任何回调 —— 所以内层的 onTap 不会触发。\n'
                '③ 两次实验里「入场」的顺序都是内层在前（看板序号 1 是内层），'
                '说明排队位置并不能决定胜负，能不能更早认领才能。',
          ),
          const SizedBox(height: 14),
          ArenaBoardView(board: _nestedBoard, hint: '还没人入场 —— 点一下上面的框试试'),
        ],
      ),
    );
  }

  Widget _buildNestedArena() {
    return Center(
      child: Column(
        children: [
          _arenaDetector(
            board: _nestedBoard,
            arenaName: '外层 Tap(A)',
            onTap: () => _flashNested('外层 Tap(A) 的 onTap 触发'),
            eager: _outerEager,
            child: _box(
              size: 220,
              color: const Color(0xFF3D5A80),
              label: 'A（外层）',
              child: _arenaDetector(
                board: _nestedBoard,
                arenaName: '内层 Tap(B)',
                onTap: () => _flashNested('内层 Tap(B) 的 onTap 触发'),
                child: _box(
                  size: 118,
                  color: const Color(0xFFC05621),
                  label: 'B',
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _nestedResult,
            textAlign: TextAlign.center,
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

  Widget _buildNestedToggle() {
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
            '外层的抢法（切完重新点一下内框 B）',
            style: _toggleLabelStyle,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('普通 Tap（排队）'),
                selected: !_outerEager,
                onSelected: (_) => _setOuterEager(false),
              ),
              ChoiceChip(
                label: const Text('Eager（入场即认领）'),
                selected: _outerEager,
                onSelected: (_) => _setOuterEager(true),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _outerEager
                ? '当前：外层是 EagerGestureRecognizer。它入场瞬间就认领，'
                      '然后什么都不做 —— 内层的 onTap 不会触发。'
                : '当前：外层是普通 TapGestureRecognizer，只在排队。'
                      '抬手时 sweep 把收益判给排队最靠前的内层 → 内层赢。',
            style: const TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 实验二：一个区域里的五个手势
  // ----------------------------------------------------------
  Widget _buildMultiSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验二：同一个区域里的五个手势互相竞争'),
          const SizedBox(height: 8),
          const Text(
            '这个区域同时挂了 Tap、DoubleTap、LongPress、HorizontalDrag、VerticalDrag，'
            '全部在同一个竞技场里。你的每一个动作都在让它们中的某几个出场、某一个获胜。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 14),
          _buildMultiArena(),
          const SizedBox(height: 10),
          Text(
            _multiResult,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _buildMultiToggle(),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.insights_outlined,
            text:
                '重点看「+xxx ms」这一列 —— 它是从入场到被裁决的真实耗时：\n'
                '· 横拖 / 竖拖：超过 18px 就主动认领，几毫秒结束，其他四个当场出局。\n'
                '· 长按：满 500ms 主动认领，同样干净利落。\n'
                '· 单击（挂载 DoubleTap 时）：会拖到 300ms 左右才赢。'
                '因为双击识别器第一次抬手时把竞技场 hold 住了，谁都不能被裁决，'
                '要等它的双击窗口过期。\n'
                '· 关掉下面的 DoubleTap 开关再单击，耗时立刻掉到 0ms 左右 —— '
                '这就是「加了 onDoubleTap 之后单击变迟钝」的真凶。',
          ),
          const SizedBox(height: 14),
          ArenaBoardView(board: _multiBoard, hint: '还没人入场 —— 在这个区域里点一下试试'),
        ],
      ),
    );
  }

  Widget _buildMultiArena() {
    // 注意 map 的遍历顺序就是「入场顺序」，也就是竞技场里的排队位置。
    // Tap 放第一个，所以 sweep 无人认领时它排最前面。
    final Map<Type, GestureRecognizerFactory> gestures =
        <Type, GestureRecognizerFactory>{
          _ProbeTap: GestureRecognizerFactoryWithHandlers<_ProbeTap>(
            () => _ProbeTap(
              arenaName: 'Tap',
              arenaBoard: _multiBoard,
              andThen: () => _flashMulti('onTap 触发（单击）'),
            ),
            (_ProbeTap instance) {},
          ),
          if (_multiWithDoubleTap)
            _ProbeDoubleTap: GestureRecognizerFactoryWithHandlers<_ProbeDoubleTap>(
              () => _ProbeDoubleTap(
                arenaName: 'DoubleTap',
                arenaBoard: _multiBoard,
                andThen: () => _flashMulti('onDoubleTap 触发（双击）'),
              ),
              (_ProbeDoubleTap instance) {},
            ),
          _ProbeLongPress: GestureRecognizerFactoryWithHandlers<_ProbeLongPress>(
            () => _ProbeLongPress(
              arenaName: 'LongPress',
              arenaBoard: _multiBoard,
              andThen: () => _flashMulti('onLongPress 触发（长按满 500ms）'),
            ),
            (_ProbeLongPress instance) {},
          ),
          _ProbeHorizontalDrag:
              GestureRecognizerFactoryWithHandlers<_ProbeHorizontalDrag>(
                () => _ProbeHorizontalDrag(
                  arenaName: 'HorizontalDrag',
                  arenaBoard: _multiBoard,
                )..onStart = (DragStartDetails details) =>
                    _flashMulti('onHorizontalDragStart 触发'),
                (_ProbeHorizontalDrag instance) {},
              ),
          _ProbeVerticalDrag:
              GestureRecognizerFactoryWithHandlers<_ProbeVerticalDrag>(
                () => _ProbeVerticalDrag(
                  arenaName: 'VerticalDrag',
                  arenaBoard: _multiBoard,
                )..onStart = (DragStartDetails details) =>
                    _flashMulti('onVerticalDragStart 触发'),
                (_ProbeVerticalDrag instance) {},
              ),
        };

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: gestures,
      child: Container(
        height: 170,
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF5353A0).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF5353A0).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '点 / 双击 / 长按 / 横拖 / 竖拖',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5353A0),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '这个区域有 5 个识别器在同一个竞技场里',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiToggle() {
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'DoubleTap 是否参与竞争（影响单击的裁决耗时）',
                  style: _toggleLabelStyle,
                ),
              ),
              Switch(
                value: _multiWithDoubleTap,
                onChanged: _setMultiWithDoubleTap,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _multiWithDoubleTap
                ? '已挂载：单击要等双击窗口（约 300ms）过期才会赢，看板上的耗时很明显。'
                : '已移除：没有成员 hold 住竞技场，单击抬手即赢，耗时几乎为 0。',
            style: const TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 冲突速查
  // ----------------------------------------------------------
  Widget _buildConflictSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('常见手势冲突速查'),
          SizedBox(height: 6),
          Text(
            '把上面的规则套到真实场景里，绝大多数冲突都能一眼看出原因。',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          SizedBox(height: 14),
          _ConflictRow(
            scene: '内层 onTap + 外层 onTap',
            symptom: '只有内层的回调触发，外层的完全不响应',
            solution:
                '内层先入场、先认领，外层在 sweep 里出局 —— 这是设计如此。'
                '两层都要响应就改用 Listener（它不参与竞技场），'
                '或者在内层的回调里手动调用外层的逻辑。',
          ),
          _ConflictRow(
            scene: 'onTap + onDoubleTap 写在一起',
            symptom: '单击回调明显变迟钝，约 300ms 后才触发',
            solution:
                '双击识别器第一次抬手时会 hold 住竞技场，谁都不能被裁决。'
                '需要即时反馈就用 onTapDown（按下立刻触发，代价是可能误触发）。',
          ),
          _ConflictRow(
            scene: 'GestureDetector(onPanUpdate) 套在 ListView 里',
            symptom: '列表完全滚不动',
            solution:
                'Pan 是「万向拖拽」，只要有位移就认领，会把列表的纵向拖拽一起吃掉。'
                '按实际方向换成 onVerticalDragUpdate / onHorizontalDragUpdate。',
          ),
          _ConflictRow(
            scene: 'Slider 放进 ListView',
            symptom: '一切正常，滑块能拖、列表也能滚',
            solution:
                'Slider 内部是水平拖动，列表是垂直拖动，两者方向正交、各赢各的，'
                '竞技场里互不干涉 —— 方向不同的手势天生不冲突。',
          ),
          _ConflictRow(
            scene: '内层 Scrollable 套在外层 Scrollable 里（同方向）',
            symptom: '内层滚到头也不带动外层，界面像卡住了',
            solution:
                '同类型的拖拽识别器在内层先认领，外层永远轮不到。'
                '需要联动就用 NotificationListener 手动驱动外层，'
                '或者给内层配 NeverScrollableScrollPhysics 自己接管。',
          ),
          _ConflictRow(
            scene: 'AndroidView / WebView 里的原生手势收不到',
            symptom: '原生控件点不动，手势全被 Flutter 截走',
            solution:
                '给 gestureRecognizers 传 {EagerGestureRecognizer()}，'
                '它入场瞬间就认领整个竞技场 —— 正是实验一里把内层挤掉的那个角色。',
            last: true,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 进阶：框架自己的竞技场日志
  // ----------------------------------------------------------
  Widget _buildDiagnosticsSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle('进阶：看框架自己的竞技场日志'),
              ),
              Switch(value: _diagnostics, onChanged: _setDiagnostics),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Flutter 内置了一个调试开关：',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 8),
          const _CodeHint(
            'debugPrintGestureArenaDiagnostics = true;  // 竞技场全程\n'
            'debugPrintRecognizerCallbacksTrace  = true;  // 谁的回调被调用',
          ),
          const SizedBox(height: 10),
          const Text(
            '打开后，GestureArenaManager 会把「谁入场 / 谁 hold / 谁 accept / '
            '谁 reject / 谁 sweep 获胜」逐行打到控制台。'
            '上面的看板是我按规则重画的视图，这里是框架的原话 —— 两边对着看，'
            '能确认看板没有骗你。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 8),
          Text(
            kDebugMode
                ? '这两个变量只在 debug 构建里有意义（内部用 assert 包裹，release 下代码会被摇掉）。'
                : '当前是 release 构建，开关不会产生任何日志。',
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 12),
          _FrameworkLogPanel(store: _frameworkLog),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 交互辅助
  // ----------------------------------------------------------

  /// 包一层「竞技场成员」：RawGestureDetector + 探针识别器。
  ///
  /// 这里用的是 [RawGestureDetector]，因为它能直接指定识别器实例，
  /// 而 GestureDetector 只能给你回调、看不到竞技场内部。
  ///
  /// `behavior` 必须显式写成 opaque：外框本身是透明的，
  /// 用默认的 deferToChild 它连竞技场都进不去（见 4.2 的结论）。
  Widget _arenaDetector({
    required ArenaBoard board,
    required String arenaName,
    required VoidCallback onTap,
    required Widget child,
    bool eager = false,
  }) {
    final Map<Type, GestureRecognizerFactory> gestures = eager
        ? <Type, GestureRecognizerFactory>{
            _ProbeEager: GestureRecognizerFactoryWithHandlers<_ProbeEager>(
              () => _ProbeEager(arenaName: arenaName, arenaBoard: board),
              (_ProbeEager instance) {},
            ),
          }
        : <Type, GestureRecognizerFactory>{
            _ProbeTap: GestureRecognizerFactoryWithHandlers<_ProbeTap>(
              () => _ProbeTap(
                arenaName: arenaName,
                arenaBoard: board,
                andThen: onTap,
              ),
              (_ProbeTap instance) {},
            ),
          };

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: gestures,
      child: child,
    );
  }

  /// 只有外观的方框：边框和标签用 [IgnorePointer] 包住，不参与命中。
  ///
  /// 否则那圈 [DecoratedBox] 在矩形下恒可命中，会替整块区域「代收」事件
  /// （第 4.1 页那个真实的坑）。
  Widget _box({
    required double size,
    required Color color,
    required String label,
    Widget? child,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (child != null) Center(child: child),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: 0.06),
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
            ),
          ),
        ],
      ),
    );
  }

  void _flashNested(String text) {
    if (!mounted) return;
    setState(() => _nestedResult = text);
  }

  void _flashMulti(String text) {
    if (!mounted) return;
    setState(() => _multiResult = text);
  }

  void _setOuterEager(bool value) {
    if (_outerEager == value) return;
    setState(() {
      _outerEager = value;
      _nestedResult = value
          ? '外层已换成 EagerGestureRecognizer（入场即认领）—— 点 B 看看。'
          : '外层已换回普通 TapGestureRecognizer（排队）—— 点 B 看看。';
    });
    _nestedBoard.clear();
  }

  void _setMultiWithDoubleTap(bool value) {
    if (_multiWithDoubleTap == value) return;
    setState(() {
      _multiWithDoubleTap = value;
      _multiResult = value
          ? 'DoubleTap 已挂载 —— 单击要等 300ms 左右才赢。'
          : 'DoubleTap 已移除 —— 再单击一次，耗时几乎为 0。';
    });
    _multiBoard.clear();
  }

  void _setDiagnostics(bool value) {
    setState(() => _diagnostics = value);
    debugPrintGestureArenaDiagnostics = value;
    debugPrintRecognizerCallbacksTrace = value;
    if (value) {
      _hookPrint();
      _frameworkLog.add('──── 已打开竞技场日志，去上面点几下 ────');
    } else {
      _restorePrint();
      _frameworkLog.add('──── 已关闭竞技场日志 ────');
    }
  }

  /// 把全局 [debugPrint] 接管过来：照常转发给原来的实现，
  /// 同时把竞技场相关的行抄一份到面板里。
  void _hookPrint() {
    if (_printHooked) return;
    _originalDebugPrint = debugPrint;
    debugPrint = _capturePrint;
    _printHooked = true;
  }

  void _restorePrint() {
    if (!_printHooked) return;
    debugPrint = _originalDebugPrint;
    _printHooked = false;
  }

  void _capturePrint(String? message, {int? wrapWidth}) {
    _originalDebugPrint(message, wrapWidth: wrapWidth);
    if (message == null) return;
    // 竞技场日志以 'Gesture arena' 开头；
    // 识别器回调追踪的行带一个 '❙' 前缀。
    if (message.startsWith('Gesture arena') || message.contains('❙')) {
      _frameworkLog.add(message);
    }
  }
}

// ============================================================
// 四、看板与通用小组件
// ============================================================

/// 竞技场看板：成员状态 + 裁决耗时 + 过程日志。
class ArenaBoardView extends StatelessWidget {
  const ArenaBoardView({super.key, required this.board, required this.hint});

  final ArenaBoard board;

  final String hint;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: board,
      builder: (BuildContext context, Widget? _) {
        final ArenaMember? winner = board.winner;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '竞技场看板',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  board.isEmpty
                      ? '等待入场'
                      : '第 ${board.round} 回合 · 指针 #${board.pointer}',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                TextButton.icon(
                  onPressed: board.isEmpty ? null : board.clear,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('清空', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (board.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  hint,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black38),
                ),
              )
            else ...[
              for (final ArenaMember member in board.members)
                _memberRow(member),
              const SizedBox(height: 4),
              if (winner != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '这次手势被「${winner.name}」拿走'
                    '${winner.elapsed != null ? '（裁决用了 ${winner.elapsed!.inMilliseconds}ms）' : ''}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              _logBox(board.log),
            ],
          ],
        );
      },
    );
  }

  Widget _memberRow(ArenaMember member) {
    final (Color color, IconData icon, String label) = switch (member.state) {
      ArenaMemberState.queued => (
        Colors.blueGrey,
        Icons.hourglass_top,
        '排队中',
      ),
      ArenaMemberState.won => (Colors.green, Icons.military_tech, '获胜'),
      ArenaMemberState.lost => (Colors.redAccent, Icons.block, '出局'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // 序号 = 入场顺序 = 命中路径顺序（由内到外）
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              '${member.order}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
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
                  member.name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  member.kind,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          if (member.elapsed != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '+${member.elapsed!.inMilliseconds}ms',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.black45,
                ),
              ),
            ),
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logBox(List<String> lines) {
    return Container(
      height: 140,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (final String line in lines)
            Text(
              line,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.7,
                color: _logColor(line),
              ),
            ),
        ],
      ),
    );
  }

  Color _logColor(String line) {
    if (line.contains('✔')) return const Color(0xFF7CE38B);
    if (line.contains('✗')) return const Color(0xFFFF8A80);
    if (line.contains('────')) return const Color(0x8AFFFFFF);
    return const Color(0xFFD5D5D5);
  }
}

/// 框架内部日志面板。
class _FrameworkLogPanel extends StatelessWidget {
  const _FrameworkLogPanel({required this.store});

  final LogStore store;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'GestureArenaManager 原话',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            ListenableBuilder(
              listenable: store,
              builder: (BuildContext context, Widget? _) => TextButton.icon(
                onPressed: store.lines.isEmpty ? null : store.clear,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ListenableBuilder(
          listenable: store,
          builder: (BuildContext context, Widget? _) {
            final List<String> lines = store.lines;
            return Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF12161C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: lines.isEmpty
                  ? const Center(
                      child: Text(
                        '打开右上角的开关，然后去上面点几下',
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      reverse: true,
                      children: [
                        for (final String line in lines)
                          Text(
                            line,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              height: 1.7,
                              color: Color(0xFF9FE8B0),
                            ),
                          ),
                      ],
                    ),
            );
          },
        ),
      ],
    );
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

/// 冲突速查的一行：场景 / 现象 / 解法
class _ConflictRow extends StatelessWidget {
  const _ConflictRow({
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
