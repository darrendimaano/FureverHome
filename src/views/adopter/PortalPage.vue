<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { useRoute } from "vue-router";
import {
  IonBadge,
  IonButton,
  IonContent,
  IonIcon,
  IonInput,
  IonItem,
  IonLabel,
  IonList,
  IonPage,
  IonProgressBar,
  IonTextarea,
  toastController,
} from "@ionic/vue";
import {
  calendarClearOutline,
  checkmarkCircleOutline,
  documentTextOutline,
  notificationsOutline,
  personOutline,
  walletOutline,
} from "ionicons/icons";
import SiteHeader from "@/components/SiteHeader.vue";
import PetCard from "@/components/PetCard.vue";
import { petImageUrl } from "@/services/catalog";
import { useAppState } from "@/composables/useAppState";
import { supabase } from "@/services/supabase";

const route = useRoute();
const {
  state,
  favoritePets,
  markNotificationRead,
  markAllNotificationsRead,
  refreshNotifications,
} = useAppState();
const title = computed(() => String(route.meta.title || "Your account"));
const section = computed(() => String(route.meta.section || ""));
const profile = ref({ name: state.userName, phone: "" });
const appointments = ref<Array<{
  id: string;
  starts_at: string;
  location: string;
  status: string;
  pet: { name: string } | null;
  assessment: { outcome: string; recommendations: string | null } | null;
}>>([]);
const appointmentsLoading = ref(false);
const appointmentsError = ref("");
const applications = ref<Array<{
  id: string;
  status: string;
  created_at: string;
  pet_id: string;
  review_notes: string | null;
  pet: { name: string } | null;
}>>([]);
const applicationsLoading = ref(false);
const applicationsError = ref("");
type ProgressAppointment = {
  id: string;
  pet_id: string;
  starts_at: string;
  created_at: string;
  status: string;
  pet: {
    name: string;
    breed: string;
    pet_photos: Array<{ storage_path: string; sort_order: number }> | null;
  } | null;
};
type ProgressAssessment = {
  appointment_id: string;
  outcome: string;
  assessed_at: string;
  recommendations: string | null;
};
type ProgressApplication = {
  id: string;
  pet_id: string;
  status: string;
  created_at: string;
  submitted_at: string | null;
  updated_at: string;
  review_notes: string | null;
  pet: {
    name: string;
    breed: string;
    pet_photos: Array<{ storage_path: string; sort_order: number }> | null;
  } | null;
};
const progressAppointments = ref<ProgressAppointment[]>([]);
const progressAssessments = ref<ProgressAssessment[]>([]);
const progressApplications = ref<ProgressApplication[]>([]);
const progressLoading = ref(false);
const progressError = ref("");
const notificationsLoading = ref(false);
const notificationsError = ref("");

const formatAppointmentStatus = (status: string) =>
  status.split("_").map((word) => word[0].toUpperCase() + word.slice(1)).join(" ");

const appointmentStatusColor = (status: string) => {
  if (status === "pending_confirmation") return "warning";
  if (status === "confirmed" || status === "completed") return "success";
  if (status === "cancelled" || status === "no_show") return "medium";
  return "tertiary";
};

const formatAppointmentDate = (startsAt: string) => new Date(startsAt).toLocaleString();
const assessmentOutcomeLabel = (outcome: string) => ({
  approved_to_proceed: "Eligible to proceed",
  additional_assessment_required: "Additional assessment required",
  not_approved: "Not eligible to adopt",
}[outcome] || outcome);
const applicationStatusLabel = (status: string) => status.split("_").map((word) => word[0].toUpperCase() + word.slice(1)).join(" ");

