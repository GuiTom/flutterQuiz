import 'package:flutter/material.dart';

class FrameSeparatePage extends StatelessWidget {
  const FrameSeparatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分帧渲染优化'),
      ),
      body: const Center(
        child: Text(
          '分帧渲染优化',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
