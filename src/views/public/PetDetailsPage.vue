<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import {
  IonAccordion,
  IonAccordionGroup,
  IonButton,
  IonChip,
  IonContent,
  IonIcon,
  IonItem,
  IonLabel,
  IonPage,
  alertController,
  toastController,
} from "@ionic/vue";
import {
  calendarClearOutline,
  checkmarkCircle,
  heart,
  heartOutline,
  locationOutline,
  playCircleOutline,
  shieldCheckmarkOutline,
  timeOutline,
} from "ionicons/icons";
import SiteHeader from "@/components/SiteHeader.vue";
import SiteFooter from "@/components/SiteFooter.vue";
import ShelterMap from "@/components/ShelterMap.vue";
import { pets } from "@/services/catalog";
import { useAppState } from "@/composables/useAppState";
import { useFavoriteAction } from "@/composables/useFavoriteAction";
import { supabase } from "@/services/supabase";

const route = useRoute();
const router = useRouter();
const pet = computed(() => pets.find((item) => item.id === route.params.id) || pets[0]);
const { state } = useAppState();
const { handleFavorite } = useFavoriteAction();
const showVideo = ref(false);
const videoError = ref(false);
const video = computed(() => pet.value?.videos?.[0]);
const assessmentEligible = ref(false);
const eligibilityLoading = ref(false);

const loadEligibility = async () => {
  assessmentEligible.value = false;
  const { data: userData } = await supabase.auth.getUser();
  if (!userData.user) return;

  eligibilityLoading.value = true;
  const { data, error } = await supabase
    .from("assessment_records")
    .select("id, appointment:appointments!inner(pet_id)")
    .eq("applicant_id", userData.user.id)
    .eq("outcome", "approved_to_proceed")
    .eq("appointment.pet_id", pet.value.id)
    .limit(1)
    .maybeSingle();
  assessmentEligible.value = !error && Boolean(data);
  eligibilityLoading.value = false;
};

const loadPetDetails = () => {
  showVideo.value = false;
  videoError.value = false;
  void loadEligibility();
};

onMounted(loadPetDetails);
watch(
  () => route.params.id,
  loadPetDetails,
);

const bookAssessment = async () => {
  if (assessmentEligible.value) {
    await router.push(`/applications/new/${pet.value.id}`);
    return;
  }

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    await router.push(`/appointments/book/${pet.value.id}`);
    return;
  }

  const { data: pendingAppointment, error } = await supabase
    .from("appointments")
    .select("starts_at, pet:pets(name)")
    .eq("applicant_id", userData.user.id)
    .eq("status", "pending_confirmation")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    const toast = await toastController.create({ message: error.message, color: "danger", duration: 2400 });
    await toast.present();
    return;
  }

  if (pendingAppointment) {
    const appointmentDate = new Date(pendingAppointment.starts_at).toLocaleString();
    const alert = await alertController.create({
      header: "Appointment still pending",
      message: `You already have a pending appointment${pendingAppointment.pet ? ` for ${pendingAppointment.pet.name}` : ""} on ${appointmentDate}. Please wait for confirmation before booking another.`,
      buttons: [
        { text: "View appointments", handler: () => router.push("/appointments") },
        { text: "OK", role: "cancel" },
      ],
    });
    await alert.present();
    return;
  }

  await router.push(`/appointments/book/${pet.value.id}`);
};
</script>

