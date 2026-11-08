<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import {
  IonButton,
  IonContent,
  IonDatetime,
  IonInput,
  IonModal,
  IonPage,
  IonSelect,
  IonSelectOption,
  IonTextarea,
  alertController,
  toastController,
} from "@ionic/vue";
import SiteHeader from "@/components/SiteHeader.vue";
import ShelterMap from "@/components/ShelterMap.vue";
import { pets, refreshPetLocation } from "@/services/catalog";
import { supabase } from "@/services/supabase";

const route = useRoute();
const router = useRouter();
const pet = computed(() => pets.find((item) => item.id === route.params.petId) || pets[0]);
const shelterMapOpen = ref(false);
const locationLoadError = ref("");
const hasShelterPin = computed(
  () =>
    pet.value.latitude !== null &&
    pet.value.longitude !== null &&
    Number.isFinite(pet.value.latitude) &&
    Number.isFinite(pet.value.longitude),
);
const shelterCoordinates = computed(() => {
  if (!hasShelterPin.value) return "";
  return `${pet.value.latitude!.toFixed(6)}, ${pet.value.longitude!.toFixed(6)}`;
});
const openStreetMapUrl = computed(() =>
  `https://www.openstreetmap.org/?mlat=${pet.value.latitude}&mlon=${pet.value.longitude}#map=18/${pet.value.latitude}/${pet.value.longitude}`,
);
const form = ref({
  name: "",
  phone: "",
  email: "",
  date: "",
  time: "",
  location: pet.value.address || pet.value.location,
  reason: "",
  experience: "",
  residence: "",
  notes: "",
});

watch(
  () => pet.value.address || pet.value.location,
  (location) => {
    form.value.location = location;
  },
);

onMounted(async () => {
  const petId = String(route.params.petId || "");
  const error = await refreshPetLocation(petId);
  if (error) locationLoadError.value = error;
});

const showPendingAppointment = async (appointment: { starts_at: string; pet: { name: string } | null }) => {
  const appointmentDate = new Date(appointment.starts_at).toLocaleString();
  const alert = await alertController.create({
    header: "Appointment still pending",
    message: `You already have a pending appointment${appointment.pet ? ` for ${appointment.pet.name}` : ""} on ${appointmentDate}. Please wait for confirmation before booking another.`,
    buttons: [
      { text: "View appointments", handler: () => router.push("/appointments") },
      { text: "OK", role: "cancel" },
    ],
  });
  await alert.present();
};

const submit = async () => {
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    const toast = await toastController.create({ message: "Sign in before booking an appointment.", color: "danger", duration: 2400 });
    return toast.present();
  }

  const { data: pendingAppointment, error: pendingError } = await supabase
    .from("appointments")
    .select("starts_at, pet:pets(name)")
    .eq("applicant_id", userData.user.id)
    .eq("status", "pending_confirmation")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (pendingError) {
    const toast = await toastController.create({ message: pendingError.message, color: "danger", duration: 2400 });
    return toast.present();
  }
  if (pendingAppointment) {
    await showPendingAppointment(pendingAppointment);
    return;
  }

  if (!form.value.name || !form.value.phone || !form.value.email || !form.value.date || !form.value.time) {
    const toast = await toastController.create({ message: "Complete all required fields.", color: "danger", duration: 2400 });
    return toast.present();
  }
  const alert = await alertController.create({
    header: "Confirm assessment request",
    message: `Request ${form.value.date} at ${form.value.time} for ${pet.value.name}?`,
    buttons: [
      { text: "Review", role: "cancel" },
      {
        text: "Confirm booking",
        handler: async () => {
          const startsAt = new Date(`${form.value.date.slice(0, 10)}T${form.value.time}:00`);
          const { error } = await supabase.from("appointments").insert({
            applicant_id: userData.user.id,
            pet_id: pet.value.id,
            starts_at: startsAt.toISOString(),
            location: form.value.location,
            contact_number: form.value.phone,
            reason_for_adoption: form.value.reason,
            pet_experience: form.value.experience,
            household_information: form.value.residence,
            additional_notes: form.value.notes,
          });
          const toast = await toastController.create({
            message: error ? error.message : "Appointment saved as Pending Confirmation.",
            color: error ? "danger" : "success",
            duration: 2600,
          });
          await toast.present();
          if (!error) router.push("/appointments");
        },
      },
    ],
  });
  await alert.present();
};
</script>

