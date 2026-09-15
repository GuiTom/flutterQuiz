# error_report —— Flutter 错误上报演示工程

一个**可以直接跑**的最小崩溃上报实现，把「第八章：错误日志收集」里的概念
全部落成能点的代码。零第三方依赖（`dart:io` + Flutter 自带的东西就够了），
方便你直接读源码。

---

## 速查卡片：一分钟记住全部规则

**终极判据（只记这一句就够）：**

> 能抓不能抓，**不看早晚看路径** —— 错误得能顺着栈，一路掀到你 `try` 那层。

**主口诀（ang 韵）：**

> 同步 throw 走栈上，try/catch 当场挡；
> async 一包进 Future，错误进箱藏；
> await 拆箱送回栈，try 又接得上；
> 没人 await 就冒泡，兜底去收场。

| 口诀 | 对应的写法 | 结果 |
|---|---|---|
| 同步 throw 走栈上 | 回调里直接 `throw` | 栈 unwind，try/catch 抓到 |
| async 一包进 Future | `async` 函数体 / `.then` 回调里 `throw` | 变成 Future 的错误，栈上抓不到 |
| await 拆箱送回栈 | `await` 一个会失败的 Future | 在 await 点重新抛出，try 又抓得到 |
| 没人 await 就冒泡 | 裸 `.then()` / Timer 回调 | 逃逸到 `PlatformDispatcher.onError` |

注意第三行是**转了两次**才回得来（async 转出去、await 转回来），两次都跟时间无关 —— 所以「异步错误 try/catch 抓不到」这句话是错的。

**await 三兄弟（a 韵）：**

> await 拆包给你抓，
> unawaited 照样爬，
> ignore 一吞全抹杀。

| 写法 | 等不等 | 错误去哪 |
|---|---|---|
| `await f` | 等 | 转回栈 → try/catch 能抓 |
| `unawaited(f)` | 不等 | **照常冒泡**到兜底 |
| `f.ignore()` | 不等 | **吞掉**，兜底再也收不到 |

最容易混的是中间那个：`unawaited` **不是**「忽略错误」，它只是「我不等你」。

**两条兜底通道（an 韵）：**

> 框架同步 FlutterError 管，
> 异步逃逸 PlatformDispatcher 拦。

这是**兜底通道**的分类，不是「能不能 try/catch」的分类。两件事混在一起，就会得出上面那句错误结论。

**上报铁律（ian 韵）：**

> 吞进 catch 的，兜底永不见；
> 跨了 isolate，堆栈断成线；
> 路由和用户 id，上报时自己填。

- 错误一旦被 `catch (e) {}` 接住，就**永远不会**到达兜底 —— 线上「崩溃率很低但用户一直反馈有问题」，八成是这个
- 跨 Isolate、或回调由 C++ 直接发起，await 挂起链就断了，堆栈里只剩 `throw` 那一行
- 所以路由、机型、用户 id 必须上报时主动塞进去，光有堆栈你不知道用户在哪个页面

---

## 跑起来

```bash
cd error_report
flutter pub get
flutter run -d macos        # 也可以 ios / android
flutter test                # 6 个用例：核心逻辑 + UI 冒烟
```

> 上报是**模拟**的：`CrashReporter._send()` 用 `Future.delayed` 假装发网络。
> 日志落地是真的，写在系统临时目录下的 `crash_queue.jsonl`。

## 你能在这里亲手验证什么

