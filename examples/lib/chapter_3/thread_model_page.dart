import 'package:flutter/material.dart';

class ThreadModelPage extends StatelessWidget {
  const ThreadModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('线程模型'),
      ),
      body: const Center(
        child: Text(
          '线程模型',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
