<script setup lang="ts">
import { IonButton, IonIcon } from "@ionic/vue";
import { logoFacebook, logoInstagram, mailOutline, paw } from "ionicons/icons";
</script>

<template>
  <footer class="footer">
    <div class="container footer-grid">
      <div>
        <div class="footer-brand"><ion-icon :icon="paw" /> FurEver Home</div>
        <p>Thoughtful matches. Safer adoptions. Happier beginnings.</p>
        <div class="socials">
          <ion-button aria-label="Instagram" fill="clear" href="https://instagram.com">
            <ion-icon slot="icon-only" :icon="logoInstagram" />
          </ion-button>
          <ion-button aria-label="Facebook" fill="clear" href="https://facebook.com">
            <ion-icon slot="icon-only" :icon="logoFacebook" />
          </ion-button>
          <ion-button aria-label="Email" fill="clear" href="mailto:hello@fureverhome.org">
            <ion-icon slot="icon-only" :icon="mailOutline" />
          </ion-button>
        </div>
      </div>
      <div>
        <strong>Explore</strong>
        <ion-button fill="clear" router-link="/pets">Available pets</ion-button>
        <ion-button fill="clear" router-link="/fundraising">Support our mission</ion-button>
        <ion-button fill="clear" router-link="/appointments">Assessments</ion-button>
      </div>
      <div>
        <strong>Help &amp; trust</strong>
        <ion-button fill="clear" router-link="/faq">FAQs</ion-button>
        <ion-button fill="clear" router-link="/privacy">Privacy policy</ion-button>
        <p>hello@fureverhome.org<br />+1 (555) 014-PAWS</p>
      </div>
    </div>
    <div class="container legal">© 2025 FurEver Home. Responsible adoption, thoughtfully managed.</div>
  </footer>
</template>

<style scoped>
.footer {
  padding: 60px 0 24px;
  background: #38271f;
  color: #f8f1e7;
}

.footer-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(150px, 0.8fr) minmax(180px, 0.8fr);
  gap: clamp(24px, 5vw, 64px);
}

.footer-grid > div:not(:first-child) {
  display: flex;
  min-width: 0;
  flex-direction: column;
  align-items: flex-start;
}

.footer-brand {
  display: flex;
  align-items: center;
  gap: 9px;
  font-family: Georgia, serif;
  font-size: 1.4rem;
  font-weight: 700;
}

.footer p {
  color: #cfbfb5;
  line-height: 1.7;
}

.footer strong {
  display: block;
  margin-bottom: 12px;
}

.footer ion-button {
  --color: #e8ddd6;
  display: block;
  width: fit-content;
  min-width: 0;
  height: 34px;
  margin: 0;
  text-align: left;
  --padding-start: 0;
  --padding-end: 0;
}

.footer ion-button::part(native) {
  justify-content: flex-start;
}

.socials {
  display: flex;
}

.legal {
  margin-top: 42px;
  border-top: 1px solid #59443a;
  padding-top: 22px;
  color: #ad9c93;
  font-size: 0.82rem;
}

@media (max-width: 720px) {
  .footer-grid {
    grid-template-columns: 1fr;
    gap: 28px;
  }
}
</style>
