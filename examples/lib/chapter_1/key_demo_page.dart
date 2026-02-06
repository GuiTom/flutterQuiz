import 'dart:math';

import 'package:flutter/material.dart';

class KeyDemoPage extends StatelessWidget {
  const KeyDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Key与复用'),
      ),
      body: const WrappedStatefulkeyWidget(),
    );
  }
}
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
    myColor = generateRandomColor();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: myColor,
        width: 100,height: 100,);
  }
  generateRandomColor() {
    return Color.fromARGB(
        255,
        Random().nextInt(255),
        Random().nextInt(255),
        Random().nextInt(255));
}
}
