import 'package:flutter/material.dart';

class WidgetRebuildPage extends StatelessWidget {
  const WidgetRebuildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget重建优化'),
      ),
      body: const Center(
        child: Text(
          'Widget重建优化',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
