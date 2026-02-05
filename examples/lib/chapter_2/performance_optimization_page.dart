import 'package:flutter/material.dart';

class Chapter2Page extends StatelessWidget {
  const Chapter2Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('第二章 性能优化'),
      ),
      body: const Center(
        child: Text('掌握 widget 重建、布局、离屏渲染、图片和绘制边界等优化技巧'),
      ),
    );
  }
}
