import 'package:flutter/material.dart';

class LayoutOptimizationPage extends StatelessWidget {
  const LayoutOptimizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('布局优化'),
      ),
      body: const Center(
        child: Text(
          '布局优化',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