<template>
  <ion-page>
    <site-header />
    <ion-content id="main-content">
      <div class="container details">
        <div class="gallery">
          <img :src="pet.image" :alt="pet.name" />
          <span class="status-pill">{{ pet.status }}</span>
        </div>
        <aside>
          <div class="eyebrow">{{ pet.species }} · {{ pet.breed }}</div>
          <h1>{{ pet.name }}</h1>
          <p class="lead">{{ pet.personality }}</p>
          <div class="pet-facts">
            <ion-chip>{{ pet.age }}</ion-chip>
            <ion-chip>{{ pet.gender }}</ion-chip>
            <ion-chip>{{ pet.size }}</ion-chip>
          </div>
          <p class="location"><ion-icon :icon="locationOutline" /> {{ pet.location }}</p>
          <p v-if="pet.address" class="shelter-address">{{ pet.address }}</p>
          <div class="verified">
            <ion-icon :icon="shieldCheckmarkOutline" />
            <div>
              <strong>Shelter-verified care record</strong>
              <span>{{ pet.vaccinationStatus }} · {{ pet.health }}</span>
            </div>
          </div>
          <ion-button
            expand="block"
            size="large"
            :disabled="pet.status !== 'Available' || eligibilityLoading"
            @click="bookAssessment"
          >
            <ion-icon slot="start" :icon="assessmentEligible ? checkmarkCircle : calendarClearOutline" />
            {{ assessmentEligible ? `Adopt ${pet.name}` : "Book assessment appointment" }}
          </ion-button>
          <ion-button expand="block" fill="outline" @click="handleFavorite(pet.id)">
            <ion-icon slot="start" :icon="state.favorites.has(pet.id) ? heart : heartOutline" />
            {{ state.favorites.has(pet.id) ? "Saved to favorites" : "Save to favorites" }}
          </ion-button>
        </aside>
      </div>

      <section
        v-if="pet.latitude !== null && pet.longitude !== null"
        class="container shelter-location"
      >
        <div>
          <div class="eyebrow">Visit the shelter</div>
          <h2 class="section-title">Shelter location</h2>
          <p class="lead">{{ pet.address || pet.location }}</p>
        </div>
        <shelter-map :latitude="pet.latitude" :longitude="pet.longitude" />
      </section>

      <section class="container profile-section">
        <div>
          <div class="eyebrow">Know their story</div>
          <h2 class="section-title">Life with {{ pet.name }}</h2>
          <p class="lead">{{ pet.story }}</p>
          <ion-accordion-group>
            <ion-accordion v-for="item in [
              ['Health & care', `${pet.health}. Vaccination and deworming records reviewed by shelter staff.`],
              ['Feeding preferences', 'Two measured meals daily. Fresh water should always be available.'],
              ['Special care', pet.health === 'Special care' ? 'Requires a patient introduction and follow-up veterinary care.' : 'No special care requirements currently recorded.'],
              ['Adoption eligibility', 'Available after physical assessment and authorized staff approval.'],
            ]" :key="item[0]">
              <ion-item slot="header"><ion-label>{{ item[0] }}</ion-label></ion-item>
              <div slot="content" class="accordion-copy">{{ item[1] }}</div>
            </ion-accordion>
          </ion-accordion-group>
        </div>
        <div v-if="video" class="video-card surface">
          <div class="video-frame">
            <img v-if="!showVideo" :src="pet.image" :alt="`${pet.name} behavior video preview`" />
            <video
              v-else
              :key="video.url"
              controls
              autoplay
              preload="metadata"
              :poster="pet.image"
              @error="videoError = true"
              @loadeddata="videoError = false"
            >
              <source :src="video.url" :type="video.contentType" />
              <track kind="captions" label="English" />
              Your browser does not support this video.
            </video>
            <div v-if="videoError" class="video-playback-error" role="alert">
              <p>Hindi ma-load ang behavior video. Tingnan ang internet connection at subukang muli.</p>
              <ion-button fill="outline" size="small" @click="videoError = false; showVideo = false">
                Subukan ulit
              </ion-button>
            </div>
            <ion-button v-if="!showVideo" aria-label="Play behavior evidence" @click="showVideo = true">
              <ion-icon slot="icon-only" :icon="playCircleOutline" />
            </ion-button>
          </div>
          <div class="video-copy">
            <span
              class="status-pill"
              :class="{ pending: video.verificationStatus !== 'verified' }"
            >
              <ion-icon
                :icon="video.verificationStatus === 'verified' ? checkmarkCircle : timeOutline"
              />
              {{ video.verificationStatus === "verified" ? "Verified" : "Pending review" }}
            </span>
            <h3>{{ video.observedTrait }}</h3>
            <p>{{ video.description }} · Uploaded {{ new Date(video.uploadedAt).toLocaleDateString() }}</p>
            <small>
              Video is behavioral evidence only and does not guarantee medical health or future
              temperament.
            </small>
            <small v-if="video.sourceAttribution" class="attribution">
              {{ video.sourceAttribution }}
            </small>
          </div>
        </div>
        <div v-else class="video-empty surface">
          <ion-icon :icon="playCircleOutline" />
          <h3>No behavior video uploaded yet</h3>
          <p>Authorized shelter staff can upload a video for review.</p>
        </div>
      </section>
      <site-footer />
    </ion-content>
  </ion-page>
