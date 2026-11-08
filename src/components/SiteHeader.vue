<script setup lang="ts">
import { computed, useId } from "vue";
import {
  IonBackButton,
  IonBadge,
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonItem,
  IonList,
  IonMenu,
  IonMenuButton,
  IonMenuToggle,
  IonPopover,
  IonToolbar,
} from "@ionic/vue";
import {
  calendarClearOutline,
  cashOutline,
  chevronDownOutline,
  documentTextOutline,
  heart,
  heartOutline,
  homeOutline,
  logOutOutline,
  paw,
  pawOutline,
  personOutline,
  walletOutline,
  notificationsOutline,
  speedometerOutline,
} from "ionicons/icons";
import { useRoute, useRouter } from "vue-router";
import { useAppState } from "@/composables/useAppState";

const router = useRouter();
const route = useRoute();
const { state, logout } = useAppState();
const desktopMenuTriggerId = useId();
const unreadNotificationCount = computed(
  () => state.notifications.filter((item) => !item.read).length,
);
const showBack = computed(() => route.path !== "/");
const defaultBackHref = computed(() => {
  if (route.path.startsWith("/pets/")) return "/pets";
  if (route.path.startsWith("/fundraising/")) return "/fundraising";
  if (
    route.path.startsWith("/favorites") ||
    route.path.startsWith("/appointments") ||
    route.path.startsWith("/applications") ||
    route.path.startsWith("/progress") ||
    route.path.startsWith("/donations") ||
    route.path.startsWith("/profile") ||
    route.path.startsWith("/notifications")
  ) {
    return "/dashboard";
  }
  return "/";
});

const signOut = async () => {
  await logout();
  router.push("/");
};

const menuItems = [
  [homeOutline, "Home", "/"],
  [pawOutline, "Find a pet", "/pets"],
  [cashOutline, "Fundraising", "/fundraising"],
  [speedometerOutline, "My dashboard", "/dashboard"],
  [heartOutline, "Favorites", "/favorites"],
  [calendarClearOutline, "Appointments", "/appointments"],
  [documentTextOutline, "Adoption progress", "/progress"],
  [documentTextOutline, "Applications", "/applications"],
  [walletOutline, "Donation history", "/donations"],
  [personOutline, "Profile", "/profile"],
  [notificationsOutline, "Notifications", "/notifications"],
] as const;
</script>

<template>
  <ion-menu content-id="main-content">
    <div class="menu-brand"><ion-icon :icon="paw" /> FurEver Home</div>
    <ion-menu-toggle v-for="item in [
      ['Home', '/'],
      ['Find a pet', '/pets'],
      ['Fundraising', '/fundraising'],
      ['My dashboard', '/dashboard'],
      ['Favorites', '/favorites'],
      ['Appointments', '/appointments'],
      ['Adoption progress', '/progress'],
    ]" :key="item[1]">
      <ion-button fill="clear" expand="block" :router-link="item[1]">{{ item[0] }}</ion-button>
    </ion-menu-toggle>
  </ion-menu>

  <ion-header class="site-header">
    <ion-toolbar>
      <div class="header-inner">
        <div class="header-left">
          <ion-back-button
            v-if="showBack"
            :default-href="defaultBackHref"
            text="Back"
            aria-label="Go back"
          />
        <span class="brand" @click="$router.push('/')">
          <span class="brand-mark"><ion-icon :icon="paw" /></span>
          <span>FurEver <b>Home</b></span>
        </span>
          <ion-button :id="desktopMenuTriggerId" class="desktop-menu" fill="clear">
            Explore
            <ion-icon slot="end" :icon="chevronDownOutline" />
          </ion-button>
          <ion-popover class="explore-popover" :trigger="desktopMenuTriggerId" trigger-action="click" :dismiss-on-select="true">
            <ion-content class="explore-menu-content">
              <div class="explore-menu-heading">
                <span class="explore-menu-mark"><ion-icon :icon="paw" /></span>
                <span><small>FurEver Home</small><strong>Explore</strong></span>
              </div>
              <ion-list class="explore-menu-list" lines="none">
                <ion-item
                  v-for="item in menuItems"
                  :key="item[2]"
                  button
                  :router-link="item[2]"
                  :class="{ active: route.path === item[2] || (item[2] !== '/' && route.path.startsWith(`${item[2]}/`)) }"
                >
                  <ion-icon slot="start" :icon="item[0]" />
                  <ion-label>{{ item[1] }}</ion-label>
                </ion-item>
              </ion-list>
            </ion-content>
          </ion-popover>
          <ion-menu-button class="mobile-only" aria-label="Open navigation menu" />
        </div>
        <ion-buttons class="header-actions">
          <ion-button v-if="state.role !== 'guest'" fill="clear" router-link="/notifications" aria-label="Notifications">
            <ion-icon slot="icon-only" :icon="notificationsOutline" />
            <ion-badge v-if="unreadNotificationCount" color="primary">{{ unreadNotificationCount }}</ion-badge>
          </ion-button>
          <ion-button v-if="state.role === 'guest'" fill="outline" router-link="/login">
            <ion-icon slot="start" :icon="personOutline" />
            Sign in
          </ion-button>
          <ion-button v-else fill="outline" @click="signOut">
            <ion-icon slot="start" :icon="logOutOutline" />
            Sign out
          </ion-button>
        </ion-buttons>
      </div>
    </ion-toolbar>
  </ion-header>