const adoptionProgress = computed(() => {
  const grouped = new Map<string, {
    petId: string;
    pet: { name: string; breed: string; image: string } | null;
    appointments: ProgressAppointment[];
    applications: ProgressApplication[];
  }>();
  const ensurePet = (
    petId: string,
    pet: ProgressAppointment["pet"] | ProgressApplication["pet"],
  ) => {
    const mappedPet = pet
      ? {
          name: pet.name,
          breed: pet.breed,
          image: petImageUrl(pet.pet_photos),
        }
      : null;
    let item = grouped.get(petId);
    if (!item) {
      item = { petId, pet: mappedPet, appointments: [], applications: [] };
      grouped.set(petId, item);
    } else if (!item.pet && mappedPet) {
      item.pet = mappedPet;
    }
    return item;
  };
  for (const appointment of progressAppointments.value) {
    ensurePet(appointment.pet_id, appointment.pet).appointments.push(appointment);
  }
  for (const application of progressApplications.value) {
    ensurePet(application.pet_id, application.pet).applications.push(application);
  }
  return [...grouped.values()]
    .map((item) => {
      item.appointments.sort((a, b) => b.created_at.localeCompare(a.created_at));
      item.applications.sort((a, b) => b.created_at.localeCompare(a.created_at));
      const appointment = item.appointments[0] || null;
      const petAppointmentIds = new Set(item.appointments.map((row) => row.id));
      const assessment = progressAssessments.value
        .filter((row) => petAppointmentIds.has(row.appointment_id))
        .sort((a, b) => b.assessed_at.localeCompare(a.assessed_at))[0] || null;
      const application = item.applications[0] || null;
      const appointmentDone = Boolean(appointment) &&
        !["cancelled", "no_show"].includes(appointment?.status || "");
      const assessmentDone = Boolean(assessment);
      const applicationDone = Boolean(
        application && !["draft", "rejected"].includes(application.status),
      );
      const adoptionDone = application?.status === "adoption_completed";
      const completedMilestones = Number(appointmentDone) +
        Number(assessmentDone) +
        Number(applicationDone) +
        Number(adoptionDone);
      return {
        ...item,
        appointment,
        assessment,
        application,
        milestones: [
          {
            title: "Assessment appointment",
            detail: appointment
              ? `${formatAppointmentStatus(appointment.status)} · ${formatAppointmentDate(appointment.starts_at)}`
              : "No appointment recorded",
            done: appointmentDone,
            blocked: ["cancelled", "no_show"].includes(appointment?.status || ""),
          },
          {
            title: "Staff assessment",
            detail: assessment
              ? `${assessmentOutcomeLabel(assessment.outcome)} · ${new Date(assessment.assessed_at).toLocaleDateString()}`
              : "Waiting for the shelter assessment record",
            done: assessmentDone && assessment?.outcome !== "not_approved",
            blocked: assessment?.outcome === "not_approved",
          },
          {
            title: "Adoption application",
            detail: application
              ? `${applicationStatusLabel(application.status)} · ${new Date(application.submitted_at || application.created_at).toLocaleDateString()}`
              : "Available after an eligible assessment",
            done: applicationDone,
            blocked: application?.status === "rejected",
          },
          {
            title: "Adoption completed",
            detail: adoptionDone
              ? `Adoption recorded · ${new Date(application?.updated_at || "").toLocaleDateString()}`
              : "Recorded after staff completes the adoption",
            done: adoptionDone,
            blocked: false,
          },
        ],
        progressValue: adoptionDone ? 1 : completedMilestones / 4,
      };
    })
    .sort((a, b) => {
      const aDate = [a.appointment?.created_at, a.application?.created_at]
        .filter((date): date is string => Boolean(date))
        .sort();
      const bDate = [b.appointment?.created_at, b.application?.created_at]
        .filter((date): date is string => Boolean(date))
        .sort();
      return (bDate[bDate.length - 1] || "").localeCompare(aDate[aDate.length - 1] || "");
    });
});

