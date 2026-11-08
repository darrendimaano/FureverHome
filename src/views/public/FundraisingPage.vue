<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import {
  IonButton,
  IonCheckbox,
  IonContent,
  IonIcon,
  IonInput,
  IonModal,
  IonPage,
  IonProgressBar,
  IonSelect,
  IonSelectOption,
  IonTextarea,
  toastController,
} from "@ionic/vue";
import { closeOutline } from "ionicons/icons";
import SiteHeader from "@/components/SiteHeader.vue";
import SiteFooter from "@/components/SiteFooter.vue";
import { campaigns } from "@/services/catalog";
import { useAppState } from "@/composables/useAppState";
import { supabase } from "@/services/supabase";

const route = useRoute();
const router = useRouter();
const { refreshNotifications } = useAppState();
const selected = computed(() => campaigns.find((item) => item.id === route.params.id));
const activeCampaigns = computed(() => campaigns.filter((campaign) => campaign.status === "Active"));
const showAllCampaigns = ref(false);
const browsedCampaigns = computed(() => showAllCampaigns.value ? campaigns : activeCampaigns.value);
const amount = ref<number | null>(null);
const donor = ref("");
const email = ref("");
const message = ref("");
const anonymous = ref(false);
const campaignId = ref(selected.value?.status === "Active" ? selected.value.id : activeCampaigns.value[0]?.id || "");
const paymentReference = ref("");
const proofFile = ref<File | null>(null);
const submitting = ref(false);
const donationModalOpen = ref(false);
const paymentSettings = ref<{ gcash_number: string; qr_storage_path: string | null } | null>(null);
const paymentSettingsLoading = ref(true);
const showSupporters = ref(false);
const supportersLoading = ref(false);
const supportersError = ref("");
const publicDonors = ref<Array<{
  campaign_id: string;
  display_name: string;
  display_email: string | null;
  created_at: string;
}>>([]);
const qrImageUrl = computed(() => {
  const path = paymentSettings.value?.qr_storage_path;
  if (!path) return "";
  return /^https?:\/\//.test(path)
    ? path
    : supabase.storage.from("fundraising-qr").getPublicUrl(path).data.publicUrl;
});
const selectedCampaignId = computed(() => selected.value?.id || campaignId.value);
const selectedCampaignDonors = computed(() => publicDonors.value.filter((item) => item.campaign_id === selectedCampaignId.value));
const canDonate = computed(() => selected.value ? selected.value.status === "Active" : activeCampaigns.value.length > 0);

watch(() => selected.value?.id, () => {
  donationModalOpen.value = false;
  showSupporters.value = false;
  publicDonors.value = [];
  supportersError.value = "";
  campaignId.value = selected.value?.status === "Active" ? selected.value.id : activeCampaigns.value[0]?.id || "";
});

watch(campaigns, (items) => {
  if (!selected.value && !activeCampaigns.value.some((campaign) => campaign.id === campaignId.value) && items.length) {
    campaignId.value = activeCampaigns.value[0]?.id || "";
  }
}, { immediate: true });

const loadFundraisingDetails = async () => {
  paymentSettingsLoading.value = true;
  const settingsResult = await supabase
    .from("fundraising_payment_settings")
    .select("gcash_number, qr_storage_path")
    .eq("id", 1)
    .maybeSingle();
  paymentSettings.value = settingsResult.data || null;
  paymentSettingsLoading.value = false;
};

const toggleSupporters = async () => {
  if (!selected.value) return;
  if (showSupporters.value) {
    showSupporters.value = false;
    return;
  }
  showSupporters.value = true;
  supportersLoading.value = true;
  supportersError.value = "";
  const { data, error } = await supabase
    .from("campaign_public_donors")
    .select("campaign_id, display_name, display_email, created_at")
    .eq("campaign_id", selected.value.id)
    .order("created_at", { ascending: false });
  if (error) supportersError.value = error.message;
  else publicDonors.value = data || [];
  supportersLoading.value = false;
};

