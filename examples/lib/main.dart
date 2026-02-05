import 'package:flutter/material.dart';
import 'chapter_1/rendering_flow_page.dart';
import 'chapter_2/performance_optimization_page.dart';
import 'chapter_3/threading_isolate_async_page.dart';
import 'chapter_4/user_interaction_page.dart';
import 'chapter_5/advanced_dart_syntax_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Study',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(title: 'Flutter 学习目录'),
        '/Chapter1/README': (context) => const Chapter1Page(),
        '/Chapter2/README': (context) => const Chapter2Page(),
        '/Chapter3/README': (context) => const Chapter3Page(),
        '/Chapter4/README': (context) => const Chapter4Page(),
        '/Chapter5/README': (context) => const Chapter5Page(),
      },
    );
  }
}

class Chapter {
  final String icon;
  final String title;
  final String details;
  final String link;

  const Chapter({
    required this.icon,
    required this.title,
    required this.details,
    required this.link,
  });
}


class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  final List<Chapter> chapters = const [
    Chapter(
      icon: '🎨',
      title: '第一章 渲染流程',
      details: '深入理解 Flutter 的三棵树、渲染流程和 key 的复用机制',
      link: '/Chapter1/README',
    ),
    Chapter(
      icon: '⚡',
      title: '第二章 性能优化',
      details: '掌握 widget 重建、布局、离屏渲染、图片和绘制边界等优化技巧',
      link: '/Chapter2/README',
    ),
    Chapter(
      icon: '🔄',
      title: '第三章 线程/isolate/异步',
      details: '理解 Flutter 的线程模型和异步编程机制',
      link: '/Chapter3/README',
    ),
    Chapter(
      icon: '👆',
      title: '第四章 用户交互',
      details: '学习命中测试、手势竞争等用户交互处理机制',
      link: '/Chapter4/README',
    ),
    Chapter(
      icon: '📚',
      title: '第五章 生僻语法',
      details: '探索 Dart 语言中的高级语法特性',
      link: '/Chapter5/README',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: chapters.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12.0),
        itemBuilder: (context, index) {
          final chapter = chapters[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10.0,
              ),
              leading: Text(
                chapter.icon,
                style: const TextStyle(fontSize: 32),
              ),
              title: Text(
                chapter.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  chapter.details,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(context, chapter.link);
              },
            ),
          );
        },
      ),
    );
  }
}

