import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// ---------------
// 1. 自定义 Widget（配置树）
// ---------------
class MyCustomWidget extends SingleChildRenderObjectWidget {
  const MyCustomWidget({super.child});

  // 官方必须实现：创建 Element
  @override
  SingleChildRenderObjectElement createElement() {
    return SingleChildRenderObjectElement(this);
  }

  // 官方必须实现：创建 RenderObject
  @override
  RenderObject createRenderObject(BuildContext context) {
    return MyRenderObject();
  }
}

// ---------------
// 2. 自定义 RenderObject（渲染树）
// ---------------
class MyRenderObject extends RenderBox {
  // 布局
  @override
  void performLayout() {
    super.performLayout();
    size = const Size(466, 725); // 固定宽高
  }

  // 绘制
  @override
  void paint(PaintingContext context, Offset offset) {
    final paint = Paint()..color = Colors.red;
    context.canvas.drawRect(offset & size, paint);
  }
}