</template>

<style scoped>
.site-header {
  box-shadow: 0 1px 0 var(--border);
}

ion-toolbar {
  --background: rgba(255, 253, 249, 0.96);
  --padding-start: max(18px, calc((100vw - 1180px) / 2));
  --padding-end: max(18px, calc((100vw - 1180px) / 2));
  min-height: 80px;
}

.header-inner,
.header-left,
.header-actions {
  display: flex;
  align-items: center;
}

.header-inner {
  width: 100%;
  justify-content: space-between;
  gap: 20px;
  min-height: 80px;
}

.header-left {
  gap: 18px;
}

.brand {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  color: var(--ion-color-secondary);
  cursor: pointer;
  font-family: Georgia, serif;
  font-size: 1.28rem;
}

.brand b {
  color: var(--ion-color-primary);
}

.brand-mark {
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border-radius: 13px;
  background: var(--ion-color-primary);
  color: white;
}

.desktop-menu {
  margin-left: 8px;
  --color: var(--ion-color-secondary);
  --border-radius: 8px;
  font-weight: 700;
}

ion-popover.explore-popover {
  --width: 300px;
  --max-height: min(76vh, 620px);
  --backdrop-opacity: 0;
}

ion-popover.explore-popover::part(content) {
  overflow: hidden;
  border: 1px solid rgba(95, 63, 47, 0.14);
  border-radius: 12px;
  background: #fffdfa;
  box-shadow: 0 18px 48px rgba(47, 38, 34, 0.18);
}

.explore-menu-content {
  --background: #fffdfa;
}

.explore-menu-heading {
  display: flex;
  align-items: center;
  gap: 12px;
  border-bottom: 1px solid var(--border);
  padding: 16px 18px 14px;
}

.explore-menu-mark {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: 10px;
  background: var(--ion-color-primary);
  color: white;
  font-size: 1.1rem;
}

.explore-menu-heading > span:last-child {
  display: grid;
  gap: 2px;
}

.explore-menu-heading small {
  color: var(--ink-muted);
  font-size: 0.7rem;
}

.explore-menu-heading strong {
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.05rem;
}

.explore-menu-list {
  padding: 8px;
  background: transparent;
}

.explore-menu-list ion-item {
  --background: transparent;
  --border-color: transparent;
  --color: var(--ion-color-secondary);
  --padding-start: 12px;
  --inner-padding-end: 12px;
  --min-height: 42px;
  margin: 2px 0;
  border-radius: 8px;
  font-size: 0.92rem;
}

.explore-menu-list ion-item:hover {
  --background: #fff4ed;
}

.explore-menu-list ion-item.active {
  --background: #fff0e6;
  --color: var(--ion-color-primary);
  font-weight: 700;
}

.explore-menu-list ion-icon {
  color: var(--ion-color-primary);
  font-size: 1.1rem;
}

.header-actions {
  flex-shrink: 0;
}

.mobile-only {
  display: none;
}

ion-badge {
  position: absolute;
  top: 5px;
  right: 2px;
  min-width: 17px;
  font-size: 0.65rem;
}

.menu-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 32px 22px 18px;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.35rem;
  font-weight: 700;
}

@media (max-width: 880px) {
  .desktop-menu {
    display: none;
  }

  .mobile-only {
    display: flex;
  }

  .header-left {
    gap: 10px;
  }

  .brand {
    font-size: 1.05rem;
  }

  .header-inner {
    gap: 8px;
  }

  .header-actions ion-button {
    font-size: 0.82rem;
  }
}
</style>
