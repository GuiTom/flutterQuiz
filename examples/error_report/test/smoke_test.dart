import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:error_report/crash_reporter.dart';
import 'package:error_report/home_page.dart';

void main() {
  setUp(() async {
    // 每个测试进程用独立目录，避免并发跑测试时互相踩队列文件。
    CrashReporter.instance.queueDirName = 'error_report_test_$pid';
    await CrashReporter.instance.init();
    CrashReporter.instance.clearQueue();
    CrashReporter.instance.setChannels(
      framework: true,
      platform: true,
      friendlyErrorWidget: true,
    );
  });

  testWidgets('实验台能渲染，触发异常后队列有记录', (WidgetTester tester) async {
    // 场景列表很长，把视口调高，避免按钮落在屏幕外 / 被底部导航栏挡住。
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('错误上报 · 实验台'), findsOneWidget);
    expect(find.text('① try/catch 吞掉'), findsOneWidget);
    expect(find.text('⑪ 崩溃风暴 ×20'), findsOneWidget);

    // ① 是被 try/catch 吞掉的：点完之后队列应该一条都没有。
    await tester.tap(find.byKey(const ValueKey<String>('trigger-0')));
    await tester.pump();
    expect(CrashReporter.instance.readQueue(), isEmpty);

    // ⑪ 崩溃风暴：点完队列立刻多 20 条 —— 落地是同步的，没有 await。
    await tester.tap(find.byKey(const ValueKey<String>('trigger-10')));
    await tester.pump();
    expect(CrashReporter.instance.readQueue().length, 20);
  });

  testWidgets('切到日志页能看到三个 Tab', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    await tester.tap(find.text('日志'));
    await tester.pumpAndSettle();

    expect(find.text('队列'), findsWidgets);
    expect(find.text('已上报'), findsWidgets);
    expect(find.text('已丢失'), findsWidgets);
  });
}
