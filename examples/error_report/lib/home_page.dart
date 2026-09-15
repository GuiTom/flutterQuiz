import 'dart:async';

import 'package:flutter/material.dart';

import 'crash_reporter.dart';
import 'scenarios.dart';

/// 主界面：左边"实验台"负责制造异常，右边"日志"看上报结果。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[_LabView(), _LogView()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            label: '实验台',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            label: '日志',
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// 实验台
/// ============================================================

class _LabView extends StatefulWidget {
  const _LabView();

  @override
  State<_LabView> createState() => _LabViewState();
}

class _LabViewState extends State<_LabView> {
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    CrashReporter.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    CrashReporter.instance.removeListener(_onChanged);
    super.dispose();
  }

  /// 崩溃可能发生在 build 期间，此时不能直接 setState。
  /// 排到下一帧再刷新，避免 "setState() called during build"。
  void _onChanged() {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// 故意不 await：让错误真的逃逸到 PlatformDispatcher.onError。
  ///
  /// 这里必须保留"同步 throw 就同步抛出去"的语义 ——
  /// 如果把 ② 这种场景包成 async，throw 会被收进 Future，
  /// 通道就变了，演示结果也对不上了。
  void _run(Scenario scenario) {
    final FutureOr<void> result = scenario.run(context);
    if (result is Future<void>) {
      unawaited(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CrashReporter reporter = CrashReporter.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('错误上报 · 实验台')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildStats(reporter),
          const SizedBox(height: 16),
          _buildChannelCard(reporter),
          const SizedBox(height: 16),
          for (int i = 0; i < scenarios.length; i++) _buildScenario(i),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStats(CrashReporter reporter) {
    final int queued = reporter.readQueue().length;
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatChip(
            label: '队列待发',
            value: '$queued',
            color: const Color(0xFF3D5A80),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: '已上报',
            value: '${reporter.sent.length}',
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: '已丢失',
            value: '${reporter.lost.length}',
            color: const Color(0xFFC62828),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelCard(CrashReporter reporter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '通道开关',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              '关掉任意一条，再去点下面的场景 —— 丢掉的那些错误会跑到'
              '「日志 → 已丢失」里。那就是你线上后台永远看不到的崩溃。',
              style: TextStyle(fontSize: 12.5, height: 1.6),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('FlutterError.onError（框架同步异常）'),
              subtitle: const Text('build / 手势 / 帧回调里抛的错'),
              value: reporter.frameworkOn,
              onChanged: (bool value) => _toggle(
                framework: value,
                platform: reporter.platformOn,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('PlatformDispatcher.onError（异步错误）'),
              subtitle: const Text('未 await 的 Future / Timer 回调'),
              value: reporter.platformOn,
              onChanged: (bool value) => _toggle(
                framework: reporter.frameworkOn,
                platform: value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle({required bool framework, required bool platform}) {
    CrashReporter.instance.setChannels(
      framework: framework,
      platform: platform,
      friendlyErrorWidget: true,
    );
    setState(() {});
  }

  Widget _buildScenario(int index) {
    final Scenario scenario = scenarios[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      scenario.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      scenario.expected,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                scenario.desc,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: ValueKey<String>('trigger-$index'),
                  onPressed: () => _run(scenario),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('触发'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

/// ============================================================
/// 日志
/// ============================================================

class _LogView extends StatefulWidget {
  const _LogView();

  @override
  State<_LogView> createState() => _LogViewState();
}

class _LogViewState extends State<_LogView> {
  bool _refreshScheduled = false;
  bool _flushing = false;
  String? _flushResult;

  @override
  void initState() {
    super.initState();
    CrashReporter.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    CrashReporter.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _flush() async {
    setState(() {
      _flushing = true;
      _flushResult = null;
    });
    final FlushResult result = await CrashReporter.instance.flush();
    if (!mounted) {
      return;
    }
    setState(() {
      _flushing = false;
      _flushResult = result.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final CrashReporter reporter = CrashReporter.instance;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('错误上报 · 日志'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: '队列'),
              Tab(text: '已上报'),
              Tab(text: '已丢失'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            _buildToolbar(reporter),
            if (_flushResult != null) _buildFlushResult(),
            const Expanded(
              child: TabBarView(
                children: <Widget>[_QueueTab(), _SentTab(), _LostTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(CrashReporter reporter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('模拟"网络不可用"'),
            subtitle: const Text('打开后补发会失败，日志留在队列里并 retry+1'),
            value: reporter.simulateNetworkFailure,
            onChanged: (bool value) {
              setState(() => reporter.simulateNetworkFailure = value);
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _flushing ? null : _flush,
                  icon: _flushing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: const Text('模拟下次启动 · 补发'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    CrashReporter.instance.clearQueue();
                    setState(() => _flushResult = null);
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('清空'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlushResult() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _flushResult!,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF2E7D32)),
      ),
    );
  }
}

class _QueueTab extends StatelessWidget {
  const _QueueTab();

  @override
  Widget build(BuildContext context) {
    final List<Map<String, Object?>> events = CrashReporter.instance.readQueue();
    if (events.isEmpty) {
      return const _Empty(text: '队列是空的，去实验台触发几个异常');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: <Widget>[
        for (final Map<String, Object?> e in events.reversed) _EventTile(e),
      ],
    );
  }
}

class _SentTab extends StatelessWidget {
  const _SentTab();

  @override
  Widget build(BuildContext context) {
    final List<Map<String, Object?>> events = CrashReporter.instance.sent;
    if (events.isEmpty) {
      return const _Empty(text: '还没有成功上报的记录');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: <Widget>[
        for (final Map<String, Object?> e in events) _EventTile(e),
      ],
    );
  }
}

class _LostTab extends StatelessWidget {
  const _LostTab();

  @override
  Widget build(BuildContext context) {
    final List<LostEvent> events = CrashReporter.instance.lost;
    if (events.isEmpty) {
      return const _Empty(text: '没有丢失的错误 —— 通道都装着呢');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: <Widget>[
        for (final LostEvent e in events)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.error_outline, color: Colors.redAccent),
              title: Text(
                '${e.type}: ${e.message}',
                style: const TextStyle(fontSize: 12.5),
              ),
              subtitle: Text(
                '本该走 ${e.channel.label} · ${_hhmmss(e.time)}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: Colors.black38),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.event);

  final Map<String, Object?> event;

  @override
  Widget build(BuildContext context) {
    final Channel channel = Channel.values.firstWhere(
      (Channel c) => c.name == event['channel'],
      orElse: () => Channel.manual,
    );
    final int count = (event['count'] as int?) ?? 1;
    final int retry = (event['retry'] as int?) ?? 0;
    final Map<String, Object?> ctx =
        (event['ctx'] as Map?)?.cast<String, Object?>() ?? <String, Object?>{};

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: channel.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    channel.name,
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
                if (count > 1) ...<Widget>[
                  const SizedBox(width: 6),
                  Text(
                    '×$count（去重合并后）',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9A6700),
                    ),
                  ),
                ],
                if (retry > 0) ...<Widget>[
                  const SizedBox(width: 6),
                  Text(
                    'retry=$retry',
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ],
                const Spacer(),
                Text(
                  _hhmmss(DateTime.tryParse(event['ts'] as String? ?? '') ??
                      DateTime.now()),
                  style: const TextStyle(fontSize: 10.5, color: Colors.black38),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${event['type']}: ${event['message']}',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 4),
            Text(
              'route=${ctx['route']} · ${ctx['os']} ${ctx['dart']}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            if (event['extra'] != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'extra=${event['extra']}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9A6700)),
              ),
            ],
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${event['stack']}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  height: 1.5,
                  color: Color(0xFF3D5A80),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _hhmmss(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
