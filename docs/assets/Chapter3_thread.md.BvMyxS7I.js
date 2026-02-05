import{_ as a,o as n,c as p,ag as e}from"./chunks/framework.FundgpKU.js";const h=JSON.parse('{"title":"第1节：线程模型","description":"","frontmatter":{},"headers":[],"relativePath":"Chapter3/thread.md","filePath":"Chapter3/thread.md","lastUpdated":1704190556000}'),l={name:"Chapter3/thread.md"};function t(i,s,r,c,o,d){return n(),p("div",null,[...s[0]||(s[0]=[e(`<h1 id="第1节-线程模型" tabindex="-1">第1节：线程模型 <a class="header-anchor" href="#第1节-线程模型" aria-label="Permalink to &quot;第1节：线程模型&quot;">​</a></h1><h3 id="如何处理耗时的操作-不同语言有不同的处理方式" tabindex="-1">如何处理耗时的操作? 不同语言有不同的处理方式 <a class="header-anchor" href="#如何处理耗时的操作-不同语言有不同的处理方式" aria-label="Permalink to &quot;如何处理耗时的操作? 不同语言有不同的处理方式&quot;">​</a></h3><ul><li><p>多线程。比如 Java、C++，就是开启一个新的线程，将耗时操作放在新的线程里面处理，再通过线程间通信的方式，将拿到的数据传给主线程处理。</p></li><li><p>单线程+事件循环。比如 JavaScript、Dart 都是主要基于单线程加事件循环来完成耗时操作的处理</p></li><li><p>dart的多线程对应多isolate(isolate的显示调用和隐式调用)</p></li></ul><h5 id="隐式调用" tabindex="-1">隐式调用 <a class="header-anchor" href="#隐式调用" aria-label="Permalink to &quot;隐式调用&quot;">​</a></h5><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>int expensiveOperation(int value) {</span></span>
<span class="line"><span>  // 执行一些计算密集型的任务</span></span>
<span class="line"><span>  return value * value;</span></span>
<span class="line"><span>}</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Future&lt;void&gt; main() async {</span></span>
<span class="line"><span>  // 在后台Isolate中执行expensiveOperation函数</span></span>
<span class="line"><span>  int result = await compute(expensiveOperation, 10);</span></span>
<span class="line"><span></span></span>
<span class="line"><span>  // 处理结果</span></span>
<span class="line"><span>  print(&#39;Result: $result&#39;);</span></span>
<span class="line"><span>}</span></span></code></pre></div><h5 id="显式调用" tabindex="-1">显式调用 <a class="header-anchor" href="#显式调用" aria-label="Permalink to &quot;显式调用&quot;">​</a></h5><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>import &#39;dart:isolate&#39;;</span></span>
<span class="line"><span></span></span>
<span class="line"><span>void task1(SendPort sendPort) {</span></span>
<span class="line"><span>  // 在这里执行任务1</span></span>
<span class="line"><span>  int result = 0;</span></span>
<span class="line"><span>  for (int i = 0; i &lt; 5; i++) {</span></span>
<span class="line"><span>    result += i;</span></span>
<span class="line"><span>  }</span></span>
<span class="line"><span></span></span>
<span class="line"><span>  // 将结果发送回主Isolate</span></span>
<span class="line"><span>  sendPort.send(result);</span></span>
<span class="line"><span>}</span></span>
<span class="line"><span></span></span>
<span class="line"><span>void task2(SendPort sendPort) {</span></span>
<span class="line"><span>  // 在这里执行任务2</span></span>
<span class="line"><span>  int result = 0;</span></span>
<span class="line"><span>  for (int i = 0; i &lt; 10; i++) {</span></span>
<span class="line"><span>    result -= i;</span></span>
<span class="line"><span>  }</span></span>
<span class="line"><span></span></span>
<span class="line"><span>  // 将结果发送回主Isolate</span></span>
<span class="line"><span>  sendPort.send(result);</span></span>
<span class="line"><span>}</span></span>
<span class="line"><span></span></span>
<span class="line"><span>Future&lt;void&gt; main() async {</span></span>
<span class="line"><span>  ReceivePort receivePort1 = ReceivePort();</span></span>
<span class="line"><span>  ReceivePort receivePort2 = ReceivePort();</span></span>
<span class="line"><span></span></span>
<span class="line"><span>  // 创建 Isolate 并分别将任务1和任务2分配给它们</span></span>
<span class="line"><span>  Isolate isolate1 = await Isolate.spawn(task1, receivePort1.sendPort);</span></span>
<span class="line"><span>  Isolate isolate2 = await Isolate.spawn(task2, receivePort2.sendPort);</span></span>
<span class="line"><span></span></span>
<span class="line"><span>  // 等待 Isolate 返回结果</span></span>
<span class="line"><span>  int result1 = await receivePort1.first;</span></span>
<span class="line"><span>  int result2 = await receivePort2.first;</span></span>
<span class="line"><span></span></span>
<span class="line"><span>  print(&#39;Result from Isolate 1: $result1&#39;);//Result from Isolate 1: 10</span></span>
<span class="line"><span>  print(&#39;Result from Isolate 2: $result2&#39;);//Result from Isolate 2: -45</span></span>
<span class="line"><span></span></span>
<span class="line"><span>  // 关闭 Isolate</span></span>
<span class="line"><span>  isolate1.kill();</span></span>
<span class="line"><span>  isolate2.kill();</span></span>
<span class="line"><span>}</span></span></code></pre></div>`,7)])])}const v=a(l,[["render",t]]);export{h as __pageData,v as default};
