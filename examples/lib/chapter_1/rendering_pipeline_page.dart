import 'package:flutter/material.dart';

class RenderingPipelinePage extends StatelessWidget {
  const RenderingPipelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('渲染流程'),
      ),
      body: const Center(
        child: Text(
          '渲染流程',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
