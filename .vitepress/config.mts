import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
    title: "Flutter Quiz",
    description: "Flutter 底层原理认识和经验总结",
    lang: 'zh-CN',
    base: '/flutterQuiz/',
    outDir: './docs',
    themeConfig: {
        // https://vitepress.dev/reference/default-theme-config
        // nav: [
        //     { text: '首页', link: '/' },
        //     { text: '第一章 渲染流程', link: '/Chapter1/README' },
        //     { text: '第二章 性能优化', link: '/Chapter2/README' },
        //     { text: '第三章 线程/isolate/异步', link: '/Chapter3/README' },
        //     { text: '第四章 用户交互', link: '/Chapter4/README' },
        //     { text: '第五章 生僻语法', link: '/Chapter5/README' }
        // ],

        sidebar: [
            {
                text: '前言',
                link: '/'
            },
            {
                text: '第一章 渲染流程',
                collapsed: false,
                items: [
                    { text: '章节介绍', link: '/Chapter1/README' },
                    { text: '第1节：三棵树', link: '/Chapter1/tree' },
                    { text: '第2节：渲染流程', link: '/Chapter1/pipeline' },
                    { text: '第3节：key与复用', link: '/Chapter1/key' }
                ]
            },
            {
                text: '第二章 性能优化',
                collapsed: false,
                items: [
                    { text: '章节介绍', link: '/Chapter2/README' },
                    { text: '第1节：widget重建优化', link: '/Chapter2/widet_build' },
                    { text: '第2节：布局优化', link: '/Chapter2/layout' },
                    { text: '第3节：离屏渲染优化', link: '/Chapter2/offscreen' },
                    { text: '第4节：图片优化', link: '/Chapter2/image' },
                    { text: '第5节：绘制边界优化', link: '/Chapter2/repaintBoundary' },
                    { text: '第6节：分帧渲染优化', link: '/Chapter2/frame_seprate' }
                ]
            },
            {
                text: '第三章 线程/isolate/异步',
                collapsed: false,
                items: [
                    { text: '章节介绍', link: '/Chapter3/README' },
                    { text: '第1节：线程模型', link: '/Chapter3/thread' },
                    { text: '第2节：异步', link: '/Chapter3/async' }
                ]
            },
            {
                text: '第四章 用户交互时间处理机制',
                collapsed: false,
                items: [
                    { text: '章节介绍', link: '/Chapter4/README' },
                    { text: '第1节：命中测试', link: '/Chapter4/hit_test' },
                    { text: '第2节：命中测试行为', link: '/Chapter4/hittest_behavior' },
                    { text: '第3节：手势竞争', link: '/Chapter4/gensture_arena' }
                ]
            },
            {
                text: '第五章 生僻语法',
                collapsed: false,
                items: [
                    { text: '章节介绍', link: '/Chapter5/README' },
                    { text: '第1节：yield', link: '/Chapter5/yield' }
                ]
            }
        ],

        socialLinks: [
            { icon: 'github', link: 'https://github.com/GuiTom/flutterQuiz' }
        ],

        search: {
            provider: 'local',
            options: {
                locales: {
                    root: {
                        translations: {
                            button: {
                                buttonText: '搜索文档',
                                buttonAriaLabel: '搜索文档'
                            },
                            modal: {
                                noResultsText: '无法找到相关结果',
                                resetButtonTitle: '清除查询条件',
                                footer: {
                                    selectText: '选择',
                                    navigateText: '切换'
                                }
                            }
                        }
                    }
                }
            }
        },

        outline: {
            label: '页面导航',
            level: [2, 3]
        },

        docFooter: {
            prev: '上一页',
            next: '下一页'
        },

        lastUpdated: {
            text: '最后更新于',
            formatOptions: {
                dateStyle: 'short',
                timeStyle: 'short'
            }
        },

        returnToTopLabel: '回到顶部',
        sidebarMenuLabel: '菜单',
        darkModeSwitchLabel: '主题',
        lightModeSwitchTitle: '切换到浅色模式',
        darkModeSwitchTitle: '切换到深色模式'
    }
})
