<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import {
  IonButton,
  IonCheckbox,
  IonContent,
  IonInput,
  IonPage,
  IonSelect,
  IonSelectOption,
  IonTextarea,
  toastController,
} from "@ionic/vue";
import SiteHeader from "@/components/SiteHeader.vue";
import { pets } from "@/services/catalog";
import { supabase } from "@/services/supabase";

const route = useRoute();
const router = useRouter();
const pet = computed(() => pets.find((item) => item.id === route.params.petId) || pets[0]);
const loading = ref(true);
const submitting = ref(false);
const eligibleAssessmentId = ref("");
const alreadySubmitted = ref(false);
const previouslyRejected = ref(false);
const previousReviewNotes = ref("");
const form = reactive({
  fullName: "",
  phone: "",
  email: "",
  address: "",
  household: "",
  residenceType: "",
  landlordPermission: false,
  existingPets: "",
  petExperience: "",
  hoursAlone: "",
  reason: "",
  emergencyContact: "",
  agreementAccepted: false,
});

const loadApplicationContext = async () => {
  loading.value = true;
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    await router.replace("/login");
    return;
  }

  form.email = authData.user.email || "";
  const { data: profile } = await supabase
    .from("profiles")
    .select("full_name, phone")
    .eq("id", authData.user.id)
    .maybeSingle();
  form.fullName = profile?.full_name || String(authData.user.user_metadata.full_name || "");
  form.phone = profile?.phone || "";

  const { data: assessment, error: assessmentError } = await supabase
    .from("assessment_records")
    .select("id, appointment:appointments!inner(pet_id)")
    .eq("applicant_id", authData.user.id)
    .eq("outcome", "approved_to_proceed")
    .eq("appointment.pet_id", pet.value.id)
    .limit(1)
    .maybeSingle();
  if (assessmentError || !assessment) {
    const toast = await toastController.create({
      message: "An eligible assessment for this pet is required before applying.",
      color: "warning",
      duration: 3000,
    });
    await toast.present();
    await router.replace(`/pets/${pet.value.id}`);
    return;
  }
  eligibleAssessmentId.value = assessment.id;

  const { data: existingApplication } = await supabase
    .from("adoption_applications")
    .select("id, status, review_notes")
    .eq("applicant_id", authData.user.id)
    .eq("pet_id", pet.value.id)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  previouslyRejected.value = existingApplication?.status === "rejected";
  previousReviewNotes.value = existingApplication?.review_notes || "";
  alreadySubmitted.value = Boolean(existingApplication && existingApplication.status !== "rejected");
  loading.value = false;
};

const submitApplication = async () => {
  if (
    !form.fullName.trim() ||
    !form.phone.trim() ||
    !form.email.trim() ||
    !form.address.trim() ||
    !form.household.trim() ||
    !form.residenceType ||
    !form.petExperience.trim() ||
    !form.hoursAlone.trim() ||
    !form.reason.trim() ||
    !form.emergencyContact.trim() ||
    !form.agreementAccepted
  ) {
    const toast = await toastController.create({
      message: "Complete all required fields and accept the adoption agreement.",
      color: "danger",
      duration: 2800,
    });
    return toast.present();
  }

  submitting.value = true;
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    submitting.value = false;
    const toast = await toastController.create({ message: "Sign in again to submit your application.", color: "danger", duration: 2600 });
    return toast.present();
  }

  const { error } = await supabase.from("adoption_applications").insert({
    applicant_id: authData.user.id,
    pet_id: pet.value.id,
    assessment_id: eligibleAssessmentId.value,
    status: "under_review",
    form_data: {
      full_name: form.fullName.trim(),
      phone: form.phone.trim(),
      email: form.email.trim(),
      address: form.address.trim(),
      household: form.household.trim(),
      residence_type: form.residenceType,
      landlord_permission: form.landlordPermission,
      existing_pets: form.existingPets.trim(),
      pet_experience: form.petExperience.trim(),
      hours_alone: form.hoursAlone.trim(),
      reason: form.reason.trim(),
      emergency_contact: form.emergencyContact.trim(),
    },
    agreement_accepted_at: new Date().toISOString(),
    submitted_at: new Date().toISOString(),
  });
  submitting.value = false;

  const toast = await toastController.create({
    message: error ? error.message : "Adoption application submitted for review.",
    color: error ? "danger" : "success",
    duration: 2800,
  });
  await toast.present();
  if (!error) await router.push("/applications");
};

