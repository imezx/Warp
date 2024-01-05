import { defineConfig } from 'vitepress'

function nav() {
  return [
    {
      text: 'Guide',
      link: '/guide/',
    },
    {
      text: 'API Reference',
      items: [
        { text: '1.0', link: '/api/1.0/warp' }
      ]
    }
  ]
}

function side() {
  return {
    '/api/1.0': [
      {
        text: 'API Reference',
        items: [
          { text: 'Warp', link: '/api/1.0/warp' },
          { text: 'Server', link: '/api/1.0/server' },
          { text: 'Client', link: '/api/1.0/client' },
          { text: 'RateLimit', link: '/api/1.0/ratelimit' },
        ]
      }
    ],
    '/guide/': [
      {
        text: 'Guide',
        items: [
          { text: 'Overview', link: '/guide/' },
          { text: 'Installation', link: '/guide/installation' },
          { text: 'Getting Started', link: '/guide/getting-started' },
          { text: 'Example', link: '/guide/example' },
        ]
      },
    ]
  }
}

export default defineConfig({
  title: "Warp",
  description: "Warp - A very-fast & powerful network library for Roblox.",
  lang: 'en-US',
  head: [
    ['link', { rel: 'icon', href: 'favicon.ico' }],
  ],
  base: "/Warp",
  assetsDir: '/assets',
  cleanUrls: true,
  themeConfig: {
    logo: '/icon.ico',
    nav: nav(),
    sidebar: side(),
    socialLinks: [
      { icon: 'github', link: 'https://github.com/imezx/Warp' },
      { icon: 'discord', link: 'https://discord.gg/qnSfEZ6bZK' },
    ]
  }
})