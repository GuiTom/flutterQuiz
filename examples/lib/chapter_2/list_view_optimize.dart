import 'package:flutter/material.dart';

/// ListView.builder 懒加载（分页加载）示例
class ListViewOptimizePage extends StatefulWidget {
  const ListViewOptimizePage({super.key});

  @override
  State<ListViewOptimizePage> createState() => _ListViewOptimizePageState();
}

class _ListViewOptimizePageState extends State<ListViewOptimizePage> {
  // 数据源
  final List<String> _items = List.generate(50, (i) => "Item $i");
  
  // 滚动控制器
  final ScrollController _scrollController = ScrollController();
  
  // 加载状态
  bool _isLoading = false;
  bool _hasMore = true; // 是否还有更多数据

  @override
  void initState() {
    super.initState();
    // 监听滚动
    _scrollController.addListener(() {
      // 滚动到距离底部 100 像素时加载更多
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        _loadMore();
      }
    });
  }

  // 模拟分页请求
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    // 模拟网络请求延迟
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      int start = _items.length;
      // 每次加载 10 条
      _items.addAll(List.generate(10, (i) => "Item ${start + i} (new)"));
      _isLoading = false;
      
      // 模拟总数限制为 60 条
      if (_items.length >= 60) {
        _hasMore = false;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ListView 懒加载优化'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // 模拟下拉刷新
          await Future.delayed(const Duration(seconds: 1));
          setState(() {
            _items.clear();
            _items.addAll(List.generate(20, (i) => "Refreshed Item $i"));
            _hasMore = true;
          });
        },
        child: ListView.builder(
          controller: _scrollController,
          // physics: const AlwaysScrollableScrollPhysics(),
          // 列表长度 + 1 用于显示底部的 Loading 状态
          itemCount: _items.length + 1,
          cacheExtent: 50,
          itemBuilder: (context, index) {
            // 如果是最后一个，显示加载指示器
            print("list builder: $index");
            if (index == _items.length) {
              return _buildFooter();
            }

            // 这里的每一个 ListTile 都是在进入屏幕时才真正构建的（懒加载）
            return ListTile(
              leading: CircleAvatar(child: Text("$index")),
              title: Text(_items[index]),
              subtitle: const Text("这是一个懒加载生成的列表项"),
            );
          },
        ),
      ),
    );
  }

  // 底部状态显示
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _hasMore
            ? (_isLoading
                ? const Column(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 10),
                      Text("加载中...", style: TextStyle(color: Colors.grey)),
                    ],
                  )
                : const Text("上拉加载更多", style: TextStyle(color: Colors.grey)))
            : const Text("--- 我是有底线的 ---", style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
