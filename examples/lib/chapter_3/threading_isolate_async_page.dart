import 'package:flutter/material.dart';

class Chapter3Page extends StatelessWidget {
  const Chapter3Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('第三章 线程/isolate/异步'),
      ),
      body: const Center(
        child: Text('理解 Flutter 的线程模型和异步编程机制'),
      ),
    );
  }
}
