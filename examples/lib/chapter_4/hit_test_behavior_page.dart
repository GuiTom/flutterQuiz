import 'package:flutter/material.dart';

class HitTestBehaviorPage extends StatelessWidget {
  const HitTestBehaviorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HitTestBehavior'),
      ),
      body: const Center(
        child: Text(
          'HitTestBehavior',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
