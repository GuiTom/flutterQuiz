import 'package:flutter/material.dart';

/// ============================================================
/// 第七章：InheritedWidget 扩展出的组件
/// ============================================================
///
/// `InheritedWidget` 本体只有几十行代码，却是 Flutter 里
/// 「跨层级传值 + 精准重建」的地基。Theme、MediaQuery、DefaultTextStyle、
/// Provider、Riverpod…… 全都站在它上面。
///
/// 本页内容：
/// 一、机制：依赖登记（dependents）+ updateShouldNotify 的「两段式通知」
/// 二、实验一：手写 InheritedWidget，看「谁重建、谁不动」
/// 三、实验二：InheritedNotifier —— 数据自己变化就能触发重建，祖先不用重建
/// 四、实验三：InheritedModel —— 按 aspect 精准重建，避免全量刷新
/// 五、家族图谱：框架里从 InheritedWidget 扩展出来的那些组件
/// 六、常见坑 + 选型对照
class InheritedWidgets extends StatelessWidget {
  const InheritedWidgets({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inherited 扩展出的组件'),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _MechanismCard(),
          SizedBox(height: 16),
          _DependencyCard(),
          SizedBox(height: 16),
          _NotifierCard(),
          SizedBox(height: 16),
          _ModelCard(),
          SizedBox(height: 16),
          _FamilyTreeCard(),
          SizedBox(height: 16),
          _TrapCard(),
          SizedBox(height: 16),
          _ChooseCard(),
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

// ============================================================
// 一、机制
// ============================================================

class _MechanismCard extends StatelessWidget {
  const _MechanismCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('它到底做了什么：依赖登记 + 两段式通知'),
          SizedBox(height: 8),
          Text(
            'InheritedWidget 本身不参与布局和绘制（它直接透传 child），'
            '它唯一的价值是当「广播塔」：把数据挂在树上，'
            '并且**只**通知那些主动登记过依赖的子孙去重建。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 14),
          _PipelineStep(
            ordinal: '1',
            title: '读取即登记',
            desc: 'Xxx.of(context) 内部就是 '
                'context.dependOnInheritedWidgetOfExactType<T>()：'
                '向上找到最近的 T 类型 InheritedElement，'
                '把「当前 Element」记进它的 _dependents 表。'
                '注意是「登记」而不是「拷贝值」。',
            color: Color(0xFF3D5A80),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '2',
            title: '值发生变化',
            desc: '持有数据的祖先 setState（或 notifier 发出通知），'
                '于是生成一个**新的** InheritedWidget 实例。'
                '记住：只有新实例才会触发下面的比较。',
            color: Color(0xFF5C6BC0),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '3',
            title: '第一段：updateShouldNotify(oldWidget)',
            desc: 'Element.update 里调用它。返回 false 就地打住 —— '
                '哪怕值变了，只要你说「不值得通知」，依赖者就一次都不重建。'
                '返回 true 才进入第二段。',
            color: Color(0xFF9A6700),
          ),
          SizedBox(height: 12),
          _PipelineStep(
            ordinal: '4',
            title: '第二段：notifyClients 精准投递',
            desc: '遍历 _dependents，逐个 didChangeDependencies() → '
                'markNeedsBuild()，下一帧只重建这些 Element。'
                '所以依赖者会重建，而它的**祖先和其他兄弟完全不动**。',
            color: Color(0xFF2E7D32),
          ),
          SizedBox(height: 14),
          _TipRow(
            icon: Icons.lightbulb_outline,
            text: '这套「登记 → 比较 → 点对点投递」的机制，就是 Flutter 里唯一'
                '原生的跨层级状态共享方案。Provider 只是给它套了层 '
                'InheritedProvider，Riverpod 也只是在它之上做了依赖图 —— '
                '底层始终是这个 Element 级的 _dependents 表。',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 二、实验一：手写 InheritedWidget
// ============================================================

/// 最简 InheritedWidget：只带一个 count 和一个自增回调。
///
/// `updateShouldNotify` 只在 count 真的变了才返回 true ——
/// 这就是「精准通知」的开关。它比较的是**值**，不是对象引用。
class _CounterScope extends InheritedWidget {
  const _CounterScope({
    required this.count,
    required this.increment,
    required super.child,
  });

  final int count;

  final VoidCallback increment;

  /// 约定俗成的静态 `of`：把 dependOnInheritedWidgetOfExactType 藏起来，
  /// 顺带在找不到时给出清晰报错。
  static _CounterScope of(BuildContext context) {
    final _CounterScope? scope =
        context.dependOnInheritedWidgetOfExactType<_CounterScope>();
    assert(scope != null, '_CounterScope.of() 只能在 _CounterScope 的子树里调用');
    return scope!;
  }

  @override
  bool updateShouldNotify(_CounterScope oldWidget) => count != oldWidget.count;
}

class _DependencyCard extends StatelessWidget {
  const _DependencyCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验一：谁会重建，谁不会'),
          const SizedBox(height: 8),
          const Text(
            '三块面板都挂在同一个 InheritedWidget 下面。'
            'A 用 of(context) 读了它，B 用 getInheritedWidgetOfExactType 读了它，'
            'C 压根没读。点「+1」看它们的 build 次数。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            r'''// A：会登记依赖 —— 值变了就重建
final scope = context.dependOnInheritedWidgetOfExactType<_CounterScope>();

// B：只读取、不登记 —— 值变了它一无所知（Flutter 3.7+）
final scope = context.getInheritedWidgetOfExactType<_CounterScope>();''',
          ),
          const SizedBox(height: 14),
          const _DependencyDemo(),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.insights_outlined,
            text: 'B 是最容易踩的坑：getInheritedWidgetOfExactType 能读到值，'
                '但不会把当前 Element 登记进 _dependents，'
                '所以数据更新后它永远显示旧值 —— 看起来像「状态没同步」，'
                '实际是你压根没订阅。',
          ),
        ],
      ),
    );
  }
}

class _DependencyDemo extends StatefulWidget {
  const _DependencyDemo();

  @override
  State<_DependencyDemo> createState() => _DependencyDemoState();
}

class _DependencyDemoState extends State<_DependencyDemo> {
  int _count = 0;
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    _builds++;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CounterScope(
          count: _count,
          increment: () => setState(() => _count++),
          // 关键：child 是 const，所以外层 setState 时它不会被重建，
          // 下面三块面板的变化只可能来自 InheritedWidget 的通知。
          child: const _DependencyPanels(),
        ),
        const SizedBox(height: 10),
        Text(
          '外层持有者：_count = $_count，build 次数 = $_builds',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => setState(() => _count++),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('外层 setState：count++'),
        ),
      ],
    );
  }
}

/// `const` 面板容器：只会 build 一次，所以子面板的重建必然来自依赖通知。
class _DependencyPanels extends StatelessWidget {
  const _DependencyPanels();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _DependentPanel(),
        SizedBox(height: 8),
        _ShadowPanel(),
        SizedBox(height: 8),
        _SilentPanel(),
      ],
    );
  }
}

/// A：登记依赖 → 每次值变化都重建
class _DependentPanel extends StatefulWidget {
  const _DependentPanel();

  @override
  State<_DependentPanel> createState() => _DependentPanelState();
}

class _DependentPanelState extends State<_DependentPanel> {
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    _builds++;
    final _CounterScope scope = _CounterScope.of(context);
    return _MiniPanel(
      tag: 'A',
      accent: _kGood,
      title: 'dependOnInheritedWidgetOfExactType —— 登记了依赖',
      lines: <String>['读到的 count = ${scope.count}', 'build 次数 = $_builds'],
      action: TextButton(
        onPressed: scope.increment,
        child: const Text('在 A 里 +1'),
      ),
    );
  }
}

/// B：只读不登记 → 永远停在第一次 build 的值
class _ShadowPanel extends StatefulWidget {
  const _ShadowPanel();

  @override
  State<_ShadowPanel> createState() => _ShadowPanelState();
}

class _ShadowPanelState extends State<_ShadowPanel> {
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    _builds++;
    final _CounterScope? scope =
        context.getInheritedWidgetOfExactType<_CounterScope>();
    return _MiniPanel(
      tag: 'B',
      accent: _kWarn,
      title: 'getInheritedWidgetOfExactType —— 只读，不登记',
      lines: <String>[
        '读到的 count = ${scope?.count}（永远是初始值）',
        'build 次数 = $_builds',
      ],
    );
  }
}

/// C：完全没读过它 → 同样不会被通知
class _SilentPanel extends StatefulWidget {
  const _SilentPanel();

  @override
  State<_SilentPanel> createState() => _SilentPanelState();
}

class _SilentPanelState extends State<_SilentPanel> {
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    _builds++;
    return _MiniPanel(
      tag: 'C',
      accent: _kNeutral,
      title: '没读过它 —— 没登记，也没关系',
      lines: <String>['build 次数 = $_builds', '它只关心自己'],
    );
  }
}

// ============================================================
// 三、实验二：InheritedNotifier
// ============================================================

/// 被监听的模型：一变就 notifyListeners()。
class _CountModel extends ChangeNotifier {
  int _count = 0;
  int _notifications = 0;

  int get count => _count;

  int get notifications => _notifications;

  void increment() {
    _count++;
    _notifications++;
    notifyListeners();
  }
}

/// InheritedNotifier：不用祖先 setState，数据自己变化就能通知依赖者。
///
/// 它内部会 addListener(_handleUpdate)，收到通知就 markNeedsBuild 自己，
/// 再在自己的 build 里 notifyClients 投递给所有依赖者。
class _CountScope extends InheritedNotifier<_CountModel> {
  const _CountScope({required super.notifier, required super.child});

  static _CountModel of(BuildContext context) {
    final _CountScope? scope =
        context.dependOnInheritedWidgetOfExactType<_CountScope>();
    assert(scope != null, '_CountScope.of() 只能在 _CountScope 的子树里调用');
    final _CountModel? model = scope!.notifier;
    assert(model != null, '_CountScope 必须绑定一个 notifier');
    return model!;
  }
}

class _NotifierCard extends StatelessWidget {
  const _NotifierCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验二：数据自己变化，祖先不用重建'),
          const SizedBox(height: 8),
          const Text(
            'InheritedWidget 有个硬伤：值变了要靠祖先 setState 才能生成新实例，'
            '于是祖先自己也得重建。InheritedNotifier 把 ChangeNotifier 接进来，'
            '数据一喊，它自己去通知依赖者 —— 祖先一次都不用动。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            r'''class CountScope extends InheritedNotifier<CountModel> {
  const CountScope({required super.notifier, required super.child});

  static CountModel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CountScope>()!.notifier!;
}

// 数据一变，依赖者就重建 —— 不需要任何人 setState
model.increment();   // → notifyListeners()''',
          ),
          const SizedBox(height: 14),
          const _NotifierDemo(),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.insights_outlined,
            text: '注意上面那个「外层 build 次数」永远是 1：祖先根本没参与。'
                '这就是 InheritedNotifier 比手写 InheritedWidget 更实用的地方 —— '
                '把「数据源」和「传播通道」彻底解耦了。\n'
                '另外别忘了：InheritedNotifier 只负责 addListener / removeListener，'
                '**不会** dispose 你的 notifier，该你 dispose 的还得自己 dispose。',
          ),
        ],
      ),
    );
  }
}

class _NotifierDemo extends StatefulWidget {
  const _NotifierDemo();

