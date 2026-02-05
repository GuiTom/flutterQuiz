#!/bin/bash

# Function to create a page
create_page() {
    local file_path=$1
    local class_name=$2
    local title=$3
    
    cat <<EOF > "$file_path"
import 'package:flutter/material.dart';

class $class_name extends StatelessWidget {
  const $class_name({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('$title'),
      ),
      body: const Center(
        child: Text(
          '$title',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
EOF
}

# Chapter 1
create_page "examples/lib/chapter_1/key_demo_page.dart" "KeyDemoPage" "Key与复用"
create_page "examples/lib/chapter_1/rendering_pipeline_page.dart" "RenderingPipelinePage" "渲染流程"
create_page "examples/lib/chapter_1/three_trees_page.dart" "ThreeTreesPage" "三棵树"

# Chapter 2
create_page "examples/lib/chapter_2/frame_separate_page.dart" "FrameSeparatePage" "分帧渲染优化"
create_page "examples/lib/chapter_2/image_optimization_page.dart" "ImageOptimizationPage" "图片优化"
create_page "examples/lib/chapter_2/layout_optimization_page.dart" "LayoutOptimizationPage" "布局优化"
create_page "examples/lib/chapter_2/offscreen_rendering_page.dart" "OffscreenRenderingPage" "离屏渲染优化"
create_page "examples/lib/chapter_2/repaint_boundary_page.dart" "RepaintBoundaryPage" "绘制边界"
create_page "examples/lib/chapter_2/widget_rebuild_page.dart" "WidgetRebuildPage" "Widget重建优化"

# Chapter 3
create_page "examples/lib/chapter_3/async_page.dart" "AsyncPage" "异步"
create_page "examples/lib/chapter_3/thread_model_page.dart" "ThreadModelPage" "线程模型"

# Chapter 4
create_page "examples/lib/chapter_4/gesture_arena_page.dart" "GestureArenaPage" "手势竞争"
create_page "examples/lib/chapter_4/hit_test_page.dart" "HitTestPage" "点击测试"
create_page "examples/lib/chapter_4/hit_test_behavior_page.dart" "HitTestBehaviorPage" "HitTestBehavior"
create_page "examples/lib/chapter_4/lifecycle_page.dart" "LifecyclePage" "State生命周期"

# Chapter 5
create_page "examples/lib/chapter_5/yield_page.dart" "YieldPage" "yield"
