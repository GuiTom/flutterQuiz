# 第2节：手势竞争

正常情况下应该是手势直接作用的对象应该来处理手势，所以一个简单的原则就是同一个手势应该只有一个手势识别器生效，为此，手势识别才映入了手势竞技场（Arena）的概念，简单来讲：

1. 每一个手势识别器（GestureRecognizer）都是一个“竞争者”（GestureArenaMember），当发生指针事件时，他们都要在“竞技场”去竞争本次事件的处理权，默认情况最终只有一个“竞争者”会胜出(win)。
2. GestureRecognizer 的 handleEvent 中会识别手势，如果手势发生了某个手势，竞争者可以宣布自己是否胜出，一旦有一个竞争者胜出，竞技场管理者（GestureArenaManager）就会通知其他竞争者失败。
3. 胜出者的 acceptGesture 会被调用，其余的 rejectGesture 将会被调用。

如果对一个组件同时监听水平和垂直方向的拖动手势，当我们斜着拖动时哪个方向的拖动手势回调会被触发？实际上取决于第一次移动时两个轴上的位移分量，哪个轴的大，哪个轴在本次滑动事件竞争中就胜出。上面已经说过，每一个手势识别器（`GestureRecognizer`）都是一个“竞争者”（`GestureArenaMember`），当发生指针事件时，他们都要在“竞技场”去竞争本次事件的处理权，默认情况最终只有一个“竞争者”会胜出(win)。例如，假设有一个`ListView`，它的第一个子组件也是`ListView`，如果现在滑动这个子`ListView`，父`ListView`会动吗？答案是否定的，这时只有子`ListView`会动，因为这时子`ListView`会胜出而获得滑动事件的处理权。

### 两个特殊的例子:
 EagerGestureRecognizer（急切胜出）：有些手势（如点击 Tap）可能在某些条件下立刻宣布胜出，而不给其他手势竞争的机会。

 手势透传：如果你希望父子组件同时动（例如：滑动子列表到底部后带动父列表），通常不能通过竞技场默认逻辑实现，而需要使用特殊的 RawGestureDetector 或者自定义手势识别器来手动管理 acceptGesture。
###### 见: https://github.com/GuiTom/flutterQuiz/blob/master/examples/lib/chapter_4/user_interaction_page.dart