const selectProofFile = async (event: Event) => {
  const component = event.target as EventTarget & { getInputElement?: () => Promise<HTMLInputElement> };
  const input = await component.getInputElement?.();
  const file = input?.files?.[0] || null;
  if (!file) return;
  if (!new Set(["image/jpeg", "image/png", "image/webp", "application/pdf"]).has(file.type) || file.size > 10 * 1024 * 1024) {
    proofFile.value = null;
    const toast = await toastController.create({ message: "Upload a JPG, PNG, WebP, or PDF proof no larger than 10 MB.", color: "danger", duration: 3000 });
    await toast.present();
    return;
  }
  proofFile.value = file;
};

const submitDonation = async () => {
  if (!canDonate.value || !activeCampaigns.value.some((campaign) => campaign.id === campaignId.value)) {
    const toast = await toastController.create({ message: "This campaign is no longer accepting donations.", color: "warning", duration: 2800 });
    return toast.present();
  }
  if (!paymentSettings.value?.gcash_number && !paymentSettings.value?.qr_storage_path) {
    const toast = await toastController.create({ message: "GCash payment instructions are not set up yet.", color: "warning", duration: 3000 });
    return toast.present();
  }
  if (!donor.value.trim() || !email.value.trim() || !amount.value || amount.value <= 0 || !campaignId.value || !proofFile.value) {
    const toast = await toastController.create({ message: "Complete your name, email, amount, campaign, and proof of payment.", color: "danger", duration: 2800 });
    return toast.present();
  }

  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    const toast = await toastController.create({ message: "Sign in before submitting proof of payment.", color: "warning", duration: 2800 });
    await toast.present();
    await router.push("/login");
    return;
  }

  submitting.value = true;
  const safeName = proofFile.value.name.replace(/[^a-zA-Z0-9._-]/g, "-");
  const proofPath = `${authData.user.id}/${crypto.randomUUID()}-${safeName}`;
  const upload = await supabase.storage.from("donation-proofs").upload(proofPath, proofFile.value, {
    contentType: proofFile.value.type,
    upsert: false,
  });
  if (upload.error) {
    submitting.value = false;
    const toast = await toastController.create({ message: upload.error.message, color: "danger", duration: 3000 });
    return toast.present();
  }

  const { error } = await supabase.from("donations").insert({
    campaign_id: campaignId.value,
    donor_id: authData.user.id,
    donor_name: donor.value.trim(),
    donor_email: email.value.trim(),
    amount: amount.value,
    anonymous: anonymous.value,
    message: message.value.trim() || null,
    payment_provider: "gcash",
    payment_reference: paymentReference.value.trim() || null,
    payment_status: "offline_pending",
    proof_storage_path: proofPath,
  });
  if (error) await supabase.storage.from("donation-proofs").remove([proofPath]);
  submitting.value = false;

  const toast = await toastController.create({
    message: error ? error.message : "Donation proof submitted. It will appear in the supporter list after admin confirmation.",
    color: error ? "danger" : "success",
    duration: 3400,
  });
  await toast.present();
  if (!error) {
    amount.value = null;
    message.value = "";
    paymentReference.value = "";
    proofFile.value = null;
    await refreshNotifications();
  }
};

onMounted(loadFundraisingDetails);
</script>

