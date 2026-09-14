# Flutter 高级开发工程师 · 面试题库

> 面向 3~5 年以上经验、能独立负责模块/架构的候选人。
> 出题原则：**不问 API 怎么用，只问 API 为什么这样设计、边界在哪里、代价是什么。**
> 每题后面的「考察点」是面试官用来打分的关键词，「追问」是拉开分数的地方——能答出第一层是合格，能被追到第三层才是高级。

---

## 📌 使用说明（先读这一节）

### 一、节奏：不要从头问到尾

全套题目完整问完要 **2 小时以上**，实际面试请按下面的配比裁剪：

| 环节 | 时长 | 内容 |
| --- | --- | --- |
| 项目深挖 | 10–15 min | 第 0 章（**优先级最高，不可省**） |
| 技术深挖 | 25–40 min | 按候选人背景选 1–2 个模块（见下表） |
| 场景 / 实操 | 15–20 min | 第 10、11 章 |
| 软素质 | 10–15 min | 第 12、13 章 |
| 候选人反问 | ≥ 5 min | 一定要留 |

### 二、按候选人背景选题

| 候选人画像 | 重点章节 |
| --- | --- |
| 混合开发 / 原生协作多 | 第 8 章 + 第 13 章 |
| 纯 Flutter 业务开发 | 第 2、3、4、5 章 + 第 12 章 |
| 自称做过大量性能优化 | 第 4 章 + 第 11 章 + 附录 B 链 1 / 链 3 |
| 架构 / Tech Lead 岗 | 第 12、9、5 章 + 附录 B 链 4 |
| 主导过组件库 / 基建 | 第 12、9 章 + Q5.10~Q5.12 |
| **岗位涉及 Web / 桌面** | ⚠️ 本库覆盖不足，需自行补充题目 |

### 三、三条判定原则（**非常关键**）

**① 项目深挖优先级 > 底层原理。**
项目部分答得虚，底层答得再漂亮也要打问号。警惕「源码背题选手」——能复述 Element 生命周期，但拿不出一个真实优化数据、真实踩坑案例。

**② 懂原理 ≠ 记住源码私有字段名。**
本库部分题目会提到 `_dirtyElements`、`_inheritedElements`、`_dependents`、`PersistentHashMap` 等内部字段，**这些只是给面试官的"标准答案锚点"，不是给候选人的默写题**。

- ✅ 需要：懂机制、链路、会分析现象、知道利弊
- ❌ 不要求：默写源码里的私有变量名

> 举例：候选人答不出 `_dependents` 这个名字，但能讲清"`InheritedWidget` 是**双向注册依赖**——父级记住谁订阅了它，数据变更时只通知订阅者，不是全量向上遍历查找"，**这就是合格**。

**③ 用好 Red Flags（第 14 章）。**
出现多条红色信号，哪怕技术题对很多，也要谨慎——它们往往代表工程思维缺陷，而不是知识盲区。

---

## ⚠️ 这份题库的适用边界与已知短板

> 以下不是"自我否定"，而是明确它的**定位与边界**：它是一份**深度技术面 + 业务实战面题库**，不覆盖全部能力的考察。使用时请知悉。

### 1. 底层原理偏重，业务架构与团队协作权重偏低

大量篇幅在 Dart runtime、三棵树、渲染管线、线程模型。但高级工程师还有一整块能力：

- 复杂业务模块的拆解、跨团队协作、技术方案评审、技术债务治理；
- 大业务下**组件库设计**、业务组件与通用组件的边界；
- 版本迭代、大规模代码迁移的风险评估。

原来只有少量开放设计题覆盖。**已在第 12 章补齐。**

### 2. 对"实战强但没啃过源码"的候选人存在误杀风险

现实中有一类工程师：没读过 Flutter 源码，但多年大型混合项目实战，擅长排查线上问题、做架构、做性能调优，只是对 `_inheritedElements`、`RelayoutBoundary` 这类内部字段名记不牢。

> 已在使用说明 §3② 明确判定标准，并在相关题目下加了 `⚠️` 标注。

### 3. Flutter 新版本特性覆盖偏少

本库基于 Flutter 3.x。对 **Impeller** 细节、Material 3、Android V2 embedding、Web 平台、桌面端问题覆盖很少。

> 已补 Q9.10~Q9.15。若岗位涉及 Web / 桌面，仍需自行补充。

### 4. 场景设计题好，但缺少代码实操

原来全是口头问答，而口头面试**是可以伪装的**。已在第 11 章补充「找 bug / 改代码」类实操题。

### 5. 工程化部分偏理论，缺少真实故障案例

原题目大多是概念。现实中高级开发常遇到的是：大版本升级迁移、pub 依赖冲突、多渠道产物异常、符号解析失败、线上回滚。

> 已在第 13 章补齐（以"讲你的真实案例"的方式问）。

### 6. GetX 缺少大规模项目的深度场景题

只在选型对比里提了一句。已补 Q5.10~Q5.12。

---

## 目录

