import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:error_report/crash_reporter.dart';

void main() {
  setUp(() async {
    // 每个测试进程用独立目录，避免并发跑测试时互相踩队列文件。
    CrashReporter.instance.queueDirName = 'error_report_test_$pid';
    await CrashReporter.instance.init();
    CrashReporter.instance.clearQueue();
    CrashReporter.instance.currentRoute = '/';
  });

  test('同一异常的指纹相同，不同异常的指纹不同', () {
    final CrashReporter reporter = CrashReporter.instance;
    final StackTrace stack = StackTrace.current;

    final String a = reporter.fingerprint(StateError('x'), stack);
    final String b = reporter.fingerprint(StateError('x'), stack);

    expect(a, b);
    expect(reporter.fingerprint(ArgumentError('y'), stack), isNot(a));
  });

  test('report 之后同步可读，并且带上了路由上下文', () {
    final CrashReporter reporter = CrashReporter.instance;
    reporter.currentRoute = '/detail';

    // 关键：report 返回后立刻就能读到 —— 落地是同步写，没有 await。
    reporter.report(StateError('hello'), StackTrace.current);

    final List<Map<String, Object?>> queue = reporter.readQueue();
    expect(queue.length, 1);
    expect(queue.first['type'], 'StateError');
    expect(queue.first['message'], contains('hello'));
    expect(queue.first['channel'], Channel.manual.name);
    expect((queue.first['ctx'] as Map)['route'], '/detail');
  });

  test('同一异常重复上报会在补发时被聚合', () async {
    final CrashReporter reporter = CrashReporter.instance;

    for (int i = 0; i < 5; i++) {
      reporter.report(StateError('storm'), StackTrace.current);
    }
    expect(reporter.readQueue().length, 5);

    final FlushResult result = await reporter.flush();

    expect(result.sent, 1); // 五条合并成一条
    expect(result.merged, 4);
    expect(reporter.sent.first['count'], 5);
    expect(reporter.readQueue(), isEmpty);
  });

  test('补发失败时日志留在队列里并 retry+1', () async {
    final CrashReporter reporter = CrashReporter.instance;
    reporter.simulateNetworkFailure = true;
    addTearDown(() => reporter.simulateNetworkFailure = false);

    reporter.report(StateError('offline'), StackTrace.current);

    final FlushResult result = await reporter.flush();

    expect(result.sent, 0);
    expect(result.failed, 1);
    final List<Map<String, Object?>> queue = reporter.readQueue();
    expect(queue.length, 1);
    expect(queue.first['retry'], 1);
  });
}