<template>
  <ion-page>
    <site-header />
    <ion-content id="main-content">
      <section class="fund-hero">
        <div class="container">
          <div class="eyebrow">Give care, comfort, and second chances</div>
          <h1 class="section-title">{{ selected ? selected.title : "Support rescue that lasts." }}</h1>
          <p class="lead">
            Every confirmed donation helps provide food, veterinary treatment, safe shelter, and
            transport for rescued cats and dogs.
          </p>
        </div>
      </section>
      <section v-if="!selected" class="container campaign-browser">
        <header class="campaign-browser-heading">
          <div>
            <div class="eyebrow">{{ showAllCampaigns ? "Campaign archive" : "Current fundraising" }}</div>
            <h2>{{ showAllCampaigns ? "All campaigns" : "Active campaigns" }}</h2>
          </div>
          <ion-button fill="outline" @click="showAllCampaigns = !showAllCampaigns">
            {{ showAllCampaigns ? "View active campaigns" : "View all campaigns" }}
          </ion-button>
        </header>
        <div v-if="browsedCampaigns.length" class="campaign-strip" :class="{ 'all-campaign-grid': showAllCampaigns }">
          <button
            v-for="campaign in browsedCampaigns"
            :key="campaign.id"
            class="campaign-tile surface"
            @click="router.push(`/fundraising/${campaign.id}`)"
          >
            <span class="campaign-tile-image">
              <img :src="campaign.image" :alt="campaign.title" />
              <span class="status-pill" :class="{ ended: campaign.status !== 'Active' }">{{ campaign.status }}</span>
            </span>
            <span class="campaign-tile-body">
              <strong>{{ campaign.title }}</strong>
              <small>{{ campaign.purpose }}</small>
              <ion-progress-bar :value="Math.min(1, campaign.raised / campaign.target)" />
              <span class="campaign-tile-total">₱{{ campaign.raised.toLocaleString() }} raised</span>
            </span>
          </button>
        </div>
        <div v-else class="campaign-empty surface">
          <h3>{{ showAllCampaigns ? "No campaigns to show" : "No active campaigns right now" }}</h3>
          <p>{{ showAllCampaigns ? "Campaigns will appear here when they are published." : "View all campaigns to browse the archive." }}</p>
        </div>
      </section>

      <div class="container fund-layout" :class="{ 'fund-layout-single': !selected, 'campaign-detail-layout': selected }">
        <main v-if="selected">
          <article class="campaign surface">
            <img :src="selected.image" :alt="selected.title" />
            <div class="campaign-body">
              <span class="status-pill" :class="{ ended: selected.status !== 'Active' }">{{ selected.status }}</span>
              <h2>{{ selected.title }}</h2>
              <p>{{ selected.purpose }}</p>
              <p>
                Funds are allocated to supplier invoices and authorized shelter expenses.
                Public totals include only confirmed online payments and authorized offline records.
              </p>
              <ion-progress-bar :value="Math.min(1, selected.raised / selected.target)" />
              <div class="totals">
                <strong>₱{{ selected.raised.toLocaleString() }} raised</strong>
                <span>₱{{ selected.target.toLocaleString() }} goal · Ends {{ selected.endDate }}</span>
              </div>
              <div class="supporters">
                <ion-button fill="outline" size="small" @click="toggleSupporters">
                  {{ supportersLoading ? "Loading supporters..." : showSupporters ? "Hide confirmed supporters" : "View confirmed supporters" }}
                </ion-button>
                <div v-if="showSupporters" class="supporter-list-wrap">
                  <h3>Confirmed supporters</h3>
                  <p v-if="supportersError">{{ supportersError }}</p>
                  <p v-else-if="!supportersLoading && !selectedCampaignDonors.length">No confirmed supporters listed yet.</p>
                  <div v-else class="supporter-list">
                    <div v-for="supporter in selectedCampaignDonors" :key="`${supporter.campaign_id}-${supporter.created_at}-${supporter.display_email}`" class="supporter-row">
                    <strong>{{ supporter.display_name }}</strong>
                    <span v-if="supporter.display_email">{{ supporter.display_email }}</span>
                    </div>
                  </div>
                </div>
              </div>
              <ion-button v-if="canDonate" expand="block" size="large" @click="donationModalOpen = true">
                Donate to this campaign
              </ion-button>
              <div v-else class="notice">This campaign has ended or is closed and is no longer accepting donations.</div>
            </div>
          </article>
        </main>
      </div>
      <ion-modal
        :is-open="donationModalOpen"
        class="donation-modal"
        @didDismiss="donationModalOpen = false"
      >
        <ion-content class="donation-modal-content">
          <div class="donation-modal-inner">
            <header class="donation-modal-header">
              <div>
                <div class="eyebrow">Donation pledge</div>
                <h2>Make a difference</h2>
                <p>{{ selected?.title }}</p>
              </div>
              <ion-button fill="clear" aria-label="Close donation form" @click="donationModalOpen = false">
                <ion-icon slot="icon-only" :icon="closeOutline" />
              </ion-button>
            </header>
            <div class="notice">Send your donation through GCash, then submit your proof. The donation is counted after admin verifies it.</div>
            <div v-if="paymentSettingsLoading" class="payment-loading">Loading GCash instructions...</div>
            <div v-else-if="paymentSettings?.gcash_number || qrImageUrl" class="gcash-instructions">
              <strong>GCash payment details</strong>
              <span v-if="paymentSettings?.gcash_number">GCash number: <b>{{ paymentSettings.gcash_number }}</b></span>
              <img v-if="qrImageUrl" :src="qrImageUrl" alt="GCash QR code for donations" />
            </div>
            <div v-else class="notice">GCash payment instructions are not available right now.</div>
            <ion-input v-model="donor" fill="outline" label="Donor name *" label-placement="stacked" />
            <ion-input v-model="email" type="email" fill="outline" label="Email *" label-placement="stacked" />
            <ion-input v-model="amount" type="number" min="1" fill="outline" label="Amount (PHP) *" label-placement="stacked" />
            <ion-input v-model="paymentReference" fill="outline" label="GCash reference number" label-placement="stacked" />
            <ion-input type="file" accept="image/jpeg,image/png,image/webp,application/pdf" fill="outline" label="Proof of payment *" label-placement="stacked" @ionChange="selectProofFile" />
            <small v-if="proofFile">Selected proof: {{ proofFile.name }}</small>
            <ion-textarea v-model="message" fill="outline" label="Optional message" label-placement="stacked" />
            <ion-checkbox v-model="anonymous" label-placement="end">Keep my donation anonymous</ion-checkbox>
            <small class="anonymous-note">If selected, your name and email will not appear in the confirmed supporters list. Your donation still counts toward the campaign total.</small>
            <ion-button expand="block" size="large" :disabled="!canDonate || submitting || paymentSettingsLoading || (!paymentSettings?.gcash_number && !paymentSettings?.qr_storage_path)" @click="submitDonation">
              {{ submitting ? "Submitting proof..." : "Submit donation proof" }}
            </ion-button>
            <small>Your name and email are masked on the supporter list only after admin confirmation. Your full details and proof stay private.</small>
          </div>
        </ion-content>
      </ion-modal>
      <site-footer />
    </ion-content>
  </ion-page>
