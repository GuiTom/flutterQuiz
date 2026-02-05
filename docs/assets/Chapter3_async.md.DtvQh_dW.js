import{_ as s,o as n,c as e,ag as p}from"./chunks/framework.CbQjVMS6.js";const t="/assets/image-20231211155527350.CXf8x-vs.png",m=JSON.parse('{"title":"第2节：异步","description":"","frontmatter":{},"headers":[],"relativePath":"Chapter3/async.md","filePath":"Chapter3/async.md","lastUpdated":1770253889000}'),l={name:"Chapter3/async.md"};function c(i,a,o,r,d,u){return n(),e("div",null,[...a[0]||(a[0]=[p('<h1 id="第2节-异步" tabindex="-1">第2节：异步 <a class="header-anchor" href="#第2节-异步" aria-label="Permalink to &quot;第2节：异步&quot;">​</a></h1><h3 id="单线程的异步操作" tabindex="-1">单线程的异步操作 <a class="header-anchor" href="#单线程的异步操作" aria-label="Permalink to &quot;单线程的异步操作&quot;">​</a></h3><p>应用程序大部分时间是处于空闲状态的，并不是一直在和用户进行交互。而我们的操作系统存在<code>阻塞式调用</code>和<code>非阻塞式调用</code>。</p><ul><li>阻塞式调用：调用结果返回之前，当前线程会被挂起，调用线程只有在得到调用结果之后才会继续执行。</li><li>非阻塞式调用：调用执行之后，当前线程不会停止执行，只需要间隔一段时间来检查一下有没有结果返回即可。</li></ul><p>Dart 的异步操作就是利用非阻塞式调用实现的。</p><h3 id="什么是事件循环" tabindex="-1">什么是事件循环 <a class="header-anchor" href="#什么是事件循环" aria-label="Permalink to &quot;什么是事件循环&quot;">​</a></h3><p>和 iOS 应用很像，在 Dart 的线程中也存在事件循环和消息队列的概念，但在 Dart 中线程叫做<code>isolate</code>。应用程序启动后，开始执行 main 函数并运行 <code>main isolate</code>。</p><p>每个 isolate 包含一个事件循环以及两个事件队列，<code>event loop事件循环</code>，以及<code>event queue</code>和<code>microtask queue事件队列</code>，event 和 microtask 队列有点类似 iOS 的 source0 和source1。</p><ul><li>event queue：负责处理I/O事件、绘制事件、手势事件、接收其他 isolate 消息等外部事件。</li><li>microtask queue：可以自己向 isolate 内部添加事件，事件的优先级比 event queue高。</li></ul><img src="'+t+`" alt="image-20231211155527350" style="zoom:50%;"><h2 id="dart-中的异步" tabindex="-1">Dart 中的异步 <a class="header-anchor" href="#dart-中的异步" aria-label="Permalink to &quot;Dart 中的异步&quot;">​</a></h2><p>Dart中的异步操作主要使用<code>Future</code>以及<code>async</code>、<code>await</code>，async 和 await 是要一起使用的，这就是协程的一个语法糖。</p><ul><li>Future 延时操作的一个封装，可以将异步任务封装为<code>Future</code>对象，我们通常通过then()来处理返回的结果</li><li>async 用于标明函数是一个异步函数，其返回值类型是Future类型</li><li>await 用来等待耗时操作的返回结果，这个操作会阻塞到后面的任务</li></ul><h3 id="什么是协程" tabindex="-1">什么是协程 <a class="header-anchor" href="#什么是协程" aria-label="Permalink to &quot;什么是协程&quot;">​</a></h3><p>协程分为<code>无线协程</code>和<code>有线协程</code>，无线协程在离开当前调用位置时，会将当前变量放在堆区，当再次回到当前位置时，还会继续从堆区中获取到变量。所以，一般在执行当前函数时就会将变量直接分配到堆区，而<code>async</code>、<code>await</code>就属于无线协程的一种。有线协程则会将变量继续保存在栈区，在回到指针指向的离开位置时，会继续从栈中取出调用。</p><h3 id="async、await原理" tabindex="-1">async、await原理 <a class="header-anchor" href="#async、await原理" aria-label="Permalink to &quot;async、await原理&quot;">​</a></h3><p>以 async、await为例，协程在执行时，执行到<code>async</code>则表示进入一个协程，会同步执行<code>async</code>的代码块。<code>async</code>的代码块本质上也相当于一个函数，并且有自己的上下文环境。当执行到<code>await</code>时，则表示有任务需要等待，CPU 则去调度执行其他 IO，也就是后面的代码或其他协程代码。过一段时间 CPU 就会轮循一次，看某个协程是否任务已经处理完成，有返回结果可以被继续执行，如果可以被继续执行的话，则会沿着上次离开时指针指向的位置继续执行，也就是<code>await</code>标志的位置。</p><p>由于并没有开启新的线程，只是进行 IO 中断改变 CPU 调度，所以网络请求这样的异步操作可以使用<code>async</code>、<code>await</code>，但如果是执行大量耗时同步操作的话，应该使用<code>isolate</code>开辟新的线程去执行。</p><p>例子:</p><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>Future&lt;void&gt; main() async {</span></span>
<span class="line"><span>  print(&#39;A&#39;);</span></span>
<span class="line"><span>  Future((){//event队列</span></span>
<span class="line"><span>    print(&#39;B&#39;);</span></span>
<span class="line"><span>    sleep(Duration(seconds: 1));</span></span>
<span class="line"><span>    print(&#39;D&#39;);</span></span>
<span class="line"><span>  }).then((value) {</span></span>
<span class="line"><span>    print(&#39;F&#39;);</span></span>
<span class="line"><span>  });</span></span>
<span class="line"><span>  Future((){//event 队列</span></span>
<span class="line"><span>    print(&#39;G&#39;);</span></span>
<span class="line"><span>    sleep(Duration(seconds: 1));</span></span>
<span class="line"><span>    print(&#39;H&#39;);</span></span>
<span class="line"><span>  });</span></span>
<span class="line"><span>  scheduleMicrotask(() {//micro toask 队列</span></span>
<span class="line"><span>    print(&#39;E&#39;);</span></span>
<span class="line"><span>  });</span></span>
<span class="line"><span>  print(&#39;C&#39;);</span></span>
<span class="line"><span>}</span></span></code></pre></div><p>输出:</p><p>A C E B D F G H</p><h3 id="completer" tabindex="-1">Completer <a class="header-anchor" href="#completer" aria-label="Permalink to &quot;Completer&quot;">​</a></h3><p>在Flutter中，Completer是一个非常有用的工具，用于处理异步操作。它允许你在某个异步操作完成时手动发出信号，并且可以通过Future对象等待该信号。</p><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>import &#39;dart:async&#39;;</span></span>
<span class="line"><span></span></span>
<span class="line"><span>void main() async{</span></span>
<span class="line"><span>  // 创建一个Completer</span></span>
<span class="line"><span></span></span>
<span class="line"><span></span></span>
<span class="line"><span>  // 模拟一个异步操作，比如网络请求</span></span>
<span class="line"><span>  Completer simulateNetworkRequest()  {</span></span>
<span class="line"><span>    Completer&lt;String&gt; completer = Completer();</span></span>
<span class="line"><span>    Future.delayed(Duration(seconds: 2),(){</span></span>
<span class="line"><span>      completer.complete(&#39;Operation completed successfully&#39;); // 异步操作完成，发出完成信号</span></span>
<span class="line"><span>    }); // 模拟一个2秒的延迟</span></span>
<span class="line"><span></span></span>
<span class="line"><span>    return completer;</span></span>
<span class="line"><span>  }</span></span>
<span class="line"><span>  print(&quot;这一行一开始就打印&quot;);</span></span>
<span class="line"><span>  // 启动异步操作</span></span>
<span class="line"><span> Completer completer = simulateNetworkRequest();</span></span>
<span class="line"><span>  print(&quot;这一行紧接着上一个print打印&quot;);</span></span>
<span class="line"><span>  // 等待异步操作完成</span></span>
<span class="line"><span>  await completer.future;</span></span>
<span class="line"><span>  print(&quot;这一行两秒后才打印&quot;);</span></span>
<span class="line"><span>}</span></span></code></pre></div>`,25)])])}const q=s(l,[["render",c]]);export{m as __pageData,q as default};