</template>

<style scoped>
.details {
  display: grid;
  grid-template-columns: 1.1fr 0.9fr;
  gap: 60px;
  padding-block: 60px;
}

.gallery {
  position: relative;
  height: 600px;
}

.gallery img {
  width: 100%;
  height: 100%;
  border-radius: 28px;
  object-fit: cover;
}

.gallery .status-pill {
  position: absolute;
  top: 18px;
  left: 18px;
}

aside {
  align-self: center;
}

h1 {
  margin: 10px 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: clamp(3.5rem, 7vw, 5rem);
}

.pet-facts,
.location {
  display: flex;
  align-items: center;
}

.location {
  gap: 7px;
  color: var(--ink-muted);
}

.shelter-address {
  margin-top: -8px;
  color: var(--ink-muted);
  font-size: 0.9rem;
}

.shelter-location {
  display: grid;
  grid-template-columns: 0.7fr 1.3fr;
  align-items: center;
  gap: 36px;
  padding-block: 0 56px;
}

.verified {
  display: flex;
  align-items: center;
  gap: 14px;
  margin: 24px 0;
  border: 1px solid #bcd0b5;
  border-radius: 16px;
  background: var(--success-soft);
  padding: 15px;
  color: #3e5d37;
}

.verified ion-icon {
  font-size: 1.7rem;
}

.verified strong,
.verified span {
  display: block;
}

.verified span {
  margin-top: 3px;
  font-size: 0.83rem;
}

.profile-section {
  display: grid;
  grid-template-columns: 0.85fr 1.15fr;
  gap: 70px;
  padding-block: 20px 90px;
}

.accordion-copy {
  padding: 4px 18px 22px;
  color: var(--ink-muted);
  line-height: 1.6;
}

.video-card {
  align-self: start;
  overflow: hidden;
}

.video-frame {
  position: relative;
  aspect-ratio: 1.6;
  background: #251b17;
}

.video-frame img,
.video-frame video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.video-frame img {
  opacity: 0.76;
}

.video-frame ion-button {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 66px;
  height: 66px;
  transform: translate(-50%, -50%);
  --border-radius: 50%;
}

.video-playback-error {
  position: absolute;
  inset: auto 12px 12px;
  border-radius: 12px;
  background: rgba(255, 253, 249, 0.96);
  padding: 10px 14px;
  text-align: center;
}

.video-playback-error p {
  margin: 0 0 6px;
  color: #8e3825;
  font-size: 0.88rem;
}

.video-copy {
  padding: 24px;
}

.video-copy h3 {
  margin-bottom: 5px;
  color: var(--ion-color-secondary);
}

.video-copy p,
.video-copy small {
  color: var(--ink-muted);
  line-height: 1.5;
}

.status-pill.pending {
  background: #fff3d6;
  color: #714f21;
}

.attribution {
  display: block;
  margin-top: 10px;
}

.video-empty {
  padding: 50px 24px;
  color: var(--ink-muted);
  text-align: center;
}

.video-empty > ion-icon {
  color: var(--ion-color-primary);
  font-size: 3rem;
}

@media (max-width: 800px) {
  .details,
  .profile-section,
  .shelter-location {
    grid-template-columns: 1fr;
  }

  .gallery {
    height: 440px;
  }
}
</style>