</template>

<style scoped>
.fund-hero {
  padding: 70px 0 100px;
  background: var(--cream);
  text-align: center;
}

.fund-hero .container {
  max-width: 780px;
}

.campaign-browser {
  position: relative;
  z-index: 1;
  margin-top: -52px;
  padding-bottom: 24px;
}

.campaign-browser-heading {
  display: flex;
  align-items: end;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 16px;
}

.campaign-browser-heading h2 {
  margin: 4px 0 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.8rem;
}

.campaign-strip {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 14px;
}

.campaign-strip.all-campaign-grid {
  grid-template-columns: repeat(auto-fill, minmax(190px, 1fr));
}

.campaign-tile {
  display: grid;
  min-width: 0;
  align-content: start;
  overflow: hidden;
  border: 1px solid var(--border);
  padding: 0;
  color: var(--ion-color-secondary);
  font: inherit;
  text-align: left;
  cursor: pointer;
  transition: transform 160ms ease, box-shadow 160ms ease;
}

.campaign-tile:hover {
  transform: translateY(-3px);
  box-shadow: var(--shadow);
}

.campaign-tile-image {
  display: block;
  position: relative;
  aspect-ratio: 1.7;
  overflow: hidden;
  background: var(--cream);
}

.campaign-tile .campaign-tile-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.campaign-tile-image .status-pill {
  position: absolute;
  top: 8px;
  left: 8px;
  background: white;
  padding: 5px 8px;
  font-size: 0.66rem;
}

.campaign-tile-image .status-pill.ended {
  color: #6d625d;
}

.campaign-tile-body {
  display: grid;
  gap: 8px;
  padding: 12px;
}

