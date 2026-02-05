import 'package:flutter/material.dart';

class RepaintBoundaryPage extends StatelessWidget {
  const RepaintBoundaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('绘制边界'),
      ),
      body: const Center(
        child: Text(
          '绘制边界',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
