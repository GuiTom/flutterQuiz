import 'package:flutter/material.dart';

class LifecyclePage extends StatelessWidget {
  const LifecyclePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('State生命周期'),
      ),
      body: const Center(
        child: Text(
          'State生命周期',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
