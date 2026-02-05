import 'package:flutter/material.dart';

class KeyDemoPage extends StatelessWidget {
  const KeyDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Key与复用'),
      ),
      body: const Center(
        child: Text(
          'Key与复用',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
