import 'dart:async';

import 'package:flutter/material.dart';

import 'crash_reporter.dart';
import 'home_page.dart';

/// ============================================================
/// 入口：这段就是第八章"main() 里该怎么接线"的可运行版本
/// ============================================================
Future<void> main() async {
  // 1. main 里做任何 await 之前，必须先初始化绑定。
  //    漏了这行，后面访问插件 / 平台通道会直接抛错。
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 初始化上报器（拿到本地队列文件）。
  await CrashReporter.instance.init();

  // 3. 装上两条官方通道 + 红屏兜底。
  //    少装一条，就少看见一整类崩溃 —— 可以在 App 里手动关掉试试。
  CrashReporter.instance.setChannels(
    framework: true,
    platform: true,
    friendlyErrorWidget: true,
  );

  // 4. 上次没发出去的日志，趁这次启动补发。
  //    必须 unawaited：补发要走网络，不能卡住启动。
  unawaited(CrashReporter.instance.flush());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Error Report Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D5A80)),
        useMaterial3: true,
      ),
      // 上报时带上"当前路由"这个上下文 —— 光看堆栈你不知道用户在哪个页面
      navigatorObservers: <NavigatorObserver>[ReporterRouteObserver()],
      home: const HomePage(),
    );
  }
}
