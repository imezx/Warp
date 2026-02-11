import DefaultTheme from 'vitepress/theme'
import { h } from 'vue'
import Typewriter from './components/Typewriter.vue'
import './style.css'

export default {
  extends: DefaultTheme,
  Layout() {
    return h(DefaultTheme.Layout, null, {
      'home-hero-info': () => h(Typewriter, {
        staticTitle: 'Warp'
      })
    })
  }
}