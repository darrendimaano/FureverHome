import { createApp } from "vue"
import { IonicVue } from "@ionic/vue"
import App from "./App.vue"
import router from "./router"
import { loadCatalog } from "./services/catalog"

import "@ionic/vue/css/core.css"
import "@ionic/vue/css/normalize.css"
import "@ionic/vue/css/structure.css"
import "@ionic/vue/css/typography.css"
import "@ionic/vue/css/padding.css"
import "@ionic/vue/css/flex-utils.css"
import "./theme/variables.css"

const app = createApp(App).use(IonicVue).use(router)

router.isReady().then(async () => {
  await loadCatalog()
  app.mount("#app")
})

if (import.meta.env.PROD && "serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker
      .register(`${import.meta.env.BASE_URL}sw.js`)
      .catch((error: unknown) => {
        console.error("Service worker registration failed:", error)
      })
  })
}
