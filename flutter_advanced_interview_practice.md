# Flutter 高级工程师练习题（20题）

1. 解释 Flutter 渲染管线（Widget→Element→RenderObject），并举例说明重建与重绘的差异和触发条件。
2. 比较 StatefulWidget 与 State 的生命周期（initState、didChangeDependencies、didUpdateWidget、dispose）在实际场景中的使用与陷阱。
3. 阐述 Key、GlobalKey 的作用与代价；设计一个场景展示使用不当导致的状态错位，并给出修复方案。
4. 说明 InheritedWidget、Provider、Riverpod、BLoC 在大型项目中的适用场景；给出迁移策略。
5. 设计一个高性能无限滚动列表，要求：分页、占位骨架、错误重试、避免不必要重建。
6. 编写一个自定义 Sliver（如 SliverStickyHeader），实现吸顶效果并支持动态高度。
7. 实现一个基于 Isolate 的图片缩放/滤镜管道，分析主线程与后台通信的方案与成本。
8. 解释 Dart 的事件循环、microtask 与 timer 的差异；给出导致 UI 卡顿的异步误用示例并修正。
9. 描述 Flutter 性能优化手段：RepaintBoundary、const 构造、缓存、Layout/paint 的代价；制定压 16ms 帧预算的策略。
10. 针对复杂表单页面，设计状态管理与验证方案，支持撤销/重做、草稿保存与离线同步。
11. 编写一个自定义 RenderObject，用以精确控制布局与绘制（如圆形布局），并说明何时优先选择它。
12. 说明 Navigator 2.0（Router API）与深链（deep link）实现要点，处理浏览器刷新和多平台一致性。
13. 设计网络层：拦截器、重试/退避、取消请求、Token 续期与安全存储；处理 401 的并发风暴。
14. 讲解 Flutter Web 的两种渲染器（HTML vs CanvasKit）差异与选择；分析常见兼容问题与解决方案。
15. 为关键页面编写 Golden Test 与 Widget Test，隔离外部依赖并提升可维护性。
16. 构建插件（Platform Channel/Federated Plugin）：同时支持 iOS/Android/Web，处理线程切换与平台权限。
17. 使用 build_runner + json_serializable/freezed 进行模型与不可变状态的代码生成，避免手写样板。
18. 设计模块化/特性包（feature packages）架构，明确共享层、域层、UI 层的边界与依赖方向。
19. 制定错误采集与观测策略：FlutterError.onError、Zone、Crashlytics/Sentry，做用户级别归因与采样。
20. 分析内存与资源管理：图片解码、缓存策略、ImageCache 调优、避免泄漏（如动画控制器/Stream 订阅）。
