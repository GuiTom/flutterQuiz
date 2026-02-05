import{_ as s,o as e,c as t,ag as n}from"./chunks/framework.FundgpKU.js";const u=JSON.parse('{"title":"","description":"","frontmatter":{},"headers":[],"relativePath":"Chapter4/hittest_behavior.md","filePath":"Chapter4/hittest_behavior.md","lastUpdated":1710469901000}'),p={name:"Chapter4/hittest_behavior.md"};function i(l,a,r,h,o,c){return e(),t("div",null,[...a[0]||(a[0]=[n(`<h4 id="histtestbehavor有三个属性" tabindex="-1">histTestBehavor有三个属性： <a class="header-anchor" href="#histtestbehavor有三个属性" aria-label="Permalink to &quot;histTestBehavor有三个属性：&quot;">​</a></h4><ol><li>behavior 为 deferToChild 时，hitTestSelf 返回 false，当前组件是否能通过命中测试完全取决于 hitTestChildren 的返回值。也就是说只要有一个子节点通过命中测试，则当前组件便会通过命中测试。</li><li>behavior 为 opaque 时，hitTestSelf 返回 true，hitTarget 值始终为 true，当前组件通过命中测试。</li><li>behavior 为 translucent 时，hitTestSelf 返回 false，hitTarget 值此时取决于 hitTestChildren 的返回值，但是无论 hitTarget 值是什么，当前节点都会被添加到 HitTestResult 中。</li></ol><p>注意，behavior 为 opaque 和 translucent 时当前组件都会通过命中测试，它们的区别是 hitTest() 的返回值（hitTarget ）可能不同，所以它们的区别就看 hitTest() 的返回值会影响什么，这个我们已经在上面详细介绍过了，下面我们通过一个实例来理解一下。</p><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>//在命中测试过程中 Listener 组件如何表现。</span></span>
<span class="line"><span>enum HitTestBehavior {</span></span>
<span class="line"><span>  // 组件是否通过命中测试取决于子组件是否通过命中测试</span></span>
<span class="line"><span>  deferToChild,</span></span>
<span class="line"><span>  // 组件必然会通过命中测试，同时其 hitTest 返回值始终为 true</span></span>
<span class="line"><span>  opaque,</span></span>
<span class="line"><span>  // 组件必然会通过命中测试，但其 hitTest 返回值可能为 true 也可能为 false</span></span>
<span class="line"><span>  translucent,</span></span>
<span class="line"><span>}</span></span></code></pre></div><h3 id="例子" tabindex="-1">例子 <a class="header-anchor" href="#例子" aria-label="Permalink to &quot;例子&quot;">​</a></h3><p>当给 <code>Container</code>设置颜色的时候，点击有响应。而去掉颜色，则点击无响应。若去掉颜色而加上behavior: HitTestBehavior.opaque,则点击也有相应。</p><div class="language- vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang"></span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>//无响应</span></span>
<span class="line"><span>GestureDetector(</span></span>
<span class="line"><span>                  onTap: () {</span></span>
<span class="line"><span>                    print(&quot;onTap&quot;);</span></span>
<span class="line"><span>                  },</span></span>
<span class="line"><span>                  child: Container(</span></span>
<span class="line"><span>                    //color: Colors.blue,打开</span></span>
<span class="line"><span>                    width: 40,</span></span>
<span class="line"><span>                    height: 40,</span></span>
<span class="line"><span>                  ),</span></span>
<span class="line"><span>                ),</span></span></code></pre></div><h3 id="参考" tabindex="-1">参考: <a class="header-anchor" href="#参考" aria-label="Permalink to &quot;参考:&quot;">​</a></h3><p>1.[Flutter : 关于 HitTestBehavior_flutter hittestbehavior-CSDN博客](<a href="https://blog.csdn.net/u013066292/article/details/1172840" target="_blank" rel="noreferrer">https://blog.csdn.net/u013066292/article/details/1172840</a></p><p>[85)</p><p>2.<a href="https://book.flutterchina.club/chapter8/hittest.html#_8-3-5-hittestbehavior" target="_blank" rel="noreferrer">8.3 Flutter事件机制 | 《Flutter实战·第二版》 (flutterchina.club)</a></p>`,11)])])}const b=s(p,[["render",i]]);export{u as __pageData,b as default};