<template>
  <ion-page>
    <site-header />
    <ion-content id="main-content">
      <div class="container booking">
        <div>
          <div class="eyebrow">Required physical assessment</div>
          <h1 class="section-title">Meet {{ pet.name }}, thoughtfully.</h1>
          <p class="lead">
            This appointment helps shelter staff assess readiness and fit. Completion does not
            automatically mean approval.
          </p>
          <div class="pet-summary surface">
            <img :src="pet.image" :alt="pet.name" />
            <div><strong>{{ pet.name }}</strong><span>{{ pet.breed }} · {{ pet.age }}</span></div>
          </div>
        </div>
        <div class="form surface">
          <h2>Book an available time</h2>
          <div class="notice">Only available times are accepted. Duplicate or conflicting bookings are rejected.</div>
          <ion-input v-model="form.name" fill="outline" label="Applicant name *" label-placement="stacked" />
          <div class="two">
            <ion-input v-model="form.phone" type="tel" fill="outline" label="Contact number *" label-placement="stacked" />
            <ion-input v-model="form.email" type="email" fill="outline" label="Email *" label-placement="stacked" />
          </div>
          <ion-datetime v-model="form.date" presentation="date" :min="new Date().toISOString()" />
          <ion-select v-model="form.time" fill="outline" label="Available time *" label-placement="stacked">
            <ion-select-option value="09:00">9:00 AM</ion-select-option>
            <ion-select-option value="11:00">11:00 AM</ion-select-option>
            <ion-select-option value="14:00">2:00 PM</ion-select-option>
          </ion-select>
          <ion-select v-model="form.location" fill="outline" label="Meeting location" label-placement="stacked">
            <ion-select-option :value="pet.address || pet.location">
              {{ pet.address ? `${pet.location} — ${pet.address}` : pet.location }}
            </ion-select-option>
          </ion-select>
          <ion-button
            fill="outline"
            :disabled="!hasShelterPin"
            @click="shelterMapOpen = true"
          >
            View shelter on map
          </ion-button>
          <p v-if="!hasShelterPin" class="map-unavailable-note">
            {{ locationLoadError || "The shelter has not added a map pin yet. Please contact staff to confirm the location." }}
          </p>
          <ion-textarea v-model="form.reason" fill="outline" label="Reason for adoption" label-placement="stacked" />
          <ion-textarea v-model="form.experience" fill="outline" label="Previous pet experience" label-placement="stacked" />
          <ion-textarea v-model="form.residence" fill="outline" label="Residence and household" label-placement="stacked" />
          <ion-textarea v-model="form.notes" fill="outline" label="Additional notes" label-placement="stacked" />
          <ion-button expand="block" size="large" @click="submit">Request appointment</ion-button>
        </div>
      </div>
    </ion-content>
    <ion-modal
      :is-open="shelterMapOpen"
      class="shelter-map-modal"
      @didDismiss="shelterMapOpen = false"
    >
      <ion-content v-if="hasShelterPin" class="shelter-map-content">
        <div class="shelter-map-heading">
          <div>
            <div class="eyebrow">Meeting location</div>
            <h2>{{ pet.address || pet.location }}</h2>
            <p>{{ pet.location }}</p>
            <p class="shelter-coordinates">
              Latitude: {{ pet.latitude?.toFixed(6) }} · Longitude: {{ pet.longitude?.toFixed(6) }}
            </p>
          </div>
          <ion-button fill="outline" @click="shelterMapOpen = false">Close map</ion-button>
        </div>
        <div class="booking-map">
          <shelter-map :latitude="pet.latitude" :longitude="pet.longitude" />
        </div>
        <p class="map-attribution-note">
          Map pin added by shelter staff · © OpenStreetMap contributors
        </p>
        <a
          class="map-external-link"
          :href="openStreetMapUrl"
          target="_blank"
          rel="noopener noreferrer"
        >
          Open this exact pin in OpenStreetMap
        </a>
      </ion-content>
    </ion-modal>
  </ion-page>
</template>

<style scoped>
.map-unavailable-note {
  margin: -4px 0 0;
  color: var(--ink-muted);
  font-size: 0.88rem;
}

.shelter-map-modal {
  --width: min(900px, calc(100vw - 32px));
  --height: min(720px, calc(100vh - 32px));
  --border-radius: 20px;
}

.shelter-map-content {
  --background: var(--ion-background-color);
  padding: 24px;
}

.shelter-map-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20px;
  margin: 0 auto 20px;
  max-width: 860px;
}

.shelter-map-heading h2 {
  margin: 5px 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.8rem;
}

.shelter-map-heading p,
.map-attribution-note {
  color: var(--ink-muted);
}

.shelter-map-heading .shelter-coordinates {
  font-size: 0.9rem;
  font-variant-numeric: tabular-nums;
}

.booking-map {
  max-width: 860px;
  margin: 0 auto;
}

.booking-map :deep(.shelter-map) {
  height: min(58vh, 500px);
}

.map-attribution-note {
  max-width: 860px;
  margin: 10px auto;
  font-size: 0.8rem;
}

.map-external-link {
  display: block;
  max-width: 860px;
  margin: 0 auto;
  color: var(--ion-color-primary);
}

.booking {
  display: grid;
  grid-template-columns: 0.8fr 1.2fr;
  align-items: start;
  gap: 60px;
  padding-block: 60px 90px;
}

.pet-summary {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-top: 30px;
  padding: 14px;
}

.pet-summary img {
  width: 80px;
  height: 80px;
  border-radius: 16px;
  object-fit: cover;
}

.pet-summary strong,
.pet-summary span {
  display: block;
}

.pet-summary span {
  margin-top: 5px;
  color: var(--ink-muted);
}

.form {
  display: grid;
  gap: 14px;
  padding: 30px;
}

.form h2 {
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 2rem;
}

.two {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
}

.notice {
  border-radius: 10px;
  background: #fff3d6;
  padding: 12px;
  color: #69481d;
  font-size: 0.82rem;
}

@media (max-width: 800px) {
  .booking {
    grid-template-columns: 1fr;
  }

  .two {
    grid-template-columns: 1fr;
  }

  .shelter-map-content {
    padding: 16px;
  }

  .shelter-map-heading {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
