# 第3节：key与复用

### 小测验         

####   1.     下列关于widget、element的关系正确的是:

A. 每个widget对应生成一个element,每个element会对应生成一个RenderObect

B. 每个widget对应生成一个element,element 不一定生成RenderOject

C. 所有的widget都会参与布局，但不一定会参与渲染画面

D. Element的deactivate方法是将自身销毁，而unmount方法是将自身存放到资源池，以待下次需要时重新调用


####    2.     下列关于widget key 的说法正确的是:

A.      ValueKey会对比对象的内存地址，如果是同一内存地址就会任务是同一个key，而ObjectKey是对比对象的数值，如果数值相等就认为是同一个key

B.     当两个兄弟组件都需要表现各自的不同属性，且需要改变组件渲染的顺序，并且都是StateflulWidget的时候，才需要使用key属性

C.     使用了key属性的widget在组件顺序发生改变的时候都能被正确识别

D.     无论是localKey还是GlobalKey都是为了标识element和widget,方便element在资源池里面调度



#### 3.  问:flutter绘制了两个并排的widget和一个按钮，他们的效果图和实现代码如下:

![image-20230925144433978](./assets/image-20230925144433978.webp)

```dart
class WrappedStatefulkeyWidget extends StatefulWidget {
  const WrappedStatefulkeyWidget({super.key});
  @override
  State<StatefulWidget> createState() => _WrappedStatefulkeyState();
}
class _WrappedStatefulkeyState extends State<WrappedStatefulkeyWidget> {

  List<Widget> tiles = [
    Padding(
      padding: const EdgeInsets.all(8.0),
      child: StatefulColorfulTile(key:const ValueKey(1)),
    ),
    Padding(
      padding: const EdgeInsets.all(8.0),
      child: StatefulColorfulTile(key:const ValueKey(2)),
    ),
  ];  


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: tiles),
      floatingActionButton: FloatingActionButton(
          onPressed: swapTiles,
          child: const Icon(Icons.sentiment_very_satisfied)),
    );
  }

  swapTiles() {
    setState(() {
      tiles = tiles.reversed.toList();
    });
  }
}

class StatefulColorfulTile extends StatefulWidget {
  StatefulColorfulTile({Key? key}) : super(key: key);  // NEW CONSTRUCTOR

  @override
  ColorfulTileState createState() => ColorfulTileState();
}

class ColorfulTileState extends State<StatefulColorfulTile> {
  Color? myColor;

  @override
  void initState() {
    super.initState();
    myColor = UniqueColorGenerator.generateRandomColor();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: myColor,
        width: 100,height: 100,);
  }
}
```

1.当点击按钮，将两个titles数组里面的两个Padding widget调换顺序，色块的颜色会改变吗？

2.如果Padding 换成 StatefulWidget呢？会有什么不同？
3.如果子Padding的子StatefulColorfulWidget的key 换成不重复的GlobalKey或者ValueKey会有不一样的结果吗？
解析:https://docs.qq.com/doc/DRWJhaXlQV25id2JB