watch(section, async (currentSection) => {
  if (currentSection === "notifications") {
    notificationsLoading.value = true;
    notificationsError.value = "";
    notificationsError.value = (await refreshNotifications()) || "";
    notificationsLoading.value = false;
    return;
  }
  if (currentSection === "applications") {
    applicationsLoading.value = true;
    applicationsError.value = "";
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      applicationsError.value = userError?.message || "Sign in to view your applications.";
      applicationsLoading.value = false;
      return;
    }
    const { data, error } = await supabase
      .from("adoption_applications")
      .select("id, pet_id, status, created_at, review_notes, pet:pets(name)")
      .eq("applicant_id", userData.user.id)
      .order("created_at", { ascending: false });
    if (error) applicationsError.value = error.message;
    else applications.value = data || [];
    applicationsLoading.value = false;
    return;
  }
  if (currentSection !== "appointments" && currentSection !== "progress") return;
  if (currentSection === "progress") {
    progressLoading.value = true;
    progressError.value = "";
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      progressError.value = userError?.message || "Sign in to view your adoption progress.";
      progressLoading.value = false;
      return;
    }
    const [appointmentResult, applicationResult] = await Promise.all([
      supabase
        .from("appointments")
        .select("id, pet_id, starts_at, created_at, status, pet:pets(name, breed, pet_photos(storage_path, sort_order))")
        .eq("applicant_id", userData.user.id)
        .order("created_at", { ascending: false }),
      supabase
        .from("adoption_applications")
        .select("id, pet_id, status, created_at, submitted_at, updated_at, review_notes, pet:pets(name, breed, pet_photos(storage_path, sort_order))")
        .eq("applicant_id", userData.user.id)
        .order("created_at", { ascending: false }),
    ]);
    if (appointmentResult.error || applicationResult.error) {
      progressError.value = appointmentResult.error?.message ||
        applicationResult.error?.message || "Unable to load adoption progress.";
      progressLoading.value = false;
      return;
    }
    progressAppointments.value = appointmentResult.data || [];
    progressApplications.value = applicationResult.data || [];
    const appointmentIds = progressAppointments.value.map((row) => row.id);
    if (appointmentIds.length) {
      const { data, error } = await supabase
        .from("assessment_records")
        .select("appointment_id, outcome, assessed_at, recommendations")
        .in("appointment_id", appointmentIds);
      if (error) {
        progressError.value = error.message;
        progressLoading.value = false;
        return;
      }
      progressAssessments.value = data || [];
    } else {
      progressAssessments.value = [];
    }
    progressLoading.value = false;
    return;
  }
  if (currentSection !== "appointments") return;
  appointmentsLoading.value = true;
  appointmentsError.value = "";
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    appointmentsError.value = userError?.message || "Sign in to view your appointments.";
    appointmentsLoading.value = false;
    return;
  }
  const { data, error } = await supabase
    .from("appointments")
    .select("id, starts_at, location, status, pet:pets(name)")
    .eq("applicant_id", userData.user.id)
    .order("starts_at", { ascending: false });
  if (error) {
    appointmentsError.value = error.message;
  } else {
    const rows = data || [];
    const appointmentIds = rows.map((appointment) => appointment.id);
    const { data: assessments, error: assessmentError } = appointmentIds.length
      ? await supabase
          .from("assessment_records")
          .select("appointment_id, outcome, recommendations")
          .in("appointment_id", appointmentIds)
      : { data: [], error: null };
    if (assessmentError) appointmentsError.value = assessmentError.message;
    else {
      appointments.value = rows.map((appointment) => ({
        ...appointment,
        assessment: (assessments || []).find((item) => item.appointment_id === appointment.id) || null,
      }));
    }
  }
  appointmentsLoading.value = false;
}, { immediate: true });

const save = async () => {
  const { data } = await supabase.auth.getUser();
  if (!data.user) return;
  const { error } = await supabase
    .from("profiles")
    .update({ full_name: profile.value.name, phone: profile.value.phone })
    .eq("id", data.user.id);
  const toast = await toastController.create({
    message: error ? error.message : "Profile saved.",
    color: error ? "danger" : "success",
    duration: 2200,
  });
  await toast.present();
};
</script>

