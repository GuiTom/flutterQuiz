import 'package:flutter/material.dart';

class ThreeTreesPage extends StatelessWidget {
  const ThreeTreesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('三棵树'),
      ),
      body: const Center(
        child: Text(
          '三棵树',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
