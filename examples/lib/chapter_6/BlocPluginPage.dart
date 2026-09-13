import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ============================================================
// 1. Cubit —— 方法驱动（最简单）
// ============================================================

/// `Cubit<int>`：状态类型就是 int，构造函数里给出初始值 0。
/// 外部通过「调用方法」来驱动状态变化，内部用 emit 推出新状态。
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
  void reset() => emit(0);
}

// ============================================================
// 2. Bloc —— 事件驱动（更规范、可追溯）
// ============================================================

/// 把「所有输入」抽象成事件对象。
abstract class CounterEvent {}

class CounterIncremented extends CounterEvent {}

class CounterDecremented extends CounterEvent {}

class CounterReset extends CounterEvent {}

/// `Bloc<Event, State>`：在构造函数里用 `on<事件类型>` 注册处理器，
/// 把「事件」映射成「新状态」。输入永远是事件对象，而不是直接调方法。
class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<CounterIncremented>((event, emit) => emit(state + 1));
    on<CounterDecremented>((event, emit) => emit(state - 1));
    on<CounterReset>((event, emit) => emit(0));
  }
}

// ============================================================
// 3. 一次性副作用消息（用于演示 BlocConsumer）
// ============================================================

/// 每次 show 都产生一个「全新对象」，且没有重写 ==，
/// 因此每次 emit 都会被判定为新状态，保证 listener 每次都触发。
class UiMessage {
  UiMessage(this.text);

  final String text;
}

class MessageCubit extends Cubit<UiMessage?> {
  MessageCubit() : super(null);

  void show(String text) => emit(UiMessage(text));
}

// ============================================================
// 4. 简易日志总线（供本页统一展示各处的日志）
// ============================================================

/// 让各个区域把日志写进来，底部日志面板统一订阅展示。
class DemoLog extends ChangeNotifier {
  DemoLog._();

  static final DemoLog instance = DemoLog._();

  final List<String> _entries = [];

  List<String> get entries => List.unmodifiable(_entries);

  void add(String message) {
    final now = DateTime.now();
    final time = '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    _entries.insert(0, '[$time]  $message');
    if (_entries.length > 40) _entries.removeLast();
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

// ============================================================
// 页面入口
// ============================================================

/// flutter_bloc 学习 Demo。
///
/// 本页演示 flutter_bloc 的核心 API：
/// - BlocProvider / MultiBlocProvider：依赖注入，把 Bloc/Cubit 放进 widget 树
/// - BlocBuilder：订阅状态并重建 UI
/// - BlocListener：只做副作用（日志、弹窗、跳转），不参与 build
/// - BlocConsumer：Builder + Listener 二合一
/// - context.read / watch / select：读取实例 / 订阅 / 精准订阅
/// - Cubit 与 Bloc 的差异：方法驱动 vs 事件驱动
class BlocPluginPage extends StatelessWidget {
  const BlocPluginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiBlocProvider：一次注入多个 Bloc / Cubit。
    // create 里创建的实例，会随组件销毁自动 close，无需手动管理。
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CounterCubit()),
        BlocProvider(create: (_) => CounterBloc()),
        BlocProvider(create: (_) => MessageCubit()),
      ],
      child: const _BlocDemoView(),
    );
  }
}

class _BlocDemoView extends StatelessWidget {
  const _BlocDemoView();

