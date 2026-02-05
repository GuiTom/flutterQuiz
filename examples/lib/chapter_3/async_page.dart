import 'package:flutter/material.dart';

class AsyncPage extends StatelessWidget {
  const AsyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('异步'),
      ),
      body: const Center(
        child: Text(
          '异步',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