- [📌 使用说明](#-使用说明先读这一节)
- [⚠️ 适用边界与已知短板](#-这份题库的适用边界与已知短板)
- [0. 开场：项目深挖](#0-开场项目深挖10-15-min)
- [1. Dart 语言与运行时](#1-dart-语言与运行时)
- [2. 三棵树：Widget / Element / RenderObject](#2-三棵树widget--element--renderobject)
- [3. 布局与渲染管线](#3-布局与渲染管线)
- [4. 性能优化](#4-性能优化)
- [5. 状态管理与架构](#5-状态管理与架构)
- [6. 线程模型 / Isolate / 异步](#6-线程模型--isolate--异步)
- [7. 手势与事件分发](#7-手势与事件分发)
- [8. 平台通道与混合开发](#8-平台通道与混合开发)
- [9. 工程化、版本演进与质量保障](#9-工程化版本演进与质量保障)
- [10. 场景设计题（开放题）](#10-场景设计题开放题)
- [11. 代码实操题（新增）](#11-代码实操题)
- [12. 业务架构与团队协作（新增）](#12-业务架构与团队协作)
- [13. 线上故障与工程实战（新增）](#13-线上故障与工程实战)
- [14. 反面信号（Red Flags）](#14-反面信号red-flags)
- [附录 A：评分维度表](#附录-a评分维度表)
- [附录 B：几条"追问链"示例](#附录-b几条追问链示例)
- [附录 C：按岗位画像组卷](#附录-c按岗位画像组卷)

---

## 0. 开场：项目深挖（10-15 min）

> 开场不考知识点，考"你到底做了什么"。所有后续技术问题都可以从这里的回答里长出来。

- **Q0.1** 挑一个你负责过的 Flutter 项目，说一下它的技术规模：页面数、团队成员、最复杂的那个页面复杂在哪？
  - 考察点：是否真在负责模块，而不是「做需求」；能否量化复杂度（不是"挺复杂的"）。
- **Q0.2** 这个项目里你做过最有技术含量的一次优化/重构是什么？优化前后数据是多少？怎么测的？
  - 考察点：**有没有数据意识**。没数据 = 没做真优化。
- **Q0.3** 项目里踩过最深的坑是什么？最后怎么定位的？
  - 考察点：排查方法论，而不是"谷歌了一下就好了"。
- **Q0.4** 如果现在让你重新设计这个项目的状态管理/架构，你会怎么改？为什么当时不这么做？
  - 考察点：**技术判断力**，能否说出当时的约束（人力、时间、团队水平），而不是一味否定过去。
- **Q0.5** 你们项目的崩溃率、ANR、帧率指标是多少？怎么采集的？
  - 考察点：线上质量意识。

---

## 1. Dart 语言与运行时

- **Q1.1** `const` 构造函数为什么能减少重建？它对 Widget 树的复用到底起什么作用？
  - 考察点：常量规范化（canonicalization）+ `identical` 判断 + `Element.updateChild` 提前 return。能说到「const 实例同一个引用，`Widget.canUpdate` 之外还有一层 `identical(newWidget, _widget)` 短路」是加分。
- **Q1.2** `late final` 和 `final` + 初始化列表有什么区别？`late` 的两层语义分别是什么？
  - 考察点：延迟初始化 vs 非空类型断言；`LateInitializationError`。
- **Q1.3** Dart 3 的 class modifiers（`interface` / `base` / `final` / `sealed` / `mixin`）解决了什么问题？
  - 考察点：跨库的继承契约、`sealed` + 穷尽 switch、编译期保证而不是靠文档约定。
- **Q1.4** 下面这段的输出顺序是什么？为什么？
  ```dart
  print('A');
  Future(() => print('B'));
  scheduleMicrotask(() => print('C'));
  Future.microtask(() => print('D'));
  print('E');
  await Future.delayed(Duration.zero);
  print('F');
  ```
  - 考察点：microtask 优先于 event task；`Future(() {})` 走 `Timer.run` 落 event queue；`await` 之后是 microtask。
- **Q1.5** `sync*` / `async*` 里的 `yield` 分别是什么语义？为什么 `sync*` 是惰性的、`Iterable` 上的 `map` 什么时候才真正执行？
  - 考察点：生成器 + 惰性求值；`Iterable` 是 pull、`Stream` 是 push。
- **Q1.6** `dynamic`、`Object?`、泛型 `T` 在 AOT 下的性能差异来自哪里？`noSuchMethod` 什么时候会被调用？
  - 考察点：是否知道 `dynamic` 走 `NoSuchMethod`/动态派发、AOT 下无法内联。
- **Q1.7** extension 和 mixin 的使用边界？为什么 extension 不能访问私有成员、不能重写方法？
  - 考察点：扩展方法是**静态解析**的，编译期决定，和虚派发的区别。
- **Q1.8** `Completer` 能取消一个 `Future` 吗？如果业务上需要"取消请求"，你会怎么做？
  - 考察点：Dart 的 Future 不可取消；`CancelableOperation`、标志位 + Token 方案。

---

## 2. 三棵树：Widget / Element / RenderObject

- **Q2.1** 为什么需要三棵树？只用 Widget + RenderObject 两棵行不行？
  - 考察点：Widget 是不可变配置、Element 承载生命周期与树结构、RenderObject 承载布局绘制；Element 是"把不可变配置映射到有状态渲染对象的胶水"。
- **Q2.2** `Widget.canUpdate(oldWidget, newWidget)` 的判断条件是什么？返回 false 之后框架会做什么？
  - 考察点：`runtimeType` 相同 **且** `key` 相同 → 复用 Element 走 `update`；否则 deactivate 旧 Element、inflate 新的（旧子树状态全丢）。
- **Q2.3** `ValueKey` / `ObjectKey` / `UniqueKey` / `GlobalKey` 各自用在哪？`GlobalKey` 的原理和代价是什么？
  - 考察点：`GlobalKey` 靠 `BuildOwner` 的全局注册表做唯一性保证，能实现**跨树搬迁 Element（保留 State）**、`currentState`/`currentContext` 访问；代价是全局 map 查找 + 重复 key 报错 + 在长列表里频繁变 key 会导致反复 rebuild/relayout。
- **Q2.4** `BuildContext` 到底是什么？`State.context` 和 `Element` 是同一个东西吗？
  - 考察点：`Element implements BuildContext`，`State.context` 就是它挂载的那个 Element。
- **Q2.5** `setState` 之后到屏幕刷新，完整链路是什么？
  - 考察点：`setState` → `element.markNeedsBuild()` → `BuildOwner` 的脏列表 → 下一帧 `drawFrame` → `buildScope` → `rebuild` → `performRebuild` → `updateChild` → layout → paint → composite → raster。
  - > ⚠️ 只需说出链路与阶段划分，不要求默写 `_dirtyElements` 之类的字段名。
- **Q2.6** 在 `didUpdateWidget` 里调 `setState` 会怎样？为什么？
  - 考察点：`didUpdateWidget` 之后框架已经会 `rebuild(force: true)`，再 setState 是多余的；更严重的是在其中触发父级状态变更会造成循环或断言。
- **Q2.7** `InheritedWidget` 的查找为什么是 O(1)？`dependOnInheritedWidgetOfExactType` 具体做了什么？
  - 考察点：每个 Element 持有一份「类型 → 最近的 InheritedElement」映射（与父节点共享 + 自身追加），因此**不是向上遍历，而是查表**；`dependOnInheritedElement` 做**双向登记**（自己记住它、它记住自己），`updateShouldNotify` 为 true 时通知所有登记过的依赖者 → `didChangeDependencies` → `markNeedsBuild`。
  - > ⚠️ 内部实现细节：**考察机制与链路，不要求默写 `_inheritedElements` / `_dependents` 等字段名。**
- **Q2.8** `getInheritedWidgetOfExactType` / `getElementForInheritedWidgetOfExactType` 和上面那个 API 的区别？什么时候必须用前者？
  - 考察点：后两者**不建立依赖**，不注册为订阅者，因此值变了不会重建；适合事件回调、以及需要在 `deactivate` 之后读一次的场景。
- **Q2.9** `InheritedWidget` / `InheritedModel` / `InheritedNotifier` 的区别？`aspect` 参数有什么用？
  - 考察点：登记依赖时可以带一个 `aspect`，`InheritedElement` 把它作为订阅者的附加信息存下来；`InheritedModel` 覆写「登记」与「通知」两个钩子，做**按 aspect 精确通知**；`InheritedNotifier` 监听 `Listenable`，靠"自己标脏 + build 时主动发通知"绕过"祖先必须换成新 widget 实例"的限制。
  - > ⚠️ 内部实现细节：不要求默写 `setDependencies` / `updateDependencies` / `notifyDependent` 的方法名。
- **Q2.10** `Theme.of(context)` 和 `MediaQuery.sizeOf(context)` 哪个更"省"？为什么 Flutter 后来加了 `xxxOf` 系列？
  - 考察点：`sizeOf` 内部用 `aspect` 做精确订阅，只有 size 变才重建；`MediaQuery.of` 任何字段变都会重建。

---

## 3. 布局与渲染管线

- **Q3.1** 描述一帧从 `scheduleFrame` 到上屏的完整流程，画出 UI / Raster / Platform 线程各自负责的阶段。
- **Q3.2** `Constraints` 向下传递、`Size` 向上返回——如果一个孩子有多个父需求（比如 `Row` 里的 `Expanded`），约束是怎么算出来的？
  - 考察点：`Row` 先算非 flexible 孩子，再把剩余空间按 flex 分配；`Flexible` 的 `fit: loose/tight`。
- **Q3.3** `IntrinsicHeight` / `IntrinsicWidth` 为什么昂贵？O(N²) 具体出在哪里？
  - 考察点：为了得到孩子理想高度需要对孩子做一次"预布局"（递归计算 intrinsic 尺寸），深度嵌套时是平方级。
- **Q3.4** 什么是 `RelayoutBoundary`？哪些条件会让一个 RenderObject 成为 relayout boundary？
  - 考察点：`!parentUsesSize || sizedByParent || constraints.isTight || 无父`；`markNeedsLayout` 只会冒泡到最近的 relayout boundary。
  - > ⚠️ 内部实现细节：说清"哪些条件"即可，不要求背字段名。
- **Q3.5** `markNeedsPaint` 和 `markNeedsLayout` 的冒泡规则有什么不同？`RepaintBoundary` 在其中起什么作用？
  - 考察点：repaint 冒泡止于最近的 repaint boundary（会创建独立 layer）；layout 冒泡止于 relayout boundary。
- **Q3.6** 什么时候该加 `RepaintBoundary`？加了会不会更慢？
  - 考察点：会——多一个 layer 意味着多一次光栅化任务、多一块 GPU 内存；只有"内部频繁重绘但外部稳定"（如动画、图表）才值得。
- **Q3.7** `Opacity`、`ClipRRect`、`Transform`、`BackdropFilter` 各自什么时候产生独立 layer 或离屏合成？`Opacity(opacity: 0.5)` 和颜色加 alpha 哪个更好？
  - 考察点：`saveLayer` 的昂贵（离屏渲染、额外纹理）；能用颜色 alpha 就不要用 `Opacity` widget。
- **Q3.8** `CustomPainter` 的 `shouldRepaint` 写 `false` 意味着什么？`CustomPaint` 配 `isComplexHint: true` 有什么用？
- **Q3.9** `Slivers` 的布局协议和 `RenderBox` 有什么本质不同？
  - 考察点：`SliverConstraints` 带 `scrollOffset`/`remainingPaintExtent`，是"我该画多少"而不是"我有多大"；`SliverGeometry` 回报 `scrollExtent`/`paintExtent`。

---

## 4. 性能优化

- **Q4.1** 用户反馈"滑动列表卡"，你怎么定位？请给出完整的排查顺序。
  - 考察点：先复现并确认真机/机型 → `--profile` 模式 → DevTools Performance 看是 UI 线程超时还是 Raster 线程超时 → 分别对应"build 太多"还是"paint 太重"→ Timeline 事件找具体 widget。
- **Q4.2** 怎么判断掉帧是 UI 线程问题还是 Raster 线程问题？两者分别的典型原因是什么？
- **Q4.3** Widget 频繁 rebuild 一定掉帧吗？
  - 考察点：不一定。Element rebuild 只更新构建，如果 layout/paint 都被复用（const、same size、boundary 命中）开销很小；**关键在于是否引发 layout/paint 级联**。
- **Q4.4** `ListView.builder` 和 `ListView(children: [...])` 的性能差异来自哪里？`itemExtent` 又优化了什么？
- **Q4.5** `shrinkWrap: true` 为什么有性能代价？
  - 考察点：需要先布局全部子项才能确定自身尺寸，牺牲了 sliver 的懒加载；替代方案是 `SliverFillRemaining` / `CustomScrollView`。
- **Q4.6** 图片优化你会做哪几件事？
  - 考察点：`cacheWidth`/`cacheHeight`（或 `ResizeImage`）按显示尺寸解码、`imageCache.maximumSizeBytes` 调优、`precacheImage`、webp、`gaplessPlayback`、避免大图直接 decode 到内存。
- **Q4.7** 怎么优化首屏启动时间？
  - 考察点：区分 engine 冷启动 / Dart VM 初始化 / 首帧 build；`deferFirstFrame`、预初始化、延迟非关键初始化、`--split-debug-info` 与 AOT 快照、原生 Splash 衔接。
- **Q4.8** 包体积怎么优化？`--split-debug-info` 和 `--obfuscate` 做了什么？
- **Q4.9** `const` 在深层 Widget 树里的"重建隔离"效果是怎么实现的？为什么有时候加了 const 还是重建了？
  - 考察点：父级 rebuild 时 `updateChild` 里 `child != newWidget` 才会重建；const 让它 `identical` 短路。但如果父级 rebuild 后传给子树的**约束发生变化**，仍会 layout。
- **Q4.10** 有一个每帧都在跑动画的页面，旁边还有个每秒刷新的时钟，怎么让时钟不拖累动画？
- **Q4.11** 你用过 `--trace-skia` 或 shader 编译卡顿排查吗？`sksl` 预热是干什么的？

---

## 5. 状态管理与架构

- **Q5.1** `setState` / `InheritedWidget` / `Provider` / `Bloc` / `Riverpod` / `GetX`，你怎么选？判断依据是什么？
  - 考察点：能否从"状态作用域、可测试性、团队熟悉度、样板代码量、编译期安全"几个维度比较，而不是"我觉得 Bloc 优雅"。
- **Q5.2** `Provider` 的 `watch` / `read` / `select` 分别什么时候用？`read` 写错了会怎样？
  - 考察点：`watch` 在 build 里建立依赖会重建；`read` 在回调里取值不订阅；`select` 按字段过滤重建。
- **Q5.3** Bloc 的 `Event → Bloc → State` 单向流，为什么强调"state 必须不可变"？`emit` 同一个 state 会通知吗？
  - 考察点：`==` 判断，相同 state 不触发重建；这也是 `Equatable`/`freezed` 的价值。
- **Q5.4** MVVM 在 Flutter 里怎么落地？ViewModel 的生命周期挂在哪儿？为什么会内存泄漏？
- **Q5.5** 什么是"状态提升"？提升的边界在哪里——什么状态该放页面级，什么该放全局？
- **Q5.6** 业务状态和视图状态（loading、展开收起、动画进度）该怎么切分？混在一起有什么问题？
- **Q5.7** 依赖注入在 Flutter 里怎么做？不用任何库能实现吗？
- **Q5.8** 一个跨页面共享的用户信息（登录态），你会用哪种方案？如果它每秒变一次呢？
  - 考察点：能否识别"变化频率"是选型的第一约束。
- **Q5.9** 你们的架构怎么保证可测试性？写一个 Bloc/ViewModel 的单测需要 mock 什么？

### GetX 专项（大项目落地）

- **Q5.10** 大型项目用 GetX 会遇到什么问题？怎么规避？
  - 考察点：能否说出——全局单例泛滥导致生命周期不可控、`Get.find` 隐式依赖使调用关系无法静态分析、`Get.put` 忘记 `Get.delete` 造成内存泄漏、路由与状态耦合导致难以按模块拆分、无编译期约束（拼错 tag 只能运行时炸）、以及和 Navigator 2.0 / 声明式路由的冲突。
- **Q5.11** `Get.put` / `Get.lazyPut` / `Get.find` / `GetBuilder` / `Obx` 的坑分别在哪儿？为什么 GetX 的代码不好写单测？
  - 考察点：隐式全局容器 → 测试之间状态互相污染，必须在 `tearDown` 里 `Get.reset()`；`Obx` 的响应式依赖靠运行时收集，容易被"不在 build 里读"绕过而失效。
- **Q5.12** 如果项目已经在用 GetX，你会怎么渐进式改造或加约束？
  - 考察点：是否能提出务实方案——约定目录/命名规范、用 lint 或自研脚本禁止 `Get.find` 出现在非指定层、把 `Get.to` 换成统一封装的 Router 层、新模块不再引入 GetX 并逐步收敛，而不是"推倒重来"。
- **Q5.13** GetX 和 `Provider` 在"页面级 + 全局级"两种作用域下的行为差异是什么？全局状态用 GetX 的代价是什么？
  - 考察点：GetX 默认倾向于全局注册，`Provider`/`Riverpod` 是树形作用域，能天然随页面销毁。

---

## 6. 线程模型 / Isolate / 异步

- **Q6.1** 说出 Flutter 的线程模型，UI / Raster / Platform / IO 线程各负责什么？
  - 考察点：能说出"我自己的 Dart 代码只在 UI 线程（root isolate）跑"，Raster 线程跑 Skia/Impeller 光栅化。
- **Q6.2** "Flutter 是单线程的"这句话对吗？怎么解释才准确？
- **Q6.3** microtask 和 event queue 的优先级关系？`Timer.run` 和 `scheduleMicrotask` 谁先？
- **Q6.4** `compute` / `Isolate.spawn` / `Isolate.run` 有什么区别？`compute` 每次调用都会新建 Isolate 吗？
  - 考察点：`compute` 在 Dart 3 之后基于 `Isolate.run`，每次调用仍会 spawn/销毁（新版本有短命 isolate 优化），高频调用应该自己维护长生命周期 Isolate。
- **Q6.5** 两个 Isolate 之间怎么传数据？为什么不能共享内存？`TransferableTypedData` 为什么快？
  - 考察点：消息拷贝语义；`TransferableTypedData` 是**转移所有权**，避免大 buffer 的复制。
- **Q6.6** 解析一个 20MB 的 JSON，怎么做到不卡 UI？
  - 考察点：`compute` + `jsonDecode`；进一步可用 `TransferableTypedData` 或流式/增量解析；注意 `jsonDecode` 产出大量小对象，GC 压力也是问题。
- **Q6.7** `await` 会新开线程吗？`await` 一个 CPU 密集的同步函数为什么还卡？
- **Q6.8** 怎么取消一个正在进行的异步任务？多个请求并发且需要"任一成功即返回"怎么写？
- **Q6.9** Isolate 里能用 `Timer` 吗？后台 Isolate 的生命周期谁负责？
- **Q6.10** 图片解码在哪个线程？`precacheImage` 之后为什么滚动还是卡？

---

## 7. 手势与事件分发

- **Q7.1** 一次 `pointer down` 到 `onTap` 触发，中间经历了哪些步骤？
  - 考察点：`PointerRouter` 分发 → `hitTest` 收集 `HitTestResult` → 各 `GestureRecognizer` 进 arena → `GestureArenaManager` → 某一方胜出 → `sweep`。
- **Q7.2** `GestureArena` 的 `add` / `resolve` / `sweep` 分别什么时候发生？为什么 `onTap` 会有一点延迟感？
- **Q7.3** `HitTestBehavior` 的 `deferToChild` / `opaque` / `translucent` 有什么区别？`Listener` 和 `GestureDetector` 怎么选？
- **Q7.4** `IgnorePointer` / `AbsorbPointer` / `TranslucentPointer` 三者的区别？
- **Q7.5** 一个 `GestureDetector` 的 `onTap` 和 `onTapDown` 谁先触发？为什么 `onTap` 要等手势竞技场结算？
- **Q7.6** 点击区域被上面的透明 widget 挡住了怎么办？`Opacity(opacity: 0)` 会拦截点击吗？
- **Q7.7** 嵌套滚动冲突怎么解决？`NestedScrollView` 内部是怎么协作的？`kTouchSlop` 是多少、代表什么？
- **Q7.8** 横向滑动列表里放一个 `GestureDetector` 的拖拽，怎么让它不跟列表抢手势？
- **Q7.9** 手势识别器要 `dispose` 吗？不 dispose 会怎样？

---

## 8. 平台通道与混合开发

- **Q8.1** `MethodChannel` / `EventChannel` / `BasicMessageChannel` 的区别和适用场景？
- **Q8.2** Platform Channel 的通信开销在哪里？`StandardMessageCodec` 有什么限制？大量数据传输怎么优化？
- **Q8.3** 你在什么情况下会用 Pigeon / FFI 而不是 MethodChannel？
- **Q8.4** `PlatformView` 为什么性能差？Android 侧有哪几种实现模式，各自的取舍是什么？
  - 考察点：Virtual Display（旧、便宜但输入/无障碍问题）、Hybrid Composition（输入准确但每帧要合成/切 surface）、Texture Layer Hybrid Composition（3.0 起默认）。能说清"为什么它天生贵"就给高分。
- **Q8.5** Flutter 页面和原生页面混排，你踩过哪些坑？（内存、生命周期、路由、返回键、`FlutterEngine` 复用）
- **Q8.6** 多引擎（多 `FlutterEngine`）和单引擎 + `FlutterViewController` 复用，怎么选？
- **Q8.7** 原生崩溃怎么映射回 Dart 侧？怎么在崩溃上报里带上 Dart 堆栈？

---

## 9. 工程化、版本演进与质量保障

- **Q9.1** 单元测试 / Widget Test / 集成测试，你们分别覆盖什么？golden test 的价值和代价？
- **Q9.2** 多环境构建怎么做？`--dart-define`、`--dart-define-from-file`、flavors 各解决什么问题？
- **Q9.3** `FlutterError.onError`、`PlatformDispatcher.instance.onError`、`runZonedGuarded` 三者捕获范围有什么不同？
  - 考察点：前者只管框架内同步异常；`onError` 覆盖未捕获异步错误；zone 方案在 3.3 之后已不推荐。
- **Q9.4** `ErrorWidget.builder` 怎么用？线上怎么避免用户看到红屏？
- **Q9.5** CI/CD 怎么搭？Flutter 版本锁定、`pubspec.lock`、产物分发（Firebase/TestFlight/内测平台）。
- **Q9.6** 为什么 Flutter 不支持"热更新"？如果业务一定要动态化，有哪些可行路径？
  - 考察点：AOT 编译 + 应用商店政策；可行路径是服务端驱动 UI（Server-Driven UI）、动态配置、下架重发。
- **Q9.7** 你们的 `analysis_options.yaml` 都开了哪些 lint？为什么有的规则要关掉？
- **Q9.8** 怎么做灰度/AB 实验？Flutter 侧需要注意什么？
- **Q9.9** 一个线上崩溃只有 Dart 堆栈，怎么定位到具体版本和符号？

### 版本演进与平台适配（新增）

- **Q9.10** Flutter 大版本升级（比如 3.7 → 3.22），你会做哪些风险评估？迁移策略是什么？
  - 考察点：列出——先跑 `flutter analyze` + 全量单测摸底、锁定 `environment` 约束、逐个 pub 依赖确认兼容版本、重点回归 `RenderObject` 自定义组件 / 平台通道 / 原生插件、利用 `deprecated_member_use` 分批清理、用 `--no-sound-null-safety` 之外的兼容包、先在一条业务线灰度而不是全量、准备好回滚方案。能否说出**升级的阻塞点通常是原生插件而不是 Flutter 本身**是加分。
- **Q9.11** pub 依赖冲突怎么排查和解决？`dependency_overrides` 的代价是什么？
  - 考察点：读 `pub deps` 的版本冲突图 → 找到共同祖先约束 → 优先升级/替换库 → `dependency_overrides` 只是**临时**手段，会导致实际运行版本与声明不符、且在下游消费方失效。
- **Q9.12** iOS 崩溃栈没有符号 / Dart 堆栈没有行号，怎么排查？
  - 考察点：`--split-debug-info` 产物必须归档、`flutter symbolize`、dSYM 上传、`--obfuscate` 后必须保留符号文件；能说出"符号文件丢了基本无法还原"。
- **Q9.13** 多渠道产物异常（某个渠道白屏 / 上报缺失 / 图标不对）怎么排查？
  - 考察点：flavor 配置与 `productFlavors`/xcconfig 对应关系、签名与 keystore、`--dart-define` 漏配、资源未打进对应渠道、CI 缓存导致产物串包。
- **Q9.14** Impeller 相比 Skia 解决了什么痛点？又会带来哪些新问题？
  - 考察点：Skia 的 shader 首次编译导致卡顿（jank）被 Impeller 用预编译 shader 消除；新问题是 iOS 之外的平台成熟度差异、某些自定义效果/`saveLayer` 表现不一致、与旧设备的兼容与回退机制、以及一些历史 `CustomPainter` 渲染结果变化。
- **Q9.15** Material 3 和 Android V2 embedding 的迁移你了解多少？
  - 考察点：M3 的 `useMaterial3`、色彩系统与组件默认样式变化带来的回归；V2 embedding 是 `FlutterActivity`/`FlutterFragment` 的注册方式变化，旧插件不兼容 V2 是主要阻塞点。

---

## 10. 场景设计题（开放题）

> 这部分是区分度最高的环节。重点不是答案对不对，而是**有没有结构化的排查/设计思路**，以及会不会主动问清约束条件。

- **Q10.1** 一个列表页在低端机滑动只有 30fps，给你 DevTools 和真机，你的排查步骤是什么？
- **Q10.2** 一个页面上有个 `setState`，一调用整个页面都重建了，怎么把重建范围缩小到最小？
- **Q10.3** 列表里每个 item 都有一个独立的循环动画，怎么保证性能？（提示方向：`AnimatedBuilder` + `RepaintBoundary` + 动画控制器复用）
- **Q10.4** 设计一个"多 Tab 页面，Tab 之间共享一份用户数据，切 Tab 不能丢滚动位置"，你怎么做？
- **Q10.5** 首屏 3 秒启动，产品要求压到 1 秒，你的优化顺序是什么？怎么证明每一步的收益？
- **Q10.6** 一个表单页需要：实时校验、防抖、失焦校验、提交时全量校验。设计一下状态和校验时机。
- **Q10.7** 实现一个"搜索框输入即请求"的功能，要求：防抖、可取消旧请求、结果不乱序、错误可重试。
- **Q10.8** 从零搭一个 Flutter 项目，你的目录结构、分层、依赖、CI 会怎么定？为什么？
- **Q10.9** 如果让你把现有项目从 `Provider` 迁到 `Riverpod`，你会怎么评估收益、怎么分批迁移？
- **Q10.10** 一个第三方库在低端机上导致掉帧，你无法修改它的源码，怎么办？

---

## 11. 代码实操题

> 口头面试是可以伪装的。条件允许时，**给一段真实代码让候选人当场找问题并修复**，判别力远高于问答。
> 用法：先给 2 分钟看，然后请他说出「有哪几个问题、优先级、怎么改」，**不要求语法完美，看的是能不能一眼看出病灶**。

### 11.1 内存泄漏（State 生命周期）

```dart
class _CounterPageState extends State<CounterPage> {
  final ValueNotifier<int> _notifier = ValueNotifier(0);
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      _notifier.value = _controller.offset.round();
    });
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: _notifier,
        builder: (_, value, __) => Text('$value'),
      );
}
```

- **问题**：`_notifier`、`_controller` 没有 `dispose`；`Timer.periodic` 没有 `cancel`（`if (mounted)` 只防住了 `setState` 报错，**没有防住 Timer 继续持有 State**）；闭包捕获了 `_notifier`，页面销毁后仍被引用。
- **修复**：`dispose()` 中 `_notifier.dispose(); _controller.dispose();`，`Timer` 提升为字段并在 `dispose` 中 `cancel()`。
- **加分**：能主动指出"`ValueListenableBuilder` 内部会自动解绑，但 `ValueNotifier` 自身仍要 dispose"，以及"如果用 `StreamSubscription` 同理要 `cancel()`"。

### 11.2 不必要的整页重建

```dart
class _PageState extends State<Page> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() => setState(() {}))
     ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HeavyChart(),
        Transform.rotate(angle: _controller.value, child: const Icon(Icons.refresh)),
        Text('$_count'),
        ElevatedButton(onPressed: () => setState(() => _count++), child: const Text('+')),
      ],
    );
  }
}
```

- **问题**：`_controller.addListener(() => setState(() {}))` 让**整个页面以 60fps 重建**；`_count` 的变更也会连带重建整个 `Column`。
- **修复**：删掉这个 listener，用 `AnimatedBuilder` / `ListenableBuilder` **只包住需要跟随动画的那一小块**；把计数抽成独立 widget 或 `ValueListenableBuilder`。
- **加分**：能指出 `const HeavyChart()` 确实被 `identical` 短路了不会 rebuild，但**父级的 `Column`、`Transform`、`ElevatedButton` 每一帧都在做 diff**，这才是浪费。

### 11.3 InheritedWidget 不生效

```dart
class _Scope extends InheritedWidget {
  const _Scope({required this.count, required super.child});
  final int count;

  @override
  bool updateShouldNotify(_Scope oldWidget) => false;
}

class _Child extends StatelessWidget {
  const _Child();

  @override
  Widget build(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_Scope>();
    return Text('${scope?.count}');
  }
}
```

- **问题**：① 用 `getInheritedWidgetOfExactType` 读取，**没有建立依赖**，父级更新永远不会重建它；② `updateShouldNotify` 恒返回 `false`，即使改成 `dependOn...` 也不会通知。
- **修复**：改用 `context.dependOnInheritedWidgetOfExactType<_Scope>()`，并把 `updateShouldNotify` 改成 `count != oldWidget.count`。
- **加分**：能指出还有第三个前提——**祖先必须真的重建并生成新的 `_Scope` 实例**，如果祖先只是内部状态变了但没 `setState`，什么都不会发生。再进一步：如果只想部分子树刷新，应该用 `InheritedModel` 或把它拆到更小的 scope。

### 11.4 布局约束错误

```dart
Column(
  children: [
    ListView(
      children: const [Text('a'), Text('b')],
    ),
  ],
)
```

- **问题**：`Column` 给子项的是**无界高度**，而 `ListView` 需要有限高度，直接触发 unbounded height 断言。
- **修复**：`Expanded(child: ListView(...))`，或换成 `CustomScrollView` + `SliverList`。
- **追问**：`ListView` 放在 `Column` 里为什么 `shrinkWrap: true` 能"修好"？它的代价是什么？（答：代价是失去懒加载）
- **延伸**：`Row` 里放 `ListView(scrollDirection: Axis.horizontal)` 会怎样？

### 11.5 异步 + dispose 竞态

```dart
Future<void> _load() async {
  final data = await api.fetch();
  setState(() => _data = data);
}

@override
Widget build(BuildContext context) => FutureBuilder(
      future: api.fetch(),
      builder: (context, snapshot) => Text('${snapshot.data}'),
    );
```

- **问题**：① 请求返回时页面可能已经 pop，`setState` 触发断言；② `FutureBuilder` 的 `future` 写在 `build` 里，**每次 rebuild 都会重新发请求**（典型死循环 + 请求风暴）。
- **修复**：`if (!mounted) return;`；把 Future 缓存在 `initState` 或 `late final` 字段里，或改用状态管理 + `CancelableOperation` 在 `dispose` 时取消。
- **加分**：能指出 `mounted` 只能防住"报错"，防不住"继续占资源"，真正的解法是**在 dispose 时取消请求**。

### 11.6 列表 Key 误用导致状态错位

```dart
ListView(
  children: items.map((e) => _ItemTile(data: e)).toList(),
)
```

- **问题**：没有 `key`，删除中间项后 `Widget.canUpdate` 会按**位置**复用 Element，导致 `TextEditingController` 的输入内容、动画进度、展开状态整体错位一格。
- **修复**：`.map((e) => _ItemTile(key: ValueKey(e.id), data: e))`。
- **追问**：为什么用 `UniqueKey()` 反而更糟？（答：每次 rebuild 都生成新 key → `canUpdate` 永远 false → Element 全部重建，性能和状态双输）

---

## 12. 业务架构与团队协作

> 这一章考察"能不能扛事"，回答质量靠追问。**如果候选人只谈技术不谈权衡，说明还没到高级。**

### 组件与分层设计

- **Q12.1** 你们项目怎么区分**通用基础组件**和**业务组件**？举一个实际例子，以及你划这条线的依据。
  - 考察点：能否说出判断依据——是否依赖业务模型/接口、是否含业务文案、是否只在一个业务域内复用；反例是"把所有东西都塞进 common 目录"。
- **Q12.2** 组件库怎么做版本迭代和**向下兼容**？破坏性变更怎么推动落地？
  - 考察点：`@Deprecated` 标注 + 保留窗口、新增可选参数而不是改必填、语义化版本、迁移指南、用 lint 发现旧用法并给出 codemod/脚本批量替换。
- **Q12.3** 一个复杂业务模块（比如订单详情页）交给你，你的拆解过程是什么？
  - 考察点：先定数据流和状态归属 → 再切分 UI 区块 → 再定组件边界 → 最后考虑复用与测试；而不是一上来就写页面。

### 方案与决策

- **Q12.4** 技术方案评审你会重点挑战什么？
  - 考察点：边界条件、异常路径、回滚方案、可观测性（埋点/日志/监控）、性能与包体积影响、对现有代码的侵入度、上线节奏。
- **Q12.5** 产品给的交互方案在 Flutter 上实现成本极高（比如复杂转场/自定义手势），你怎么沟通？
  - 考察点：不打太极。能给出"分阶段实现 / 降级替代 / 用原生实现 / 明确成本换排期"的具体选项，并量化成本。
- **Q12.6** 跨团队（原生团队 / 后端 / 设计）出现分歧时你怎么推进？
  - 考察点：有没有"用数据/可行性验证代替立场争论"的习惯。

### 技术债与团队

- **Q12.7** 历史技术债务很重，但业务排期很紧，你怎么推动重构？
  - 考察点：**"顺手重构 + 划定边界"** 的思路——新需求必经之处先重构、把重构拆成可独立上线的小步、用指标（崩溃率/卡顿率/需求交付周期）证明收益，而不是要求一个专门的"重构排期"。
- **Q12.8** 你怎么衡量一次重构的收益？怎么说服老板投入？
- **Q12.9** 你会拦下什么样的 PR？你们的 Code Review 关注哪几类问题？
  - 考察点：分层是否被破坏、状态归属是否合理、有没有内存泄漏与 dispose、异常与边界、可测试性、而不是只挑命名和格式。
- **Q12.10** 团队里工程师水平参差，你怎么提升整体质量？
  - 考察点：用工具（lint/模板/脚手架/CI 卡点）和规范降低下限，而不是靠反复口头提醒。

---

## 13. 线上故障与工程实战

> 这一章**问的是"你真实经历过的"**，不是"你会怎么做"。候选人讲不出具体案例，说明没经历过或没参与过决策。
> 每个问题都按「现象 → 排查过程 → 根因 → 处置 → 后续预防」五段听。

- **Q13.1** 讲一次线上发布后才发现的问题。你怎么确认范围、怎么回滚或热修、事后怎么补齐监控？
- **Q13.2** 你做过最大规模的一次代码迁移是什么？风险评估和灰度策略是怎么定的？
  - 考察点：是否分批次、是否双跑对比、是否有回滚开关（Feature Flag）、迁移中怎么保证新老代码共存不出错。
- **Q13.3** Flutter 大版本升级过程中你踩过什么坑？（结合 Q9.10 追问细节）
- **Q13.4** pub 依赖冲突你是怎么排查解决的？用了 `dependency_overrides` 之后遇到过什么后续问题？
- **Q13.5** 多渠道/多 flavor 产物异常（某渠道白屏、上报缺失、包内容错）你怎么定位？
- **Q13.6** iOS 符号解析失败 / dSYM 缺失你怎么处理？Dart 侧无行号的堆栈怎么还原？
- **Q13.7** 线上的内存泄漏你们怎么发现的？定位过程是什么样的？
  - 考察点：是否有内存监控（Jetsam / OOM 率 / `devtools` memory）、能否区分"Flutter 侧泄漏"还是"平台侧泄漏"、有没有用过 allocation tracking。
- **Q13.8** 卡死 / ANR 类问题怎么排查？Flutter 侧有哪些常见诱因？
  - 考察点：主线程被同步耗时操作阻塞、平台通道死锁、Isolate 通信阻塞、大图解码。
- **Q13.9** 一个只有部分机型/部分用户出现的崩溃，你怎么定位？
  - 考察点：能否按机型/OS 版本/ABI/网络环境切片、能否想到用配置或开关做二分定位。
- **Q13.10** 灰度期间核心指标恶化（崩溃率/卡顿率上升），你的处置流程是什么？

---

## 14. 反面信号（Red Flags）

出现以下回答，无论其他部分答得多好，都建议谨慎：

| 信号 | 具体表现 |
| --- | --- |
| 只背 API 不讲原理 | 能说出 `RepaintBoundary` 能优化，但说不清它创建了独立 layer、以及什么时候反而更慢 |
| 源码背题选手 | 底层概念滚瓜烂熟，但项目深挖环节拿不出真实优化数据、真实踩坑案例 |
| 优化靠直觉 | 说"我感觉这样更快"，拿不出 DevTools / Timeline / 数据 |
| 单线程误解 | 认为 Flutter 只有一个线程；认为 `await` 会开新线程；认为 `setState` 是异步的 |
| 架构教条 | 无脑推崇某个状态管理库，说不出它的代价和适用边界 |
| 没有质量意识 | "我们从不写测试""崩溃率不知道""没接过监控" |
| 不会排查 | 遇到卡顿/崩溃的第一反应是"换写法试试"，没有假设—验证的闭环 |
| 归因错误 | 把 layout 问题说成 build 问题，把 Raster 卡顿说成 setState 太频繁 |
| 不看边界 | 问优化只讲 happy path，不提内存、包体积、低端机、无障碍 |
| 只谈技术不谈权衡 | 方案题给不出代价、回滚、灰度、排期视角 |

> ⚠️ **注意区分"知识盲区"和"思维缺陷"**：不知道 `Impeller` 的某个细节是知识盲区，可以补；但"从不写测试""不做数据验证"是思维缺陷，很难改。

---

## 附录 A：评分维度表

| 维度 | 权重 | 及格线（中级） | 优秀（高级） |
| --- | --- | --- | --- |
| Dart 语言 | 10% | 熟悉语法糖与异步基础 | 理解 AOT/JIT 差异、`const` 规范化、扩展方法静态派发 |
| 三棵树 / 框架机制 | 20% | 知道 Widget/Element/RenderObject 分工 | 能讲清 `canUpdate`、InheritedWidget 的 O(1) 查表与依赖登记/通知链路 |
| 布局渲染管线 | 15% | 知道 layout→paint | 能说清 relayout/repaint boundary、layer 生成条件、离屏合成的代价 |
| 性能优化 | 20% | 会用 DevTools 看帧率 | 能分层定位（UI vs Raster）、量化收益、知道优化的反面代价 |
| 架构与状态管理 | 10% | 用过某个库 | 能按状态作用域/变化频率/可测试性做选型，说得清代价 |
| 工程化与质量 | 10% | 会写单测 | 有 CI/CD、崩溃监控、灰度、包体积治理、版本升级迁移的完整实践 |
| 业务架构与协作 | 10% | 能拆解模块 | 有组件库/分层设计经验，能推动技术债治理，讲得清权衡 |
| 线上实战 | 5% | 参与过问题排查 | 主导过故障定位与处置，有"现象→根因→预防"的完整闭环 |

### 判定规则

1. **总分 ≥ 70%** 且 **「三棵树 / 框架机制」与「性能优化」两项不低于及格** → 通过。
2. **项目深挖（第 0 章）如果答得虚，总分封顶 60%**，不论技术题答得多好。
3. **不以私有字段名作为评分项。** 只要机制、链路、利弊讲清楚，用词可以不同。
4. 出现 **≥ 3 条 Red Flags** 时，需要额外的交叉验证（追加第 11 章实操题），谨慎通过。

---

## 附录 B：几条"追问链"示例

> 用法：先问第一层，候选人答得顺就继续往下追。**追到第三层还能答上来，基本可以判定为高级。**

### 链 1：从 `setState` 一路追到 layer

1. `setState` 做了什么？
2. `markNeedsBuild` 之后，框架在哪一帧、哪个阶段处理这些脏 Element？脏列表的遍历顺序有什么讲究？
3. 只 rebuild 了这一个 widget，为什么有时候整个页面都跟着 layout 了？`RelayoutBoundary` 在哪儿起的作用？
4. 如果 layout 没变但 paint 变了，框架怎么知道只需要重绘这一块？
5. 什么情况下 paint 会升级成"重新生成 layer"？离屏合成的代价是什么？
6. 那 `Opacity` 和 `AnimatedOpacity` 你分别什么时候用？

### 链 2：从 InheritedWidget 一路追到精确刷新

1. `InheritedWidget` 怎么把数据传下去？为什么不直接用全局变量？
2. `dependOnInheritedWidgetOfExactType` 做了什么？为什么是 O(1)？
3. 祖先换了个新 widget 实例，但 `updateShouldNotify` 返回 false，会发生什么？
4. 一个页面里有 10 个 widget 都依赖了它，能不能只刷新其中 3 个？怎么做？
5. `aspect` 参数在 `InheritedModel` 里具体怎么起作用的？订阅者的"订阅信息"存在哪？
6. `InheritedNotifier` 和 `ListenableBuilder` 有什么区别？前者存在的意义是什么？

### 链 3：从卡顿一路追到线程

1. 用户说滑动卡，你怎么确认是掉帧而不是网络慢？
2. DevTools 里 UI 线程和 Raster 线程的时间线怎么看？分别对应代码里的什么？
3. UI 线程超时的常见原因有哪些？Raster 超时呢？
4. 如果是图片解码导致的卡顿，解码发生在哪个线程？
5. 怎么把解码也挪走？挪走之后为什么还可能卡？
6. 如果必须做 CPU 密集计算，`compute` 的代价是什么？什么情况下不该用 `compute`？

### 链 4：从状态管理一路追到可测试性

1. 你们的用户登录态放在哪儿？为什么？
2. 它每个页面都会用，用 `InheritedWidget` 会不会导致全量重建？
3. 换成 `Provider` 之后，怎么保证只有用到 `userName` 的 widget 重建？
4. 这个逻辑怎么写单测？需要 mock 网络层吗？
5. 如果登录态要持久化，恢复时机放在哪儿？在 `main` 里 `await` 会阻塞首帧吗？

### 链 5：从"用了 GetX"一路追到可维护性（新增）

1. 你们为什么选 GetX？当时的约束是什么？
2. 项目大了之后，`Get.find` 的调用关系还能追踪吗？出问题怎么定位是谁注册的？
3. 单测怎么写？两个测试之间怎么隔离状态？
4. 页面销毁时那些 `Get.put` 的对象谁来释放？
5. 如果现在要加一个新模块，你还会用 GetX 吗？为什么？

---

## 附录 C：按岗位画像组卷

> 直接可用的三套卷子。**所有卷子都必须留 ≥ 5 分钟给候选人反问。**

### 卷 A · 纯 Flutter 业务开发（60 min）

| 时段 | 内容 |
| --- | --- |
| 0–12 min | 第 0 章 Q0.1–Q0.4 |
| 12–25 min | Q2.2、Q2.7、Q2.8 + 附录 B 链 2（前 3 层） |
| 25–40 min | Q4.1、Q4.3、Q4.9 + **Q11.2、Q11.5 实操** |
| 40–50 min | Q5.1、Q5.2、Q10.4 |
| 50–60 min | Q12.7 + 候选人反问 |

### 卷 B · 基础架构 / 性能方向（75 min）

| 时段 | 内容 |
| --- | --- |
| 0–12 min | 第 0 章 Q0.1–Q0.5 |
| 12–30 min | Q3.4、Q3.5、Q3.6、Q3.9 + 附录 B 链 1（追满） |
| 30–48 min | Q4.2、Q4.5、Q4.6、Q4.7 + 附录 B 链 3（追满） |
| 48–60 min | **Q11.2、Q11.3、Q11.4** |
| 60–70 min | Q6.5、Q6.6 + Q9.14 |
| 70–75 min | Q12.4 + 候选人反问 |

### 卷 C · Tech Lead / 架构负责人（90 min）

| 时段 | 内容 |
| --- | --- |
| 0–15 min | 第 0 章全部 + 追问团队构成与决策权 |
| 15–30 min | Q5.10、Q5.12 + 附录 B 链 5 |
| 30–45 min | Q12.1、Q12.2、Q12.7、Q12.9 |
| 45–60 min | Q13.1、Q13.2、Q13.4 + Q9.10 |
| 60–75 min | Q10.5、Q10.8 + **Q11.1 实操** |
| 75–90 min | 追问技术判断力：如果他来带这个团队，前三个月做什么？+ 候选人反问 |