  @override
  Widget build(BuildContext context) {
    // MultiBlocListener：把「副作用」集中挂在这里，整页的状态变化都能记录。
    // 注意：BlocListener 本身不会触发 child 重建！
    return MultiBlocListener(
      listeners: [
        BlocListener<CounterCubit, int>(
          listener: (context, state) =>
              DemoLog.instance.add('BlocListener：CounterCubit 变为 $state'),
        ),
        BlocListener<CounterBloc, int>(
          listener: (context, state) =>
              DemoLog.instance.add('BlocListener：CounterBloc 变为 $state'),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('flutter_bloc 学习 Demo')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _IntroCard(),
            SizedBox(height: 16),
            _CubitSection(),
            SizedBox(height: 16),
            _BlocSection(),
            SizedBox(height: 16),
            _ConsumerSection(),
            SizedBox(height: 16),
            _LogPanel(),
            SizedBox(height: 16),
            _ApiReference(),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ① Cubit 计数器 + 订阅方式对比
// ============================================================

class _CubitSection extends StatelessWidget {
  const _CubitSection();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('① Cubit：方法驱动'),
          const SizedBox(height: 4),
          const Text(
            '输入 = 直接调用方法；输出 = emit 新状态。'
            '这是 flutter_bloc 里最简单的一层封装。',
            style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          Center(
            // BlocBuilder<B, S>：订阅状态，状态变化时重建 builder
            child: BlocBuilder<CounterCubit, int>(
              builder: (context, count) => Text(
                '$count',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: () => context.read<CounterCubit>().decrement(),
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.read<CounterCubit>().reset(),
                child: const Text('重置'),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => context.read<CounterCubit>().increment(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            'context.read<CounterCubit>().increment();\n'
            '// read：只取实例、不订阅，适合放在按钮回调里触发逻辑',
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            '订阅方式对比（多按几次 +，观察两者的「重建次数」）',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'watch 每次计数变化都会重建；'
            'select 只在「count 跨过 5」这一刻重建，其余变化一概忽略。',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _WatchCard()),
              SizedBox(width: 12),
              Expanded(child: _SelectCard()),
            ],
          ),
        ],
      ),
    );
  }
}

/// 用 context.watch 订阅「整个 state」：只要 state 变化就重建。
class _WatchCard extends StatefulWidget {
  const _WatchCard();

  @override
  State<_WatchCard> createState() => _WatchCardState();
}

class _WatchCardState extends State<_WatchCard> {
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    _builds++; // 记录自身重建次数（仅统计用，非 UI 状态）
    final count = context.watch<CounterCubit>().state;
    return _StatTile(
      title: 'context.watch',
      subtitle: '订阅整个 state',
      value: 'count = $count',
      rebuilds: _builds,
      color: Colors.orange,
    );
  }
}

/// 用 context.select 只订阅「count 是否达到 5」：
/// 只有这个判断结果变化时才重建，其它变化一概忽略。
class _SelectCard extends StatefulWidget {
  const _SelectCard();

  @override
  State<_SelectCard> createState() => _SelectCardState();
}

class _SelectCardState extends State<_SelectCard> {
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    _builds++;
    final reached =
        context.select<CounterCubit, bool>((cubit) => cubit.state >= 5);
    return _StatTile(
      title: 'context.select',
      subtitle: '只订阅 count >= 5',
      value: reached ? '已达标' : '未达标',
      rebuilds: _builds,
      color: Colors.teal,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.rebuilds,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String value;
  final int rebuilds;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '重建 $rebuilds 次',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ② Bloc 事件驱动计数器
// ============================================================

class _BlocSection extends StatelessWidget {
  const _BlocSection();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('② Bloc：事件驱动'),
          const SizedBox(height: 4),
          const Text(
            '同样的计数逻辑，但输入不是「调方法」，而是「发送事件对象」。'
            '事件可以被记录、回放，便于调试与事件溯源。',
            style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          Center(
            child: BlocBuilder<CounterBloc, int>(
              builder: (context, count) => Text(
                '$count',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: Colors.deepPurple),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: () =>
                    context.read<CounterBloc>().add(CounterDecremented()),
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.read<CounterBloc>().add(CounterReset()),
                child: const Text('重置'),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () =>
                    context.read<CounterBloc>().add(CounterIncremented()),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            'context.read<CounterBloc>().add(CounterIncremented());\n'
            '// add：把「事件」投递给 Bloc，由 on<Event> 里的逻辑决定新状态',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ③ BlocConsumer：Builder + Listener
// ============================================================

class _ConsumerSection extends StatelessWidget {
  const _ConsumerSection();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('③ BlocConsumer：Builder + Listener'),
          const SizedBox(height: 4),
          const Text(
            '既按状态构建 UI，又处理「一次性副作用」。'
            '下面点击按钮会向 MessageCubit 发一条新消息：'
            'listener 负责弹 SnackBar，builder 只负责构建按钮本身。',
            style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          Center(
            child: BlocConsumer<MessageCubit, UiMessage?>(
              // listenWhen：只在「出现新消息」时触发，避免初始 null 也弹窗
              listenWhen: (previous, current) => current != null,
              listener: (context, message) {
                if (message == null) return;
                DemoLog.instance
                    .add('BlocConsumer.listener → 弹出 SnackBar：${message.text}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message.text),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              builder: (context, message) => FilledButton.icon(
                onPressed: () =>
                    context.read<MessageCubit>().show('这是一条一次性副作用消息'),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('触发一次副作用'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _CodeHint(
            'BlocConsumer<MessageCubit, UiMessage?>(\n'
            '  listenWhen: (prev, cur) => cur != null,\n'
            '  listener: (context, msg) { /* 副作用：弹窗、跳转、日志 */ },\n'
            '  builder:  (context, msg) { /* 构建 UI */ },\n'
            ')',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ④ 日志面板
// ============================================================

class _LogPanel extends StatelessWidget {
  const _LogPanel();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle('④ 日志面板'),
              TextButton.icon(
                onPressed: DemoLog.instance.clear,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 160,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListenableBuilder(
              listenable: DemoLog.instance,
              builder: (context, _) {
                final entries = DemoLog.instance.entries;
                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'BlocListener / BlocConsumer 的日志会出现在这里…',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) => Text(
                    entries[index],
                    style: const TextStyle(
                      color: Color(0xFF7CE38B),
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                      height: 1.6,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ⑤ API 速查 + Cubit / Bloc 对比
// ============================================================

class _ApiReference extends StatelessWidget {
  const _ApiReference();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('⑤ API 速查'),
          SizedBox(height: 8),
          _ApiRow('BlocProvider', '把 Bloc/Cubit 注入 widget 树（依赖注入），销毁时自动 close'),
          _ApiRow('MultiBlocProvider', '一次注入多个 Bloc / Cubit'),
          _ApiRow('BlocBuilder<B, S>', '订阅状态，状态变化时重建 UI'),
          _ApiRow('BlocListener<B, S>', '只做副作用（弹窗、跳转、日志），不重建 UI'),
          _ApiRow('BlocConsumer<B, S>', 'Builder + Listener 二合一'),
          _ApiRow('BlocSelector<B, S, R>', 'select 的 widget 写法，只订阅状态中的某个字段'),
          _ApiRow('context.read<T>()', '取实例但不订阅，适合在回调里触发方法/事件'),
          _ApiRow('context.watch<T>()', '订阅，状态一变就重建'),
          _ApiRow('context.select<T, R>()', '只订阅状态的某个字段，做到精准重建'),
          SizedBox(height: 16),
          Divider(),
          SizedBox(height: 12),
          _SectionTitle('Cubit vs Bloc'),
          SizedBox(height: 8),
          _ApiRow('输入方式', 'Cubit：调用方法　|　Bloc：发送事件对象'),
          _ApiRow('可追溯性', 'Cubit：较弱　|　Bloc：较强（事件可记录、可回放）'),
          _ApiRow('代码量', 'Cubit：少　|　Bloc：多（需先定义事件类）'),
          _ApiRow('适用场景', 'Cubit：简单逻辑　|　Bloc：复杂业务、需要事件溯源'),
          SizedBox(height: 12),
          Text(
            '小结：先用 Cubit 起步，逻辑变复杂、需要事件追溯时再升级为 Bloc。',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
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
          SizedBox(
            width: 130,
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 通用小组件
// ============================================================

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      color: Colors.deepPurple.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('flutter_bloc 是什么？'),
          SizedBox(height: 8),
          Text(
            'flutter_bloc 是 BLoC 模式的工业级封装：它把「事件/方法 → 状态流 → UI」'
            '这套流程，连同依赖注入、精准重建、生命周期管理一起打包，'
            '让你不必再手写 StreamController。',
            style: TextStyle(height: 1.6),
          ),
          SizedBox(height: 8),
          Text(
            '本章 6.2 的 BlocPage.dart 是手写 Stream 的「原理版」，'
            '本页则是它的「库版」对照：同样的思想，代码量大幅减少。',
            style: TextStyle(height: 1.6, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
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

class _CodeHint extends StatelessWidget {
  const _CodeHint(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
          color: Color(0xFF3D5A80),
        ),
      ),
    );
  }
}