onMounted(loadApplicationContext);
</script>

<template>
  <ion-page>
    <site-header />
    <ion-content id="main-content">
      <div class="application-page container">
        <div class="application-heading">
          <div class="eyebrow">Adoption application</div>
          <h1>Tell us about your home for {{ pet.name }}.</h1>
          <p>Your assessment is eligible to proceed. Shelter staff will review this application before making a decision.</p>
        </div>

        <div v-if="loading" class="application-state surface">Checking your assessment...</div>
        <div v-else-if="alreadySubmitted" class="application-state surface">
          <h2>Application already submitted</h2>
          <p>You already have an application for {{ pet.name }}.</p>
          <ion-button router-link="/applications">View applications</ion-button>
        </div>
        <form v-else class="application-form surface" @submit.prevent="submitApplication">
          <h2>Applicant information</h2>
          <div v-if="previouslyRejected" class="resubmission-note">
            <strong>Your previous application was declined.</strong>
            <p>{{ previousReviewNotes || "No reason was provided." }}</p>
            <span>Update your answers below, then submit a corrected application for review.</span>
          </div>
          <div class="application-grid">
            <ion-input v-model="form.fullName" fill="outline" label="Full name *" label-placement="stacked" />
            <ion-input v-model="form.phone" fill="outline" label="Contact number *" label-placement="stacked" />
            <ion-input v-model="form.email" type="email" fill="outline" label="Email *" label-placement="stacked" />
            <ion-input v-model="form.emergencyContact" fill="outline" label="Emergency contact *" label-placement="stacked" />
          </div>
          <ion-input v-model="form.address" fill="outline" label="Home address *" label-placement="stacked" />
          <ion-textarea v-model="form.household" fill="outline" label="Household members and ages *" label-placement="stacked" :auto-grow="true" />
          <ion-select v-model="form.residenceType" fill="outline" label="Residence type *" label-placement="stacked">
            <ion-select-option value="owned_house">Owned house</ion-select-option>
            <ion-select-option value="rented_house">Rented house</ion-select-option>
            <ion-select-option value="apartment">Apartment or condo</ion-select-option>
          </ion-select>
          <ion-checkbox v-if="form.residenceType !== 'owned_house'" v-model="form.landlordPermission" label-placement="end">
            I have permission to keep a pet at this residence.
          </ion-checkbox>
          <ion-textarea v-model="form.existingPets" fill="outline" label="Other pets in the home" label-placement="stacked" :auto-grow="true" />
          <ion-textarea v-model="form.petExperience" fill="outline" label="Pet care experience *" label-placement="stacked" :auto-grow="true" />
          <ion-input v-model="form.hoursAlone" fill="outline" label="How many hours will the pet be alone on a typical day? *" label-placement="stacked" />
          <ion-textarea v-model="form.reason" fill="outline" label="Why would you like to adopt this pet? *" label-placement="stacked" :auto-grow="true" />
          <ion-checkbox v-model="form.agreementAccepted" label-placement="end">
            I confirm that the information is accurate and agree to a home-readiness review.
          </ion-checkbox>
          <ion-button type="submit" expand="block" size="large" :disabled="submitting">
            {{ submitting ? "Submitting..." : "Submit adoption application" }}
          </ion-button>
        </form>
      </div>
    </ion-content>
  </ion-page>
</template>

<style scoped>
.application-page {
  max-width: 900px;
  padding-block: 48px 80px;
}

.application-heading {
  max-width: 680px;
  margin-bottom: 28px;
}

.application-heading h1 {
  margin: 8px 0 12px;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 2.6rem;
}

.application-heading p,
.application-state p {
  color: var(--ink-muted);
  line-height: 1.6;
}

.application-form {
  display: grid;
  gap: 18px;
  padding: 28px;
}

.application-form h2,
.application-state h2 {
  margin: 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
}

.application-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.application-state {
  padding: 32px;
}

.resubmission-note {
  border-left: 3px solid var(--ion-color-danger);
  background: #fff0ed;
  padding: 14px 16px;
  color: #8e3825;
}

.resubmission-note p {
  margin: 7px 0;
  line-height: 1.5;
}

.resubmission-note span {
  font-size: 0.88rem;
}

@media (max-width: 640px) {
  .application-heading h1 {
    font-size: 2rem;
  }

  .application-form {
    padding: 20px 16px;
  }

  .application-grid {
    grid-template-columns: 1fr;
  }
}
</style>