  @override
  State<_NotifierDemo> createState() => _NotifierDemoState();
}

class _NotifierDemoState extends State<_NotifierDemo> {
  final _CountModel _model = _CountModel();
  int _builds = 0;

  @override
  void dispose() {
    // InheritedNotifier 只管 removeListener，dispose 得自己来
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _builds++;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CountScope(
          notifier: _model,
          // const：外层重建也不会连带重建它，变化只能来自 notifier 通知
          child: const _NotifierReaders(),
        ),
        const SizedBox(height: 10),
        // Text(
        //   '外层 build 次数 = $_builds　|　notifyListeners 次数 = ${_model.notifications}',
        //   style: const TextStyle(fontSize: 12, color: Colors.black54),
        // ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _model.increment,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('model.increment()（不调用 setState）'),
        ),
      ],
    );
  }
}

class _NotifierReaders extends StatelessWidget {
  const _NotifierReaders();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _NotifierReader(),
        SizedBox(height: 8),
        _NotifierShadow(),
      ],
    );
  }
}

/// 依赖者：notifier 一通知就重建
class _NotifierReader extends StatefulWidget {
  const _NotifierReader();

  @override
  State<_NotifierReader> createState() => _NotifierReaderState();
}

class _NotifierReaderState extends State<_NotifierReader> {
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    _builds++;
    final _CountModel model = _CountScope.of(context);
    return _MiniPanel(
      tag: 'D',
      accent: _kGood,
      title: '依赖 notifier —— 跟着数据一起走',
      lines: <String>['读到的 count = ${model.count}', 'build 次数 = $_builds'],
    );
  }
}