<template>
  <ion-page>
    <site-header />
    <ion-content id="main-content">
      <div class="portal-head">
        <div class="container">
          <div class="eyebrow">Adopter account</div>
          <h1>{{ title }}</h1>
        </div>
      </div>
      <div class="container portal-body">
        <template v-if="section === 'favorites'">
          <div v-if="favoritePets.length" class="pet-grid">
            <pet-card v-for="pet in favoritePets" :key="pet.id" :pet="pet" />
          </div>
          <div v-else class="empty surface">
            <ion-icon :icon="checkmarkCircleOutline" />
            <h2>No saved pets yet</h2>
            <p>Favorite a pet to keep their profile close while you consider the match.</p>
            <ion-button router-link="/pets">Browse pets</ion-button>
          </div>
        </template>

        <template v-else-if="section === 'profile'">
          <div class="form surface">
            <h2>Personal information</h2>
            <p>Only you and authorized staff can access this private information.</p>
            <ion-input v-model="profile.name" fill="outline" label="Full name" label-placement="stacked" />
            <ion-input v-model="profile.phone" fill="outline" label="Contact number" label-placement="stacked" />
            <ion-button @click="save()">Save profile</ion-button>
          </div>
        </template>

        <template v-else-if="section === 'appointments'">
          <div v-if="appointmentsLoading" class="empty surface">
            <p>Loading appointments...</p>
          </div>
          <div v-else-if="appointmentsError" class="empty surface">
            <h2>Appointments unavailable</h2>
            <p>{{ appointmentsError }}</p>
          </div>
          <ion-list v-else-if="appointments.length" class="surface adopter-appointments">
            <template v-for="appointment in appointments" :key="appointment.id">
              <ion-item>
                <ion-label>
                  <strong>{{ appointment.pet?.name || "Assessment appointment" }}</strong>
                  <p>{{ formatAppointmentDate(appointment.starts_at) }} · {{ appointment.location }}</p>
                  <p>Appointment status: {{ formatAppointmentStatus(appointment.status) }}</p>
                </ion-label>
                <ion-badge slot="end" :color="appointmentStatusColor(appointment.status)">
                  {{ formatAppointmentStatus(appointment.status) }}
                </ion-badge>
              </ion-item>
              <div
                v-if="appointment.assessment"
                class="assessment-feedback"
                :class="{ denied: appointment.assessment.outcome === 'not_approved' }"
              >
                <strong>Assessment result: {{ assessmentOutcomeLabel(appointment.assessment.outcome) }}</strong>
                <p>{{ appointment.assessment.recommendations || "No additional comment was provided." }}</p>
              </div>
            </template>
          </ion-list>
          <div v-else class="empty surface">
            <ion-icon :icon="calendarClearOutline" />
            <h2>No appointments booked</h2>
            <p>Choose an available pet, then request a physical assessment time.</p>
            <ion-button router-link="/pets">Browse pets</ion-button>
          </div>
        </template>

        <template v-else-if="section === 'progress'">
          <div v-if="progressLoading" class="empty surface">
            <p>Loading adoption progress...</p>
          </div>
          <div v-else-if="progressError" class="empty surface">
            <h2>Adoption progress unavailable</h2>
            <p>{{ progressError }}</p>
          </div>
          <div v-else-if="adoptionProgress.length" class="adoption-progress-list">
            <section
              v-for="item in adoptionProgress"
              :key="item.petId"
              class="progress-card surface"
            >
              <header class="progress-card-header">
                <div class="progress-pet">
                  <img
                    :src="item.pet?.image || '/favicon.svg'"
                    :alt="item.pet ? `${item.pet.name}, ${item.pet.breed}` : 'Assessed pet'"
                  />
                  <div>
                    <div class="eyebrow">Your adoption journey</div>
                    <h2>{{ item.pet?.name || "Your appointed pet" }}</h2>
                    <p>{{ item.pet?.breed || "Pet details" }}</p>
                    <ion-button
                      v-if="item.pet"
                      fill="clear"
                      size="small"
                      :router-link="`/pets/${item.petId}`"
                    >
                      View pet profile
                    </ion-button>
                  </div>
                </div>
                <ion-badge :color="item.milestones.some((milestone) => milestone.blocked) ? 'danger' : item.progressValue === 1 ? 'success' : 'primary'">
                  {{ item.progressValue === 1 ? "Adoption completed" : "In progress" }}
                </ion-badge>
              </header>
              <ion-progress-bar :value="item.progressValue" />
              <ol class="progress-milestones">
                <li
                  v-for="milestone in item.milestones"
                  :key="milestone.title"
                  :class="{ complete: milestone.done, blocked: milestone.blocked }"
                >
                  <span class="milestone-marker" aria-hidden="true" />
                  <div>
                    <strong>{{ milestone.title }}</strong>
                    <p>{{ milestone.detail }}</p>
                  </div>
                </li>
              </ol>
              <div v-if="item.assessment?.recommendations" class="assessment-feedback">
                <strong>Assessment update</strong>
                <p>{{ item.assessment.recommendations }}</p>
              </div>
              <div v-if="item.application?.review_notes" class="assessment-feedback">
                <strong>Application update</strong>
                <p>{{ item.application.review_notes }}</p>
              </div>
            </section>
          </div>
          <div v-else class="empty surface">
            <ion-icon :icon="calendarClearOutline" />
            <h2>No adoption progress yet</h2>
            <p>Once you book an assessment for a pet, its appointment, assessment, and adoption application milestones will appear here.</p>
            <ion-button router-link="/pets">Browse pets</ion-button>
          </div>
        </template>

        <template v-else-if="section === 'applications'">
          <div v-if="applicationsLoading" class="empty surface"><p>Loading applications...</p></div>
          <div v-else-if="applicationsError" class="empty surface">
            <h2>Applications unavailable</h2>
            <p>{{ applicationsError }}</p>
          </div>
          <ion-list v-else-if="applications.length" class="surface adopter-appointments">
            <template v-for="application in applications" :key="application.id">
              <ion-item>
                <ion-label>
                  <strong>{{ application.pet?.name || "Adoption application" }}</strong>
                  <p>Submitted {{ new Date(application.created_at).toLocaleDateString() }}</p>
                </ion-label>
                <ion-badge slot="end" :color="application.status === 'approved' ? 'success' : application.status === 'rejected' ? 'danger' : 'warning'">
                  {{ applicationStatusLabel(application.status) }}
                </ion-badge>
              </ion-item>
              <div v-if="application.status === 'rejected'" class="assessment-feedback denied">
                <strong>Why it was declined</strong>
                <p>{{ application.review_notes || "No reason was provided." }}</p>
                <ion-button fill="outline" size="small" :router-link="`/applications/new/${application.pet_id}`">
                  Correct and apply again
                </ion-button>
              </div>
            </template>
          </ion-list>
          <div v-else class="empty surface">
            <ion-icon :icon="documentTextOutline" />
            <h2>No applications yet</h2>
            <p>After an eligible assessment, you can submit an adoption application for that pet.</p>
            <ion-button router-link="/pets">Browse pets</ion-button>
          </div>
        </template>

        <template v-else-if="section === 'notifications'">
          <div v-if="notificationsLoading" class="empty surface">
            <ion-progress-bar type="indeterminate" />
            <p>Loading your activity...</p>
          </div>
          <div v-else-if="notificationsError" class="empty surface" role="alert">
            <h2>Unable to load activity</h2>
            <p>{{ notificationsError }}</p>
          </div>
          <ion-list v-else-if="state.notifications.length" class="surface">
            <ion-item
              v-for="notice in state.notifications"
              :key="notice.id"
              button
              :router-link="notice.link"
              @click="markNotificationRead(notice.id)"
            >
              <ion-icon slot="start" :icon="notificationsOutline" :color="notice.read ? 'medium' : 'primary'" />
              <ion-label><strong>{{ notice.title }} · {{ notice.read ? "Read" : "New" }}</strong><p>{{ notice.text }}</p></ion-label>
            </ion-item>
          </ion-list>
          <div v-else class="empty surface">
            <ion-icon :icon="notificationsOutline" />
            <h2>No activity yet</h2>
            <p>Updates about your assessment, adoption application, and fundraising donations will appear here.</p>
          </div>
          <ion-button
            v-if="!notificationsLoading && !notificationsError && state.notifications.some((item) => !item.read)"
            fill="outline"
            @click="markAllNotificationsRead"
          >
            Mark all as read
          </ion-button>
        </template>

        <template v-else>
          <div class="empty surface">
            <ion-icon :icon="section === 'donations' ? walletOutline : documentTextOutline" />
            <h2>{{ section === "donations" ? "No confirmed donations" : "No applications yet" }}</h2>
            <p v-if="section === 'donations'">Confirmed provider payments and authorized offline donations will appear here with references.</p>
            <p v-else>Applications become available only after staff marks your assessment eligible to proceed.</p>
            <ion-button :router-link="section === 'donations' ? '/fundraising' : '/pets'">
              {{ section === "donations" ? "View campaigns" : "Browse pets" }}
            </ion-button>
          </div>
          <div v-if="route.params.id" class="surface status-history">
            <h2>Application status history</h2>
            <ion-list>
              <ion-item>
                <ion-icon slot="start" :icon="personOutline" />
                <ion-label><strong>Draft</strong><p>Not submitted · Assessment required first</p></ion-label>
              </ion-item>
            </ion-list>
          </div>
        </template>
      </div>
    </ion-content>
  </ion-page>
