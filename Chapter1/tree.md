# 第1节：三棵树

### Widget\Element\RenderObject的关系？他们是如何协作的？

![三棵树图片](./assets/image-20230917081238786.webp "渲染流程建立的三棵树")

​												图一 flutter的三棵树

##### 思考：如果想打印出某个指定widget从开始build到渲染到屏幕上面所花费的时间，可能实现吗？

答案是无法直接打印出，因为该各个widget的构建、布局、和渲染是相互并存交叉的。 

而是只能通过注释掉该widget的构建，并打印对比注释前后渲染一帧所需的时间估算渲染时间差,如下代码

```dart
  @override
  void initState() {
    super.initState();
    final startTime = DateTime.now().microsecondsSinceEpoch;
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      // 在每一帧渲染后调用
      final endTime = DateTime.now().microsecondsSinceEpoch;
      print('one frame cost：${endTime-startTime} mcrosencond');//打印出第一帧渲染所需要的时间
    });
  }
```

或者通过dev tools 里面的performance layer的图层来分析

