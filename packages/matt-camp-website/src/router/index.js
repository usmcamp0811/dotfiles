import Vue from 'vue'
import VueRouter from 'vue-router'
import VueMatomo from 'vue-matomo'
import routes from './routes'

Vue.use(VueRouter)

export default function (/* { store, ssrContext } */) {
  const Router = new VueRouter({
    scrollBehavior: () => ({ x: 0, y: 0 }),
    routes,

    // Leave these as is and change from quasar.conf.js instead!
    // quasar.conf.js -> build -> vueRouterMode
    // quasar.conf.js -> build -> publicPath
    mode: process.env.VUE_ROUTER_MODE,
    base: process.env.VUE_ROUTER_BASE
  })

  // Configure VueMatomo after Router is defined
  Vue.use(VueMatomo, {
    host: 'https://matomo.aicampground.com/',
    siteId: 1,
    router: Router,
    enableLinkTracking: true,
    requireConsent: false,
    trackInitialView: true,
    disableCookies: false,
    trackerFileName: 'matomo',
    enableHeartBeatTimer: true,
    heartBeatTimerInterval: 15
  })

  return Router
}
