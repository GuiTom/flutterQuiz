import 'package:flutter/material.dart';

class OffscreenRenderingPage extends StatelessWidget {
  const OffscreenRenderingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('离屏渲染优化'),
      ),
      body: const Center(
        child: Text(
          '离屏渲染优化',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