/// 不依赖者：隔离对照
class _NotifierShadow extends StatefulWidget {
  const _NotifierShadow();

  @override
  State<_NotifierShadow> createState() => _NotifierShadowState();
}

class _NotifierShadowState extends State<_NotifierShadow> {
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    _builds++;
    final _CountScope? scope =
        context.getInheritedWidgetOfExactType<_CountScope>();
    return _MiniPanel(
      tag: 'E',
      accent: _kWarn,
      title: '只读不登记 —— 数据在动，它不动',
      lines: <String>[
        '读到的 count = ${scope?.notifier?.count}（初始值）',
        'build 次数 = $_builds',
      ],
    );
  }
}

// ============================================================
// 四、实验三：InheritedModel
// ============================================================

/// aspect 用 enum，避免手写字符串拼错。
enum _UserAspect { name, theme }

/// InheritedModel：一个模型里有多个字段，依赖者可以只订阅其中一个。
///
/// - `updateShouldNotify` 只要**任意字段**变了就返回 true（这一层是粗筛）
/// - `updateShouldNotifyDependent` 再按每个依赖者登记的 aspect 精筛
class _UserModel extends InheritedModel<_UserAspect> {
  const _UserModel({
    required this.name,
    required this.accent,
    required super.child,
  });

  final String name;

