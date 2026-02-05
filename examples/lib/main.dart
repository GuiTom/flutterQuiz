import 'package:flutter/material.dart';
import 'chapter_1/key_demo_page.dart';
import 'chapter_1/rendering_pipeline_page.dart';
import 'chapter_1/three_trees_page.dart';
import 'chapter_2/frame_separate_page.dart';
import 'chapter_2/image_optimization_page.dart';
import 'chapter_2/layout_optimization_page.dart';
import 'chapter_2/offscreen_rendering_page.dart';
import 'chapter_2/repaint_boundary_page.dart';
import 'chapter_2/widget_rebuild_page.dart';
import 'chapter_3/async_page.dart';
import 'chapter_3/thread_model_page.dart';
import 'chapter_4/gesture_arena_page.dart';
import 'chapter_4/hit_test_page.dart';
import 'chapter_4/hit_test_behavior_page.dart';
import 'chapter_4/lifecycle_page.dart';
import 'chapter_4/user_interaction_page.dart';
import 'chapter_5/yield_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Quiz',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(title: 'Flutter Quiz'),
      },
    );
  }
}

class MenuItem {
  final dynamic icon;
  final String title;
  final String? subtitle;
  final WidgetBuilder? pageBuilder;
  final String? link;

  const MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.pageBuilder,
    this.link,
  });
}

class MenuSection {
  final String title;
  final List<MenuItem> items;

  const MenuSection({
    required this.title,
    required this.items,
  });
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  static final List<MenuSection> sections = [
    MenuSection(
      title: '快速开始',
      items: [
         MenuItem(
          icon: Icons.rocket_launch,
          title: '开始阅读',
          // Links to the first actual chapter content
          pageBuilder: (context) => const RenderingPipelinePage(), 
        ),
        const MenuItem(
          icon: Icons.code,
          title: 'GitHub',
          link: 'https://github.com/GuiTom/flutterQuiz',
        ),
      ],
    ),
    MenuSection(
      title: '第一章 渲染流程',
      items: [
        MenuItem(
          icon: '1.1',
          title: '渲染流程',
          pageBuilder: (context) => const RenderingPipelinePage(),
        ),
         MenuItem(
          icon: '1.2',
          title: '三棵树',
          pageBuilder: (context) => const ThreeTreesPage(),
        ),
         MenuItem(
          icon: '1.3',
          title: 'Key与复用',
          pageBuilder: (context) => const KeyDemoPage(),
        ),
      ],
    ),
    MenuSection(
      title: '第二章 性能优化',
      items: [
         MenuItem(
          icon: '2.1',
          title: 'Widget重建优化',
          pageBuilder: (context) => const WidgetRebuildPage(),
        ),
         MenuItem(
          icon: '2.2',
          title: '绘制边界',
          pageBuilder: (context) => const RepaintBoundaryPage(),
        ),
         MenuItem(
          icon: '2.3',
          title: '离屏渲染优化',
          pageBuilder: (context) => const OffscreenRenderingPage(),
        ),
        MenuItem(
          icon: '2.4',
          title: '布局优化',
          pageBuilder: (context) => const LayoutOptimizationPage(),
        ),
        MenuItem(
          icon: '2.5',
          title: '图片优化',
          pageBuilder: (context) => const ImageOptimizationPage(),
        ),
        MenuItem(
          icon: '2.6',
          title: '分帧渲染优化',
          pageBuilder: (context) => const FrameSeparatePage(),
        ),
      ],
    ),
    MenuSection(
      title: '第三章 线程/Isolate/异步',
      items: [
         MenuItem(
          icon: '3.1',
          title: '线程模型',
          pageBuilder: (context) => const ThreadModelPage(),
        ),
         MenuItem(
          icon: '3.2',
          title: '异步',
          pageBuilder: (context) => const AsyncPage(),
        ),
      ],
    ),
    MenuSection(
      title: '第四章 用户交互',
      items: [
         MenuItem(
          icon: '4.1',
          title: '点击测试',
          pageBuilder: (context) => const HitTestPage(),
        ),
         MenuItem(
          icon: '4.2',
          title: 'HitTestBehavior',
          pageBuilder: (context) => const HitTestBehaviorPage(),
        ),
         MenuItem(
          icon: '4.3',
          title: '手势竞争',
          pageBuilder: (context) => const GestureArenaPage(),
        ),
         MenuItem(
          icon: '4.4',
          title: 'State生命周期',
          pageBuilder: (context) => const LifecyclePage(),
        ),
        MenuItem(
          icon: '4.5',
          title: 'ListView嵌套滚动',
          pageBuilder: (context) => const NestedListView(),
        ),
      ],
    ),
    MenuSection(
      title: '第五章 生僻语法',
      items: [
         MenuItem(
          icon: '5.1',
          title: 'Yield',
          pageBuilder: (context) => const YieldPage(),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 20),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return _buildSection(context, section);
        },
      ),
    );
  }

  Widget _buildSection(BuildContext context, MenuSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8, top: 0),
          child: Text(
            section.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
          ),
          child: Column(
            children: List.generate(section.items.length, (index) {
              final item = section.items[index];
              final isLast = index == section.items.length - 1;
              return Column(
                children: [
                  _buildListTile(context, item),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      indent: 56,
                      thickness: 0.5,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildListTile(BuildContext context, MenuItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.blueAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: item.icon is IconData
            ? Icon(item.icon, color: Colors.blueAccent, size: 20)
            : Text(
                item.icon.toString(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
      ),
      subtitle: item.subtitle != null
          ? Text(
              item.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: () {
        if (item.link != null) {
          // Handle external link
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening ${item.link}...')),
          );
        } else if (item.pageBuilder != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: item.pageBuilder!),
          );
        }
      },
    );
  }
}
