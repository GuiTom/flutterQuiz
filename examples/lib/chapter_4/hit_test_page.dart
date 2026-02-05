import 'package:flutter/material.dart';

class HitTestPage extends StatelessWidget {
  const HitTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('点击测试'),
      ),
      body: const Center(
        child: Text(
          '点击测试',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
