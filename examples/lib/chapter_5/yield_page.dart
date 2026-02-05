import 'package:flutter/material.dart';

class YieldPage extends StatelessWidget {
  const YieldPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('yield'),
      ),
      body: const Center(
        child: Text(
          'yield',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
