# 第7节：分帧渲染优化

设想一个页面中有4个需要显示的widget,他们每个渲染需要10ms,一页渲染完成就需要40ms,超出了一帧的时间16.7ms,就产生了卡帧现象。

但是如果把这4个widget 分别放到第1帧、第2帧、第3帧、第4帧中去渲染，每一个widget只占用10ms,小于16.7ms，卡帧现象就这么消除了。这让我想起了分期买房，果然在哪里套路都一样...

![分帧渲染示意图](./assets/frame_seprate.webp)

这个可以说是最简单高效的优化方法了，还有一个实现库keframe

使用这个库只需要将想要分帧渲染的widget用FrameSeparateWidget包裹起来就好了，当然如果被包裹的widget的尺寸会自适应自身内容的大小，而不是用入参width和height写死，或者由父widget限定死的，那么主要填写一个固定大小的placeHolder以防止widget显示跳变

参考:https://www.jianshu.com/p/4a36cce7b76d
