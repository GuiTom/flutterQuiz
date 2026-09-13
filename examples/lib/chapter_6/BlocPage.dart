import 'dart:async';
import 'package:flutter/material.dart';

// ==========================================
// 1. Events (事件)
// 定义用户可以触发的所有动作
// ==========================================
abstract class CounterEvent {}

class IncrementCounter extends CounterEvent {}

class DecrementCounter extends CounterEvent {}

// ==========================================
// 2. States (状态)
// 定义 BLoC 可能输出的所有状态
// 状态应该是不可变的
// ==========================================
abstract class CounterState {
  final int counter;
  CounterState(this.counter);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CounterState &&
              runtimeType == other.runtimeType &&
              counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}

class CounterInitial extends CounterState {
  CounterInitial() : super(0);
}

class CounterUpdated extends CounterState {
  CounterUpdated(int newCounter) : super(newCounter);
}

// ==========================================
// 3. BLoC (业务逻辑组件)
// 处理事件，管理状态，并输出状态流
// ==========================================
class CounterBloc {
  // 初始状态
  CounterState _state = CounterInitial();

  // StreamController 用于接收 Events (输入)
  final _eventController = StreamController<CounterEvent>();
  StreamSink<CounterEvent> get eventSink => _eventController.sink;

  // StreamController 用于发送 States (输出)
  final _stateController = StreamController<CounterState>.broadcast();
  Stream<CounterState> get stateStream => _stateController.stream;

  CounterBloc() {
    // 监听事件，并根据事件类型处理业务逻辑
    _eventController.stream.listen((event) {
      if (event is IncrementCounter) {
        _mapIncrementToState();
      } else if (event is DecrementCounter) {
        _mapDecrementToState();
      }
    });
  }

  void _mapIncrementToState() {
    final newCounter = _state.counter + 1;
    _state = CounterUpdated(newCounter);
    _stateController.sink.add(_state); // 发送新状态
  }

  void _mapDecrementToState() {
    final newCounter = _state.counter - 1;
    _state = CounterUpdated(newCounter);
    _stateController.sink.add(_state); // 发送新状态
  }

  // 销毁 StreamController 以避免内存泄漏
  void dispose() {
    _eventController.close();
    _stateController.close();
  }
}

// ==========================================
// 4. View (UI 层)
// 负责发送事件和根据状态更新 UI
// ==========================================
class BLoCDesignModePage extends StatefulWidget {
  const BLoCDesignModePage({super.key});

  @override
  State<BLoCDesignModePage> createState() => _BLoCDesignModePageState();
}

class _BLoCDesignModePageState extends State<BLoCDesignModePage> {
  // 实例化 BLoC
  late final CounterBloc _counterBloc;

  @override
  void initState() {
    super.initState();
    _counterBloc = CounterBloc();
  }

  @override
  void dispose() {
    _counterBloc.dispose(); // 销毁 BLoC
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLoC 状态管理 Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              '当前计数:',
              style: TextStyle(fontSize: 24),
            ),
            // 使用 StreamBuilder 监听 BLoC 的状态流
            StreamBuilder<CounterState>(
              stream: _counterBloc.stateStream,
              initialData: CounterInitial(), // 初始数据
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                // 根据状态显示计数器值
                return Text(
                  '${snapshot.data!.counter}',
                  style: Theme.of(context).textTheme.headlineMedium,
                );
              },
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'decrement',
                  onPressed: () {
                    // 通过 sink 发送减事件
                    _counterBloc.eventSink.add(DecrementCounter());
                  },
                  tooltip: 'Decrement',
                  child: const Icon(Icons.remove),
                ),
                FloatingActionButton(
                  heroTag: 'increment',
                  onPressed: () {
                    // 通过 sink 发送加事件
                    _counterBloc.eventSink.add(IncrementCounter());
                  },
                  tooltip: 'Increment',
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
