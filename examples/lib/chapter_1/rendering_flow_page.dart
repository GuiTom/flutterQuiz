import 'package:flutter/material.dart';

class Chapter1Page extends StatelessWidget {
  const Chapter1Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('第一章 渲染流程'),
      ),
      body: const Center(
        child: Text('深入理解 Flutter 的三棵树、渲染流程和 key 的复用机制'),
      ),
    );
  }
}
