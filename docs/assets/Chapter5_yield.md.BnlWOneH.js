import{_ as n,o as s,c as p,ag as e}from"./chunks/framework.CbQjVMS6.js";const h=JSON.parse('{"title":"第2节：yield","description":"","frontmatter":{},"headers":[],"relativePath":"Chapter5/yield.md","filePath":"Chapter5/yield.md","lastUpdated":1702281941000}'),l={name:"Chapter5/yield.md"};function t(i,a,c,r,d,o){return s(),p("div",null,[...a[0]||(a[0]=[e(`<h1 id="第2节-yield" tabindex="-1">第2节：yield <a class="header-anchor" href="#第2节-yield" aria-label="Permalink to &quot;第2节：yield&quot;">​</a></h1><p>yield<code>语句只能用于生成器的函数。 生成器的功能以自然的方式生成数据项（如计算，从外部接收，预定义值等）。 当下一个数据项准备就绪时，</code>yield<code>语句将此项发送到数据序列，该数据序列本质上是函数的生成结果。 数据序列可以是同步的或异步的。 在Dart语言中，同步数据序列表示</code>Iterable<code>的实例。 异步数据序列表示</code>Stream\`的实例。</p><p>1.同步数据生成器: 返回一个 <a href="https://api.dart.dev/stable/dart-core/Iterable-class.html" target="_blank" rel="noreferrer"><code>Iterable</code></a> 对象.</p><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>Iterable&lt;int&gt; genIterates (int max) sync* {</span></span>
<span class="line"><span>  var i = 0;</span></span>
<span class="line"><span>  while (i &lt; max) {</span></span>
<span class="line"><span>    yield i;</span></span>
<span class="line"><span>    i++;</span></span>
<span class="line"><span>  }</span></span>
<span class="line"><span>}</span></span>
<span class="line"><span>Future&lt;void&gt; main() async {</span></span>
<span class="line"><span>  var l = genIterates(10);</span></span>
<span class="line"><span>  print(l);//输出: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9)</span></span>
<span class="line"><span>}</span></span></code></pre></div><p>2.异步数据生成器，返回一个Steam对象</p><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>Stream&lt;int&gt; runToMax (int n) async* {</span></span>
<span class="line"><span>  int i = 0;</span></span>
<span class="line"><span>  while (i &lt; n) {</span></span>
<span class="line"><span>    yield i;</span></span>
<span class="line"><span>    i++;</span></span>
<span class="line"><span>    await Future.delayed (Duration (seconds: 1));</span></span>
<span class="line"><span>  }</span></span>
<span class="line"><span>}</span></span>
<span class="line"><span>Future&lt;void&gt; main() async {</span></span>
<span class="line"><span>  Stream&lt;int&gt; stream = runToMax(5);</span></span>
<span class="line"><span>  await for (var n in stream) {</span></span>
<span class="line"><span>    print(n); //每隔一秒打印一个，共打印出 0 1 2 3 4</span></span>
<span class="line"><span>  }</span></span>
<span class="line"><span>}</span></span></code></pre></div><p>3.。yield<em>后面的表达式必须表示另一个子序列。yield</em>所做的是将子序列的所有元素插入到当前正在构造的序列中，就好像我们为每个元素都有一个单独的yield</p><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>Iterable&lt;int&gt; genIterates (int max) sync* {</span></span>
<span class="line"><span>  var i = 0;</span></span>
<span class="line"><span>  while (i &lt; max) {</span></span>
<span class="line"><span>    yield i;</span></span>
<span class="line"><span>    i++;</span></span>
<span class="line"><span>  }</span></span>
<span class="line"><span>}</span></span>
<span class="line"><span>Iterable&lt;int&gt; countDownFrom (int n) sync* {</span></span>
<span class="line"><span>  if (n &gt; 0) {</span></span>
<span class="line"><span>    yield n;</span></span>
<span class="line"><span>    yield* genIterates (n - 1);</span></span>
<span class="line"><span>  }</span></span>
<span class="line"><span>}</span></span>
<span class="line"><span>Future&lt;void&gt; main() async {</span></span>
<span class="line"><span>var l = countDownFrom(5);</span></span>
<span class="line"><span>	print(l);//打印：(5, 0, 1, 2, 3)</span></span>
<span class="line"><span>}</span></span></code></pre></div><p>参考链接:<a href="https://dart.dev/language/functions#generators" target="_blank" rel="noreferrer">https://dart.dev/language/functions#generators</a></p>`,9)])])}const u=n(l,[["render",t]]);export{h as __pageData,u as default};
