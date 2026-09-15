import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'crash_reporter.dart';

/// 一个可以在界面上点出来的"崩溃"。
class Scenario {
  const Scenario({
    required this.name,
    required this.expected,
    required this.desc,
    required this.run,
  });

  final String name;

  /// 预期落到哪条通道（真正的结果以日志页为准，这里只是让你先猜）。
  final String expected;

  final String desc;

  final FutureOr<void> Function(BuildContext context) run;
}

/// 在子 isolate 里崩。必须是顶层/静态函数，compute 才能传过去。
int _boomInCompute(int value) {
  throw StateError('compute boom (value=$value)');
}

/// 自己 spawn 的 isolate 入口。
void _isolateEntry(SendPort port) {
  try {
    throw StateError('isolate boom');
  } on Object catch (error, stack) {
    // 子 isolate 的异常 root isolate 的 onError 完全看不见，
    // 只能自己 try 住，手动把 [error, stack] 发回去。
    port.send(<Object>[error, stack]);
  }
}

final List<Scenario> scenarios = <Scenario>[
  Scenario(
    name: '① try/catch 吞掉',
    expected: '❌ 兜底收不到',
    desc: '一旦被 catch，错误就永远不会走到兜底通道。'
        '线上"崩溃率很低但用户一直反馈有问题"，八成是这个。'
        '捕获了要主动上报，别空 catch。',
    run: (BuildContext context) {
      try {
        throw StateError('swallowed boom');
      } on Object catch (error) {
        debugPrint('业务自己吞掉了: $error   ← 兜底一条都收不到');
      }
    },
  ),
  Scenario(
    name: '② 手势回调里 throw',
    expected: 'framework',
    desc: 'onTap / onPressed 里同步抛出。Flutter 在 GestureRecognizer 里'
        '已经 try 住了，走 FlutterError.onError。',
    run: (BuildContext context) {
      throw StateError('gesture boom');
    },
  ),
  Scenario(
    name: '③ build 里 throw',
    expected: 'framework',
    desc: 'widget 的 build 由框架调用，框架 try 住后换成 ErrorWidget。'
        '注意：只有那一块子树崩，页面其它部分照常工作，App 也不会死。',
    run: (BuildContext context) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const _BoomPage()),
      );
    },
  ),
  Scenario(
    name: '④ await 后 throw（没人 catch）',
    expected: 'platform',
    desc: '50ms 后在微任务里抛，调用方已经不在那个栈上了，'
        '错误只能逃逸到事件循环。',
    run: (BuildContext context) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      throw StateError('awaited boom');
    },
  ),
  Scenario(
    name: '⑤ 未 await 的 Future',
    expected: 'platform',
    desc: '.then() 里抛出，但没人 await 这个 Future —— 错误没有接收方，'
        '只能进兜底。你可以打开日志看看它的堆栈：里面没有触发它的那一帧。',
    run: (BuildContext context) {
      Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
        throw StateError('orphan boom');
      });
    },
  ),
  Scenario(
    name: '⑥ Timer 回调里 throw',
    expected: 'platform',
    desc: '回调执行时原来的栈早没了，try/catch 也早就执行完了。'
        '和 ⑤ 是同一类：错误以"数据"的形式存在 Future 里，没人取就冒泡到兜底。',
    run: (BuildContext context) {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        throw StateError('timer boom');
      });
    },
  ),
  Scenario(
    name: '⑦ addPostFrameCallback',
    expected: 'framework（很多人猜错）',
    desc: '它虽然排在"下一帧"，但仍然是 SchedulerBinding 主动调用的，'
        '框架在 _invokeFrameCallback 里 try 住了 —— 所以走的是 framework 通道，'
        '不是 platform。',
    run: (BuildContext context) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        throw StateError('postframe boom');
      });
    },
  ),
  Scenario(
    name: '⑧ compute 里崩',
    expected: 'isolate（要自己上报）',
    desc: 'compute 会把子 isolate 的错误自动抛回调用方，你能 catch 到 —— '
        '但它不会自动进兜底通道，必须自己调 report()。',
    run: (BuildContext context) async {
      try {
        await compute(_boomInCompute, 1);
      } on Object catch (error, stack) {
        CrashReporter.instance.report(
          error,
          stack,
          channel: Channel.isolate,
          fatal: false,
        );
      }
    },
  ),
  Scenario(
    name: '⑨ Isolate.spawn 里崩',
    expected: 'isolate（手动搬回）',
    desc: '自己 spawn 的 isolate 更麻烦：错误不会自动抛回，'
        '只能自己 try 住、用 SendPort 手动发回来。不这么做的话，'
        '那个 isolate 会静默死掉，你一条日志都没有。',
    run: (BuildContext context) async {
      final ReceivePort port = ReceivePort();
      port.listen((Object? message) {
        if (message is List && message.length == 2) {
          CrashReporter.instance.report(
            message[0] as Object,
            message[1] as StackTrace,
            channel: Channel.isolate,
          );
          port.close();
        }
      });
      await Isolate.spawn(_isolateEntry, port.sendPort);
    },
  ),
  Scenario(
    name: '⑩ 手动上报（带上下文）',
    expected: 'manual',
    desc: '不是"崩溃"但你必须知道的问题：接口返回脏数据、状态机走到非法分支。'
        '主动调 report()，并带上 extra 业务字段。',
    run: (BuildContext context) {
      CrashReporter.instance.report(
        StateError('手动上报：订单接口返回了非法状态'),
        StackTrace.current,
        channel: Channel.manual,
        extra: <String, Object?>{
          'api': '/v1/order/detail',
          'httpCode': 200,
          'bizCode': -1,
        },
      );
    },
  ),
  Scenario(
    name: '⑪ 崩溃风暴 ×20',
    expected: '去重演示',
    desc: '连着上报 20 条一模一样的错误。队列里会有 20 条，'
        '但点"补发"之后会被聚合去重成 1 条、count=20。'
        '没有这一步，一个死循环就能把你的后台刷爆。',
    run: (BuildContext context) {
      for (int i = 0; i < 20; i++) {
        CrashReporter.instance.report(
          StateError('storm boom'),
          StackTrace.current,
          channel: Channel.manual,
        );
      }
    },
  ),
];

/// 一个 build 里会崩的页面。
class _BoomPage extends StatelessWidget {
  const _BoomPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('build 里抛错')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('↑ AppBar 是正常的，只有下面这块崩了'),
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