</template>

<style scoped>
.portal-head {
  padding: 48px 0;
  background: var(--cream);
}

.portal-head h1 {
  margin: 7px 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 2.8rem;
}

.portal-body {
  min-height: 540px;
  padding-block: 42px 80px;
}

.pet-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;
}

.empty {
  max-width: 760px;
  margin: 0 auto;
  padding: 70px 30px;
  text-align: center;
}

.empty > ion-icon {
  color: var(--ion-color-primary);
  font-size: 3rem;
}

.empty h2,
.form h2,
.status-history h2 {
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.8rem;
}

.empty p,
.form p {
  color: var(--ink-muted);
}

.form {
  display: grid;
  max-width: 720px;
  gap: 14px;
  padding: 30px;
}

.status-history {
  max-width: 760px;
  margin: 22px auto;
  padding: 26px;
}

.adoption-progress-list {
  display: grid;
  gap: 22px;
}

.progress-card {
  padding: 24px;
}

.progress-card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
  margin-bottom: 18px;
}

.progress-card-header h2 {
  margin: 4px 0 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.8rem;
}

.progress-card-header p {
  margin: 2px 0;
  color: var(--ink-muted);
}

.progress-pet {
  display: flex;
  align-items: center;
  gap: 16px;
}

.progress-pet img {
  width: 96px;
  height: 96px;
  flex: 0 0 96px;
  border-radius: 16px;
  background: var(--cream);
  object-fit: cover;
}

