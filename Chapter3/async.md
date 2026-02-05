# 第2节：异步

### 单线程的异步操作

应用程序大部分时间是处于空闲状态的，并不是一直在和用户进行交互。而我们的操作系统存在`阻塞式调用`和`非阻塞式调用`。

- 阻塞式调用：调用结果返回之前，当前线程会被挂起，调用线程只有在得到调用结果之后才会继续执行。
- 非阻塞式调用：调用执行之后，当前线程不会停止执行，只需要间隔一段时间来检查一下有没有结果返回即可。

Dart 的异步操作就是利用非阻塞式调用实现的。

### 什么是事件循环

和 iOS 应用很像，在 Dart 的线程中也存在事件循环和消息队列的概念，但在 Dart 中线程叫做`isolate`。应用程序启动后，开始执行 main 函数并运行 `main isolate`。

每个 isolate 包含一个事件循环以及两个事件队列，`event loop事件循环`，以及`event queue`和`microtask queue事件队列`，event 和 microtask 队列有点类似 iOS 的 source0 和source1。

- event queue：负责处理I/O事件、绘制事件、手势事件、接收其他 isolate 消息等外部事件。
- microtask queue：可以自己向 isolate 内部添加事件，事件的优先级比 event queue高。

<img src="./assets/image-20231211155527350.png" alt="image-20231211155527350" style="zoom:50%;" />

## Dart 中的异步

Dart中的异步操作主要使用`Future`以及`async`、`await`，async 和 await 是要一起使用的，这就是协程的一个语法糖。

- Future 延时操作的一个封装，可以将异步任务封装为`Future`对象，我们通常通过then()来处理返回的结果
- async 用于标明函数是一个异步函数，其返回值类型是Future类型
- await 用来等待耗时操作的返回结果，这个操作会阻塞到后面的任务

### 什么是协程

协程分为`无线协程`和`有线协程`，无线协程在离开当前调用位置时，会将当前变量放在堆区，当再次回到当前位置时，还会继续从堆区中获取到变量。所以，一般在执行当前函数时就会将变量直接分配到堆区，而`async`、`await`就属于无线协程的一种。有线协程则会将变量继续保存在栈区，在回到指针指向的离开位置时，会继续从栈中取出调用。

### async、await原理

以 async、await为例，协程在执行时，执行到`async`则表示进入一个协程，会同步执行`async`的代码块。`async`的代码块本质上也相当于一个函数，并且有自己的上下文环境。当执行到`await`时，则表示有任务需要等待，CPU 则去调度执行其他 IO，也就是后面的代码或其他协程代码。过一段时间 CPU 就会轮循一次，看某个协程是否任务已经处理完成，有返回结果可以被继续执行，如果可以被继续执行的话，则会沿着上次离开时指针指向的位置继续执行，也就是`await`标志的位置。

由于并没有开启新的线程，只是进行 IO 中断改变 CPU 调度，所以网络请求这样的异步操作可以使用`async`、`await`，但如果是执行大量耗时同步操作的话，应该使用`isolate`开辟新的线程去执行。

例子:

~~~
Future<void> main() async {
  print('A');
  Future((){//event队列
    print('B');
    sleep(Duration(seconds: 1));
    print('D');
  }).then((value) {
    print('F');
  });
  Future((){//event 队列
    print('G');
    sleep(Duration(seconds: 1));
    print('H');
  });
  scheduleMicrotask(() {//micro toask 队列
    print('E');
  });
  print('C');
}
~~~

输出:

A C E B D F G H

### Completer

在Flutter中，Completer是一个非常有用的工具，用于处理异步操作。它允许你在某个异步操作完成时手动发出信号，并且可以通过Future对象等待该信号。
```
import 'dart:async';

void main() async{
  // 创建一个Completer


  // 模拟一个异步操作，比如网络请求
  Completer simulateNetworkRequest()  {
    Completer<String> completer = Completer();
    Future.delayed(Duration(seconds: 2),(){
      completer.complete('Operation completed successfully'); // 异步操作完成，发出完成信号
    }); // 模拟一个2秒的延迟

    return completer;
  }
  print("这一行一开始就打印");
  // 启动异步操作
 Completer completer = simulateNetworkRequest();
  print("这一行紧接着上一个print打印");
  // 等待异步操作完成
  await completer.future;
  print("这一行两秒后才打印");
}

```