.campaign-tile-body > strong {
  display: -webkit-box;
  overflow: hidden;
  font-size: 0.94rem;
  line-height: 1.3;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.campaign-tile-body > small {
  display: -webkit-box;
  min-height: 2.3em;
  overflow: hidden;
  color: var(--ink-muted);
  font-size: 0.76rem;
  line-height: 1.3;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.campaign-tile-body ion-progress-bar {
  height: 6px;
  border-radius: 99px;
}

.campaign-tile-total {
  color: var(--ion-color-primary);
  font-size: 0.76rem;
  font-weight: 700;
}

.campaign-empty {
  padding: 22px;
}

.campaign-empty h3 {
  margin-top: 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
}

.campaign-empty p {
  margin-bottom: 0;
  color: var(--ink-muted);
}

.fund-layout {
  display: grid;
  grid-template-columns: 1.2fr 0.8fr;
  align-items: start;
  gap: 30px;
  margin-top: -54px;
  padding-bottom: 80px;
}

.fund-layout-single {
  grid-template-columns: 1fr;
  margin-top: 12px;
}

.campaign-detail-layout {
  grid-template-columns: minmax(0, 820px);
  justify-content: center;
  margin-top: 12px;
}

.fund-layout-single .donation {
  position: static;
  width: min(100%, 680px);
  justify-self: center;
}

main {
  display: grid;
  gap: 24px;
}

.campaign {
  overflow: hidden;
}

.campaign img {
  width: 100%;
  height: 330px;
  object-fit: cover;
}

.campaign-body,
.donation {
  padding: 28px;
}

.campaign h2,
.donation h2 {
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 2rem;
}

.campaign p,
.donation small {
  color: var(--ink-muted);
  line-height: 1.6;
}

.totals {
  display: flex;
  justify-content: space-between;
  margin: 12px 0 20px;
  font-size: 0.88rem;
}

.totals strong {
  color: var(--ion-color-primary);
}

.supporters {
  margin: 18px 0;
  border-top: 1px solid var(--border);
  padding-top: 16px;
}

.supporter-list-wrap {
  margin-top: 14px;
  border-top: 1px solid var(--border);
  padding-top: 14px;
}

.supporters h3 {
  margin: 0 0 10px;
  color: var(--ion-color-secondary);
  font-size: 1rem;
}

.supporters p,
.supporter-row span,
.payment-loading {
  color: var(--ink-muted);
  font-size: 0.85rem;
}

.supporter-list {
  display: grid;
  gap: 8px;
}

.supporter-row {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  font-size: 0.88rem;
}

.supporter-row strong {
  color: var(--ion-color-secondary);
}

.gcash-instructions {
  display: grid;
  gap: 10px;
  border: 1px solid #c9dfcd;
  border-radius: 10px;
  background: #f1f8f1;
  padding: 14px;
  color: #315c3b;
}

.gcash-instructions img {
  width: min(100%, 240px);
  max-height: 280px;
  margin-inline: auto;
  object-fit: contain;
}

.donation {
  display: grid;
  gap: 14px;
}

ion-modal.donation-modal {
  --width: min(620px, calc(100% - 32px));
  --height: min(88vh, 820px);
  --border-radius: 14px;
  --box-shadow: 0 24px 72px rgba(47, 38, 34, 0.24);
}

.donation-modal-content {
  --background: #fffdfa;
}

.donation-modal-inner {
  display: grid;
  max-width: 620px;
  gap: 14px;
  margin-inline: auto;
  padding: 24px;
}

.donation-modal-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.donation-modal-header h2 {
  margin: 5px 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.8rem;
}

.donation-modal-header p {
  margin: 0;
  color: var(--ink-muted);
}

.notice {
  border-radius: 10px;
  background: #fff3d6;
  padding: 12px;
  color: #714f21;
  font-size: 0.82rem;
}

@media (max-width: 800px) {
  .campaign-browser-heading {
    align-items: flex-start;
    flex-direction: column;
  }

  .campaign-strip:not(.all-campaign-grid) {
    grid-auto-columns: 190px;
    grid-auto-flow: column;
    grid-template-columns: none;
    overflow-x: auto;
    padding-bottom: 8px;
  }

  .campaign-strip.all-campaign-grid {
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  }

  .fund-layout {
    grid-template-columns: 1fr;
  }

  .donation {
    position: static;
  }
}

@media (max-width: 600px) {
  .donation-modal-inner {
    gap: 12px;
    padding: 20px 16px;
  }
}
</style>
