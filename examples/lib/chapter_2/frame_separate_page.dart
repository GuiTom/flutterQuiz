import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FrameSeparatePage extends StatefulWidget {
  const FrameSeparatePage({super.key});

  @override
  State<FrameSeparatePage> createState() => _FrameSeparatePageState();
}

class _FrameSeparatePageState extends State<FrameSeparatePage> {
  List<Widget> items = [];
  bool isLoading = false;
  int count = 0;

  // 模拟耗时组件构建
  Widget _buildHeavyWidget(int index) {
    // 模拟耗时操作，例如复杂的计算或布局嵌套
    // 在真实场景中，这可能是复杂的富文本、大图处理等
    // 这里我们只是简单返回一个带有 index 的组件，但在大量构建时仍会消耗时间
    // 为了增加构建压力，我们嵌套多层
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.primaries[index % Colors.primaries.length].withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Text('Item $index', style: const TextStyle(fontSize: 16)),
          const Spacer(),
          // 增加一些无意义的组件来增加构建负担
          ...List.generate(10, (i) => Icon(Icons.adb, size: 10, color: Colors.grey.withOpacity(0.5))),
        ],
      ),
    );
  }

  // 1. 直接加载（会造成卡顿）
  void _loadBlocking() {
    setState(() {
      items.clear();
      isLoading = true;
    });

    // 可以在下一帧执行，确实让 loading 先转起来
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final startTime = DateTime.now();
      
      final newItems = <Widget>[];
      // 瞬间生成大量 Item
      for (int i = 0; i < 4000; i++) {
        newItems.add(_buildHeavyWidget(i));
      }

      setState(() {
        items = newItems;
        isLoading = false;
      });
      
      final endTime = DateTime.now();
      print('Blocking Load Cost: ${endTime.difference(startTime).inMilliseconds}ms');
    });
  }

  // 2. 分帧加载（保持流畅）
  Future<void> _loadSeparated() async {
    setState(() {
      items.clear();
      isLoading = true;
    });
    
    final total = 4000;
    final batchSize = 100; // 每帧处理的数量
    int loaded = 0;

    // 使用 Future 递归或循环分批处理
    while (loaded < total) {
      final startTime = DateTime.now();
      
      // 生成一批
      final endIndex = (loaded + batchSize < total) ? loaded + batchSize : total;
      final batchItems = <Widget>[];
      for (int i = loaded; i < endIndex; i++) {
        batchItems.add(_buildHeavyWidget(i));
      }
      
      // 更新 UI (添加一批)
      if (mounted) {
        setState(() {
          items.addAll(batchItems);
        });
      }

      loaded = endIndex;

      // 关键：由于 setState 会触发 build，我们等待下一帧，让 UI 有机会刷新
      // await Future.delayed(Duration.zero); // 这是一个简单的让出控制权的方法
      
      // 更优解：如果是单纯为了让出 UI 线程，这就够了。
      // 更精细的控制可以使用 SchedulerBinding
      await Future.delayed(const Duration(milliseconds: 16)); 
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分帧渲染优化'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  '点击下方按钮观察 Loading 动画的流畅度',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (isLoading)
                  const CircularProgressIndicator() // 观察这个 Loading 是否卡顿
                else
                  const SizedBox(height: 36, child: Text('完成')),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: isLoading ? null : _loadBlocking,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
                      child: const Text('直接加载\n(卡顿)'),
                    ),
                    ElevatedButton(
                      onPressed: isLoading ? null : _loadSeparated,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100),
                      child: const Text('分帧加载\n(流畅)'),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => items.clear()), 
                  child: const Text('清空列表')
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return items[index];
              },
            ),
          ),
        ],
      ),
    );
  }
}
