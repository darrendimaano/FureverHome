<script setup lang="ts">
import { computed } from "vue";
import { useRoute } from "vue-router";
import { IonContent, IonPage } from "@ionic/vue";
import SiteHeader from "@/components/SiteHeader.vue";
import SiteFooter from "@/components/SiteFooter.vue";

const route = useRoute();
const title = computed(() => String(route.meta.title || "Information"));
</script>

<template>
  <ion-page>
    <site-header />
    <ion-content id="main-content">
      <div class="container info">
        <div class="eyebrow">FurEver Home</div>
        <h1 class="section-title">{{ title }}</h1>
        <div class="surface copy">
          <template v-if="route.name === 'faq'">
            <h2>Why is a physical assessment required?</h2>
            <p>It helps authorized staff understand readiness, household fit, and care expectations before an application proceeds.</p>
            <h2>Does a completed assessment guarantee adoption?</h2>
            <p>No. Staff must record an eligible outcome, and the final application still requires review and approval.</p>
            <h2>Are behavior videos medical proof?</h2>
            <p>No. Videos document observed behavior only and never replace veterinary assessment.</p>
          </template>
          <template v-else>
            <h2>Your privacy matters</h2>
            <p>Private profiles, appointments, assessment notes, documents, and donation details are limited to the account owner and authorized staff. Database row-level security policies enforce this once Supabase is configured.</p>
            <p>Sensitive information is protected by authenticated access and database row-level security.</p>
          </template>
        </div>
      </div>
      <site-footer />
    </ion-content>
  </ion-page>
</template>

<style scoped>
.info {
  min-height: 650px;
  padding-block: 70px;
}

.copy {
  max-width: 800px;
  padding: 34px;
}

.copy h2 {
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
}

.copy p {
  color: var(--ink-muted);
  line-height: 1.75;
}
</style>
