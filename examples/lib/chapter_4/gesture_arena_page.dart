import 'package:flutter/material.dart';

class GestureArenaPage extends StatelessWidget {
  const GestureArenaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手势竞争'),
      ),
      body: const Center(
        child: Text(
          '手势竞争',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
