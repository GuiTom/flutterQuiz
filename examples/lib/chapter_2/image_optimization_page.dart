import 'package:flutter/material.dart';

class ImageOptimizationPage extends StatelessWidget {
  const ImageOptimizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图片优化'),
      ),
      body: const Center(
        child: Text(
          '图片优化',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
