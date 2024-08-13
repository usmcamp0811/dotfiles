import Vue from 'vue'
import VueRouter from 'vue-router'
import VueMatomo from 'vue-matomo'
import routes from './routes'

Vue.use(VueRouter)

// Configure VueMatomo
Vue.use(VueMatomo, {
  // Configure your matomo server and site by providing
  host: 'https://matomo.aicampground.com/',
  siteId: 1,

  // Enable router integration
  router: Router,

  // Enable link tracking (optional)
  enableLinkTracking: true,

  // Other optional options
  requireConsent: false, // if you require users to consent to tracking
  trackInitialView: true, // tracks the initial view
  disableCookies: false,  // disable cookies

  // Custom tracking methods if needed
  trackerFileName: 'matomo', // If you renamed the matomo.js file, adjust this setting
  enableHeartBeatTimer: true, // recommended: activates the heartbeat of the tracker
  heartBeatTimerInterval: 15 // in seconds
})

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

  return Router
}
