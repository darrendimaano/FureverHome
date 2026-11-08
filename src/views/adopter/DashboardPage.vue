<script setup lang="ts">
import { onMounted, ref } from "vue";
import { IonButton, IonCard, IonCardContent, IonContent, IonIcon, IonPage } from "@ionic/vue";
import { documentTextOutline, heartOutline, timeOutline } from "ionicons/icons";
import SiteHeader from "@/components/SiteHeader.vue";
import PetCard from "@/components/PetCard.vue";
import { useAppState } from "@/composables/useAppState";
import { pets } from "@/services/catalog";
import { supabase } from "@/services/supabase";

const { state, favoritePets } = useAppState();
const applicationsCount = ref<number | null>(null);

onMounted(async () => {
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    applicationsCount.value = 0;
    return;
  }

  const { count, error } = await supabase
    .from("adoption_applications")
    .select("id", { count: "exact", head: true })
    .eq("applicant_id", userData.user.id);
  applicationsCount.value = error ? 0 : count || 0;
});
</script>

<template>
  <ion-page>
    <site-header />
    <ion-content id="main-content">
      <div class="container dashboard">
        <div class="dash-head">
          <div>
            <div class="eyebrow">Adopter dashboard</div>
            <h1>Welcome, {{ state.userName || "friend" }}.</h1>
            <p>Here is what comes next in your adoption journey.</p>
          </div>
          <ion-button router-link="/pets">Find a pet</ion-button>
        </div>
        <div class="status surface">
          <div class="status-icon"><ion-icon :icon="timeOutline" /></div>
          <div>
            <small>Current eligibility</small>
            <h2>Appointment required</h2>
            <p>Book and attend a physical assessment before starting a final application.</p>
          </div>
          <ion-button fill="outline" router-link="/pets">Choose a pet</ion-button>
        </div>
        <div class="metric-grid">
          <ion-card v-for="metric in [
            [heartOutline, 'Favorites', state.favorites.size, '/favorites'],
            [documentTextOutline, 'Applications', applicationsCount ?? '…', '/applications'],
          ]" :key="String(metric[1])" :router-link="String(metric[3])">
            <ion-card-content>
              <ion-icon :icon="metric[0]" />
              <strong>{{ metric[2] }}</strong>
              <span>{{ metric[1] }}</span>
            </ion-card-content>
          </ion-card>
        </div>
        <div class="progress surface">
          <div>
            <div class="eyebrow">Adoption progress</div>
            <h2>Follow each pet's milestones</h2>
            <p>Appointments, assessments, applications, and completed adoptions are tracked from your records.</p>
          </div>
          <ion-button fill="outline" router-link="/progress">View progress</ion-button>
        </div>
        <div class="section-heading">
          <h2>{{ favoritePets.length ? "Your favorite pets" : "Pets you may love" }}</h2>
          <ion-button fill="clear" router-link="/favorites">View favorites</ion-button>
        </div>
        <div class="favorites">
          <pet-card v-for="pet in (favoritePets.length ? favoritePets : pets.slice(0, 3))" :key="pet.id" :pet="pet" />
        </div>
      </div>
    </ion-content>
  </ion-page>
</template>

<style scoped>
.dashboard {
  padding-block: 50px 80px;
}

.dash-head,
.status,
.metric-grid,
.section-heading {
  display: flex;
  align-items: center;
}

.dash-head,
.section-heading {
  justify-content: space-between;
}

.dash-head h1 {
  margin: 6px 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 2.8rem;
}

.dash-head p,
.status p {
  color: var(--ink-muted);
}

.status {
  gap: 20px;
  margin: 34px 0 24px;
  padding: 24px;
}

.status > div:nth-child(2) {
  flex: 1;
}

.status h2 {
  margin: 3px 0;
  color: var(--ion-color-secondary);
}

.status-icon {
  display: grid;
  width: 56px;
  height: 56px;
  place-items: center;
  border-radius: 18px;
  background: #fff0dd;
  color: var(--ion-color-primary);
  font-size: 1.6rem;
}

.metric-grid {
  gap: 20px;
}

.metric-grid ion-card {
  flex: 1;
  cursor: pointer;
}

.metric-grid ion-card-content {
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: center;
  gap: 4px 14px;
}

.metric-grid ion-icon {
  grid-row: span 2;
  color: var(--ion-color-primary);
  font-size: 1.8rem;
}

.metric-grid strong {
  font-size: 1.6rem;
}

.metric-grid span {
  color: var(--ink-muted);
}

.progress {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  margin: 24px 0 46px;
  padding: 28px;
}

.progress h2 {
  margin-bottom: 6px;
  color: var(--ion-color-secondary);
}

.progress p {
  margin: 0;
  color: var(--ink-muted);
}

.favorites {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 22px;
}

@media (max-width: 720px) {
  .dash-head,
  .status,
  .metric-grid {
    align-items: flex-start;
    flex-direction: column;
  }

  .metric-grid ion-card,
  .favorites {
    width: 100%;
  }

  .favorites {
    grid-template-columns: 1fr;
  }
}
</style>