  final Color accent;

  /// aspect 为 null 时退化成普通 InheritedWidget（任意变化都重建）。
  static _UserModel of(BuildContext context, {_UserAspect? aspect}) {
    final _UserModel? model = aspect == null
        ? context.dependOnInheritedWidgetOfExactType<_UserModel>()
        : InheritedModel.inheritFrom<_UserModel>(context, aspect: aspect);
    assert(model != null, '_UserModel.of() 只能在 _UserModel 的子树里调用');
    return model!;
  }

  @override
  bool updateShouldNotify(_UserModel oldWidget) =>
      name != oldWidget.name || accent != oldWidget.accent;

  @override
  bool updateShouldNotifyDependent(
    _UserModel oldWidget,
    Set<_UserAspect> dependencies,
  ) {
    if (dependencies.contains(_UserAspect.name) && name != oldWidget.name) {
      return true;
    }
    if (dependencies.contains(_UserAspect.theme) &&
        accent != oldWidget.accent) {
      return true;
    }
    return false;
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('实验三：按 aspect 精准重建'),
          const SizedBox(height: 8),
          const Text(
            '一个模型里塞了 name 和 accent 两个字段。'
            '只关心 name 的组件，在 accent 变化时应该一次都不重建 —— '
            '这就是 InheritedModel 存在的理由。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            r'''class UserModel extends InheritedModel<UserAspect> {
  @override
  bool updateShouldNotifyDependent(
    UserModel old, Set<UserAspect> aspects) {
    if (aspects.contains(UserAspect.name) && name != old.name) return true;
    if (aspects.contains(UserAspect.theme) && accent != old.accent) return true;
    return false;      // 粗筛通过，但这个依赖者不关心 → 不打扰它
  }
}

// 只订阅 name 这个 aspect
final model = InheritedModel.inheritFrom<UserModel>(
  context, aspect: UserAspect.name);''',
          ),
          const SizedBox(height: 14),
          const _AspectDemo(),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.insights_outlined,
            text: '注意是**两段筛选**：updateShouldNotify 先做粗筛（任意字段变就 true），'
                '再由 updateShouldNotifyDependent 逐个依赖者精筛。'
                '框架里的 MediaQuery 就是这么做的 —— '
                '它 extends InheritedModel<_MediaQueryAspect>，'
                '只关心 textScaler 的组件不会因为键盘弹出（viewInsets 变化）而重建。',
          ),
        ],
      ),
    );
  }
}

class _AspectDemo extends StatefulWidget {
  const _AspectDemo();

  @override
  State<_AspectDemo> createState() => _AspectDemoState();
}

class _AspectDemoState extends State<_AspectDemo> {
  static const List<Color> _accents = <Color>[
    Color(0xFF3D5A80),
    Color(0xFF2E7D32),
    Color(0xFFB23A48),
  ];

  String _name = 'Tom';
  int _accentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UserModel(
          name: _name,
          accent: _accents[_accentIndex],
          // const：保证下面的重建只可能来自 aspect 通知
          child: const _AspectConsumers(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () =>
                  setState(() => _name = _name == 'Tom' ? 'Jerry' : 'Tom'),
              icon: const Icon(Icons.badge_outlined, size: 16),
              label: const Text('只改 name'),
            ),
            FilledButton.icon(
              onPressed: () => setState(
                () => _accentIndex = (_accentIndex + 1) % _accents.length,
              ),
              icon: const Icon(Icons.palette_outlined, size: 16),
              label: const Text('只改 accent'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AspectConsumers extends StatelessWidget {
  const _AspectConsumers();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _NameConsumer(),
        SizedBox(height: 8),
        _ThemeConsumer(),
      ],
    );
  }
}

/// 只订阅 name
class _NameConsumer extends StatefulWidget {
  const _NameConsumer();

  @override
  State<_NameConsumer> createState() => _NameConsumerState();
}

class _NameConsumerState extends State<_NameConsumer> {
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    _builds++;
    final _UserModel model =
        _UserModel.of(context, aspect: _UserAspect.name);
    return _MiniPanel(
      tag: 'F',
      accent: _kGood,
      title: "只订阅 aspect: name",
      lines: <String>['name = ${model.name}', 'build 次数 = $_builds'],
    );
  }
}

/// 只订阅 accent
class _ThemeConsumer extends StatefulWidget {
  const _ThemeConsumer();

  @override
  State<_ThemeConsumer> createState() => _ThemeConsumerState();
}

class _ThemeConsumerState extends State<_ThemeConsumer> {
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    _builds++;
    final _UserModel model =
        _UserModel.of(context, aspect: _UserAspect.theme);
    final String hex = model.accent
        .toARGB32()
        .toRadixString(16)
        .substring(2)
        .toUpperCase();
    return _MiniPanel(
      tag: 'G',
      accent: _kGood,
      title: '只订阅 aspect: theme',
      lines: <String>['accent = #$hex', 'build 次数 = $_builds'],
      accentColor: model.accent,
    );
  }
}

// ============================================================
// 五、家族图谱
// ============================================================

class _FamilyTreeCard extends StatelessWidget {
  const _FamilyTreeCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('框架里从 InheritedWidget 扩展出来的组件'),
          SizedBox(height: 8),
          Text(
            '你平时调用的 of(context)、watch(context)，绝大多数都在这一支上。'
            '下面这些都是从 InheritedWidget 直接或间接继承来的（以 Flutter 3.35 为准）。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 14),
          _TreeRow(
            name: 'InheritedWidget',
            note: '地基：Element 级依赖登记 + updateShouldNotify',
            highlight: true,
          ),
          _TreeRow(
            name: 'InheritedModel<T>',
            note: '加「aspect」概念，能让一个 Widget 只订阅模型的一部分。'
                '框架实例：MediaQuery（size / padding / viewInsets 各自独立）',
            depth: 1,
          ),
          _TreeRow(
            name: 'InheritedNotifier<T extends Listenable>',
            note: '自动 addListener，数据自己变化就能通知依赖者。'
                '框架实例：AutocompleteHighlightedOption、FocusScope 内部的 _FocusInheritedScope',
            depth: 1,
          ),
          _TreeRow(
            name: 'InheritedTheme（abstract）',
            note: '再加 wrap / captureAll，让主题能「整体搬运」到别的 Navigator 栈。'
                '框架实例：Theme、IconTheme、DefaultTextStyle、CupertinoTheme，'
                '以及几十个 XxxTheme（AppBarTheme、TextButtonTheme…）',
            depth: 2,
          ),
          _TreeRow(
            name: '直接子类举例',
            note: 'DefaultAssetBundle、HeroControllerScope；'
                'Localizations / ScaffoldMessenger 内部也各挂了一个私有 InheritedWidget',
            depth: 1,
          ),
          _TreeRow(
            name: '第三方',
            note: 'Provider 的 InheritedProvider、Riverpod 的 UncontrolledProviderScope、'
                '各种 DI 框架的 Scope —— 全部都是它的套壳',
            depth: 1,
          ),
          SizedBox(height: 14),
          _TipRow(
            icon: Icons.tips_and_updates_outlined,
            text: '所以「学 InheritedWidget 有什么用」的答案是：'
                '你每天都在用它。Theme.of(context) / MediaQuery.sizeOf(context) '
                '的原理就是这一页讲的东西，看一眼 API 文档就知道该不该期待重建。',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 六、坑
// ============================================================

class _TrapCard extends StatelessWidget {
  const _TrapCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('InheritedWidget 相关的坑速查'),
          SizedBox(height: 6),
          Text(
            '几乎都和「什么时候能读」「什么时候该通知」有关。',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          SizedBox(height: 14),
          _TrapRow(
            scene: '在 initState 里调用 Xxx.of(context)',
            symptom: "dependOnInheritedWidgetOfExactType was called before initState() completed",
            solution: 'initState 阶段还不允许建立依赖。要读就挪到 didChangeDependencies() 或 build()；'
                '只是「拿一下对象」不进依赖表，可以在 didChangeDependencies 里缓存。',
          ),
          _TrapRow(
            scene: '把 of() 放在按钮回调、addPostFrameCallback 等异步时机里调用',
            symptom: '拿到的可能是旧值，或者被断言拦下；依赖关系也不会建立',
            solution: '依赖查询是「build 期」的行为。回调里要用就用 '
                'getInheritedWidgetOfExactType（明确不订阅），'
                '或者提前在 build 里把对象取出来存下来。',
          ),
          _TrapRow(
            scene: 'updateShouldNotify 里比较「每次 build 新建的对象」',
            symptom: '永远返回 true → 依赖者每帧重建，性能塌方',
            solution: '比较**值语义**（字段、== / hashCode），或者干脆让数据是不可变值类型。'
                '把 List / Map / 自定义类直接比引用是新手的经典错误。',
          ),
          _TrapRow(
            scene: 'InheritedWidget 里塞了可变对象，改了内部字段',
            symptom: '依赖者不更新 —— 因为 widget 引用没变，updateShouldNotify 返回 false',
            solution: '要么每次生成新的不可变实例，要么改用 InheritedNotifier / InheritedModel，'
                '让「变化」通过 Listenable 或 aspect 显式暴露出来。',
          ),
          _TrapRow(
            scene: '用 getInheritedWidgetOfExactType 当作 of() 使用',
            symptom: '能读到值，但值变化后组件永远不刷新（显示旧数据）',
            solution: '它只读不登记依赖。需要跟着变化重建就必须用 '
                'dependOnInheritedWidgetOfExactType（或它的封装 of()）。',
          ),
          _TrapRow(
            scene: 'of() 找不到祖先时只做了 assert，release 包里直接崩',
            symptom: 'Null check operator used on a null value',
            solution: 'assert 只在 debug 生效。要么提供 maybeOf() 返回可空值让调用方自己兜底，'
                '要么在 of() 里抛带清晰信息的 FlutterError。',
          ),
          _TrapRow(
            scene: 'InheritedModel 的 aspect 用字符串字面量，前后拼写不一致',
            symptom: '该重建的不重建，或该过滤的没过滤（静默失效，极难查）',
            solution: 'aspect 用 enum 或 const 变量，并在 updateShouldNotifyDependent 里'
                '显式覆盖所有分支。别让字符串分散在两个文件里。',
          ),
          _TrapRow(
            scene: '以为 InheritedNotifier 会帮你 dispose 那个 notifier',
            symptom: '页面退出后 ChangeNotifier 仍被别处持有，或 dispose 时报 using a disposed object',
            solution: '它只做 addListener / removeListener。notifier 的生命周期归创建它的人管，'
                '在 dispose() 里手动释放。',
            last: true,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 七、选型
// ============================================================

class _ChooseCard extends StatelessWidget {
  const _ChooseCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('四种「扩展形态」对照'),
          SizedBox(height: 10),
          _CompareTable(
            headers: <String>[
              '',
              'InheritedWidget',
              'InheritedNotifier',
              'InheritedModel',
              'Provider / Riverpod',
            ],
            rows: <List<String>>[
              <String>['承载什么', '任意不可变值', '一个 Listenable', '一组字段 + aspect', '状态对象 + 依赖图'],
              <String>['谁触发通知', '祖先 setState', '数据自己 notify', '数据自己 notify', '数据自己 notify'],
              <String>['通知粒度', '按 updateShouldNotify', '整个 notifier', '按 aspect 精筛', '按 select / 依赖项'],
              <String>['祖先要不要重建', '要', '不需要', '需要', '不需要'],
              <String>['额外依赖', '无', '无', '无', '需要 pub 包'],
              <String>['典型场景', '主题、环境等只读数据', '单个全局可变对象', '一个对象多个独立字段', '业务状态管理'],
              <String>['上手成本', '最低', '低', '中（要理解 aspect）', '中高'],
            ],
          ),
          SizedBox(height: 14),
          _SectionTitle('选型顺序'),
          SizedBox(height: 8),
          _BulletLine('第一步：数据只读、几乎不变（主题、屏幕尺寸、本地化）→ 直接用框架现成的 Theme / MediaQuery'),
          _BulletLine('第二步：数据可变、想跨层级通知 → 优先 InheritedNotifier（可控、零依赖）'),
          _BulletLine('第三步：一个模型里字段很多、只想订阅其中一部分 → InheritedModel'),
          _BulletLine('第四步：状态多了、要组合 / 要测试 / 要自动 dispose → 上 Provider 或 Riverpod，'
              '但要清楚它跑的还是这一页讲的机制'),
          _BulletLine('任何时候都别忘了：通知是**点对点**的，不会帮你重建祖先 —— '
              '也别指望它自动帮你管理生命周期'),
        ],
      ),
    );
  }
}

// ============================================================
// 通用小组件
// ============================================================

/// 小面板：标签 + 标题 + 若干行等宽信息 + 可选操作按钮。
class _MiniPanel extends StatelessWidget {
  const _MiniPanel({
    required this.tag,
    required this.accent,
    required this.title,
    required this.lines,
    this.action,
    this.accentColor,
  });

  final String tag;

  final Color accent;

  final String title;

  final List<String> lines;

  final Widget? action;

  /// 用于「颜色」类面板：把当前值直接铺在左侧色条上。
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: accent,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                for (final String line in lines)
                  Text(
                    line,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                if (action != null) ...[
                  const SizedBox(height: 2),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ],
              ],
            ),
          ),
          if (accentColor != null)
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

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

/// 家族图谱的一行：缩进 + 类名 + 说明
class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.name,
    required this.note,
    this.depth = 0,
    this.highlight = false,
  });

  final String name;

  final String note;

  final int depth;

  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: depth * 16.0, top: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFEAF0F8) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? _kNeutral.withValues(alpha: 0.5)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (depth > 0)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text(
                    '└',
                    style: TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                ),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: _kNeutral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(
              fontSize: 12,
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

/// 简易对照表（列宽按列数自适应）
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
            i: FixedColumnWidth(i == 0 ? 82 : 108),
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
