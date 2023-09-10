import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "Learn Zig",
  description: "简单、快速地学习Zig",
  themeConfig: {
    nav: [
      { text: '主页', link: '/' },
      { text: 'Examples', link: '/markdown-examples' }
    ],

    sidebar: [
      {
        text: 'Examples',
        items: [
          { text: 'Markdown Examples', link: '/markdown-examples' },
          { text: 'Runtime API Examples', link: '/api-examples' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/jinzhongjia/learnzig' }
    ]
  }
})
