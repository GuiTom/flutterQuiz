import 'package:flutter/material.dart';

class Chapter4Page extends StatelessWidget {
  const Chapter4Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('第四章 用户交互'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('学习命中测试、手势竞争等用户交互处理机制'),
          ),
          const Divider(),
          const Expanded(
            child: SeamlessNestedScroll(),
          ),
        ],
      ),
    );
  }
}

class SeamlessNestedScroll extends StatefulWidget {
  const SeamlessNestedScroll({super.key});

  @override
  State<SeamlessNestedScroll> createState() => _SeamlessNestedScrollState();
}

class _SeamlessNestedScrollState extends State<SeamlessNestedScroll> {
  // 父列表和子列表各自的控制器
  final ScrollController parentController = ScrollController();
  final ScrollController childController = ScrollController();

  @override
  void dispose() {
    parentController.dispose();
    childController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: parentController,
      itemCount: 40,
      itemBuilder: (context, index) {
        if (index == 5) {
          // 在第五个条目处嵌入一个固定高度的子列表
          return Container(
            height: 300,
            color: Colors.grey[200],
            child: _buildChildList(),
          );
        }
        return ListTile(title: Text("父列表条目 $index"));
      },
    );
  }

  Widget _buildChildList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) return false;
        
        if (notification is OverscrollNotification) {
          if (notification.overscroll != 0 && parentController.hasClients) {
            parentController.jumpTo(parentController.offset + notification.overscroll);
            return true;
          }
        }
        return false;
      },
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        controller: childController,
        itemCount: 20,
        itemBuilder: (context, index) => ListTile(title: Text("子列表条目 $index")),
      ),
    );
  }
}