| 场景 | 会落到哪条通道 | 想说明什么 |
|---|---|---|
| ① try/catch 吞掉 | **收不到** | 被 catch 的错误永远进不了兜底。捕获了要主动上报 |
| ② 手势回调里 throw | `FlutterError.onError` | 框架在 `GestureRecognizer` 里已经 try 住了 |
| ③ build 里 throw | `FlutterError.onError` | 只有那一块子树崩，App 不死；不接就一条日志都没有 |
| ④ await 后 throw（没人 catch） | `PlatformDispatcher.onError` | 50ms 后原栈早没了，错误只能逃逸到事件循环 |
| ⑤ 未 await 的 Future | `PlatformDispatcher.onError` | 错误没有接收方；堆栈里**没有触发它的那一帧** |
| ⑥ Timer 回调里 throw | `PlatformDispatcher.onError` | 同上，回调执行时 try/catch 早执行完了 |
| ⑦ addPostFrameCallback | `FlutterError.onError` | 很多人会猜错：帧回调是框架主动调的，框架 try 住了 |
| ⑧ compute 里崩 | 要自己上报 | compute 会把错误抛回调用方，但不会自动进兜底 |
| ⑨ Isolate.spawn 里崩 | 要手动搬回 | 子 isolate 的错 root isolate 完全看不见，必须用 SendPort 传 |
| ⑩ 手动上报 | `manual` | 不崩但必须知道的问题（脏数据、非法状态）也该上报 |
| ⑪ 崩溃风暴 ×20 | 去重演示 | 队列 20 条 → 补发时聚合成 1 条 `count=20` |

**最有意思的玩法**：在「实验台」里把某条通道的开关关掉，再去点场景。
丢掉的那些错误会跑到「日志 → 已丢失」里 —— 那就是你线上后台永远看不到的崩溃。

## 目录

```
lib/
  main.dart           入口 + 接线（这段就是可以直接抄的 main()）
  crash_reporter.dart 核心：通道接线、同步落地、指纹去重、采样限流、启动补发
  scenarios.dart      11 个可点击的崩溃场景
  home_page.dart      界面：实验台 / 日志
test/
  crash_reporter_test.dart  核心逻辑单测
  smoke_test.dart           UI 冒烟
```

## 核心实现要点

**1. 崩溃回调里只做同步写，绝不 await**

```dart
void _persistSync(Map<String, Object?> event) {
  _queueFile.writeAsStringSync(
    '${jsonEncode(event)}\n',
    mode: FileMode.append,
    flush: true,
  );
}
```

崩溃那一刻进程可能几十毫秒后就没了，任何 `await` 都等不到结果。
网络请求必须留到「下次启动补发」。

**2. `PlatformDispatcher.onError` 必须 return true**

```dart
PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
  report(error, stack, channel: Channel.platform, fatal: true);
  return true;   // 返回 false = 告诉框架"没人处理"，框架会杀进程
};
```

**3. 指纹只取堆栈前 3 帧**

行号和地址每次构建都会抖，取太多帧会让同一类问题被拆成几十条，去重彻底失效。

**4. 上下文必须自己带**

异步错误的堆栈里根本没有「触发它的那一帧」（见场景 ⑤ 的堆栈），
所以 `route`、机型、版本这些必须上报时自己塞进去 —— 光有堆栈你不知道用户在哪个页面。

**5. 兜底 UI 绝不能抛异常**

`ErrorWidget.builder` 返回的 widget 里不要读 `context`、不要访问状态。
它一崩就是无限递归，直接白屏。

## 生产环境要替换的地方

文件里都标了 TODO：

| 现在（demo） | 生产环境 |
|---|---|
| `Directory.systemTemp` | `path_provider` 的 `getApplicationDocumentsDirectory()` |
| `Future.delayed` 假装发网络 | `dio` / `http` |
| `String.hashCode` 做指纹 | `crypto` 的 `sha1`（hashCode 不保证跨版本稳定） |
| 只带 os / 路由 | `device_info_plus` + `package_info_plus` + 用户 id + 网络类型 |

另外三件 demo 里没做、但线上必须做的事：

1. **脱敏** —— 日志里很容易夹带手机号、token、URL 参数，上报前必须清掉。
2. **符号化** —— 构建时 `flutter build apk --release --obfuscate --split-debug-info=build/symbols`
   并把符号文件按构建号归档。忘了这步，事后无法补救。
3. **原生崩溃** —— OOM / JNI / 系统杀进程，Dart 侧一律看不见，必须靠原生 SDK
   （Bugly / Firebase / Sentry）采集。

## 已知取舍

- 上报是模拟的，没有真实服务端。
- 队列文件用的是系统临时目录，重启系统后可能被清掉（demo 够用，生产用 documents 目录）。
- 采样用的是 `microsecondsSinceEpoch % 1000`，仅演示用，生产请用更均匀的随机源。