.progress-pet ion-button {
  margin: 2px 0 0 -12px;
}

.progress-card ion-progress-bar {
  height: 9px;
  border-radius: 99px;
}

.progress-milestones {
  display: grid;
  gap: 0;
  margin: 22px 0 0;
  padding: 0;
  list-style: none;
}

.progress-milestones li {
  position: relative;
  display: flex;
  gap: 14px;
  min-height: 65px;
  color: var(--ink-muted);
}

.progress-milestones li:not(:last-child)::before {
  position: absolute;
  top: 18px;
  bottom: -1px;
  left: 7px;
  width: 2px;
  background: var(--border);
  content: "";
}

.milestone-marker {
  z-index: 1;
  width: 16px;
  height: 16px;
  flex: 0 0 16px;
  border: 2px solid #c9c3ba;
  border-radius: 50%;
  background: white;
}

.progress-milestones li.complete .milestone-marker {
  border-color: var(--ion-color-success);
  background: var(--ion-color-success);
}

.progress-milestones li.blocked .milestone-marker {
  border-color: var(--ion-color-danger);
  background: var(--ion-color-danger);
}

.progress-milestones strong {
  color: var(--ion-color-secondary);
}

.progress-milestones p {
  margin: 4px 0 18px;
  line-height: 1.45;
}

.adopter-appointments ion-item {
  --padding-start: 22px;
  --inner-padding-end: 22px;
}

.assessment-feedback {
  margin: 0 16px 14px;
  border-left: 3px solid var(--ion-color-success);
  background: #f0f6ed;
  padding: 14px 16px;
  color: #3e5d37;
}

.assessment-feedback.denied {
  border-left-color: var(--ion-color-danger);
  background: #fff0ed;
  color: #8e3825;
}

.assessment-feedback p {
  margin: 6px 0 0;
  line-height: 1.5;
}

@media (max-width: 750px) {
  .pet-grid {
    grid-template-columns: 1fr;
  }

  .progress-card-header {
    flex-direction: column;
  }
}
</style>
