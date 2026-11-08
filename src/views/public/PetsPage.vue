<script setup lang="ts">
import { computed, ref } from "vue";
import {
  IonContent,
  IonIcon,
  IonInput,
  IonPage,
  IonSelect,
  IonSelectOption,
} from "@ionic/vue";
import { searchOutline } from "ionicons/icons";
import SiteHeader from "@/components/SiteHeader.vue";
import SiteFooter from "@/components/SiteFooter.vue";
import PetCard from "@/components/PetCard.vue";
import { pets } from "@/services/catalog";

const search = ref("");
const species = ref("All");
const age = ref("All");
const gender = ref("All");
const size = ref("All");
const location = ref("All");
const health = ref("All");
const availability = ref("Available");
const sort = ref("Featured");

const filteredPets = computed(() => {
  const result = pets.filter((pet) => {
    const query = search.value.toLowerCase();
    return (
      (!query ||
        `${pet.name} ${pet.breed} ${pet.location}`.toLowerCase().includes(query)) &&
      (species.value === "All" || pet.species === species.value) &&
      (age.value === "All" || pet.ageGroup === age.value) &&
      (gender.value === "All" || pet.gender === gender.value) &&
      (size.value === "All" || pet.size === size.value) &&
      (location.value === "All" || pet.location === location.value) &&
      (health.value === "All" || pet.health === health.value) &&
      (availability.value === "All" || pet.status === availability.value)
    );
  });
  return [...result].sort((a, b) =>
    sort.value === "Name" ? a.name.localeCompare(b.name) : 0,
  );
});
</script>

<template>
  <ion-page>
    <site-header />
    <ion-content id="main-content">
      <section class="listing-hero">
        <div class="container">
          <div class="eyebrow">Find your new companion</div>
          <h1 class="section-title">Rescued pets, ready to be loved.</h1>
          <p class="lead">Search verified profiles and find a pet who fits your home and heart.</p>
        </div>
      </section>
      <section class="container listing">
        <div class="filters surface">
          <ion-input v-model="search" fill="outline" label="Search" label-placement="stacked" placeholder="Name, breed, or shelter">
            <ion-icon slot="start" :icon="searchOutline" />
          </ion-input>
          <ion-select v-model="species" fill="outline" label="Species" label-placement="stacked">
            <ion-select-option v-for="value in ['All', 'Dog', 'Cat']" :key="value" :value="value">{{ value }}</ion-select-option>
          </ion-select>
          <ion-select v-model="age" fill="outline" label="Age" label-placement="stacked">
            <ion-select-option v-for="value in ['All', 'Young', 'Adult', 'Senior']" :key="value" :value="value">{{ value }}</ion-select-option>
          </ion-select>
          <ion-select v-model="gender" fill="outline" label="Gender" label-placement="stacked">
            <ion-select-option v-for="value in ['All', 'Female', 'Male']" :key="value" :value="value">{{ value }}</ion-select-option>
          </ion-select>
          <ion-select v-model="size" fill="outline" label="Size" label-placement="stacked">
            <ion-select-option v-for="value in ['All', 'Small', 'Medium', 'Large']" :key="value" :value="value">{{ value }}</ion-select-option>
          </ion-select>
          <ion-select v-model="location" fill="outline" label="Location" label-placement="stacked">
            <ion-select-option v-for="value in ['All', 'Greenfield Rescue', 'Riverside Shelter', 'Northside Foster']" :key="value" :value="value">{{ value }}</ion-select-option>
          </ion-select>
          <ion-select v-model="health" fill="outline" label="Health" label-placement="stacked">
            <ion-select-option v-for="value in ['All', 'Vaccinated', 'Special care']" :key="value" :value="value">{{ value }}</ion-select-option>
          </ion-select>
          <ion-select v-model="availability" fill="outline" label="Availability" label-placement="stacked">
            <ion-select-option v-for="value in ['All', 'Available', 'On hold', 'Adopted']" :key="value" :value="value">{{ value }}</ion-select-option>
          </ion-select>
        </div>
        <div class="result-head">
          <span><strong>{{ filteredPets.length }}</strong> pets found</span>
          <ion-select v-model="sort" interface="popover" label="Sort by">
            <ion-select-option value="Featured">Featured</ion-select-option>
            <ion-select-option value="Name">Name</ion-select-option>
          </ion-select>
        </div>
        <div v-if="filteredPets.length" class="pet-grid">
          <pet-card v-for="pet in filteredPets" :key="pet.id" :pet="pet" />
        </div>
        <div v-else class="empty surface">
          <h2>No pets match these filters</h2>
          <p>Try widening your search. New rescued pets are added regularly.</p>
        </div>
      </section>
      <site-footer />
    </ion-content>
  </ion-page>
</template>

<style scoped>
.listing-hero {
  padding: 64px 0;
  background: var(--cream);
  text-align: center;
}

.listing-hero .lead {
  margin-bottom: 0;
}

.listing {
  padding-block: 40px 80px;
}

.filters {
  display: grid;
  grid-template-columns: 2fr repeat(4, 1fr);
  gap: 14px;
  margin-top: -72px;
  padding: 22px;
}

.filters ion-select:nth-last-child(-n + 3) {
  display: none;
}

.result-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 28px 4px 18px;
  color: var(--ink-muted);
}

.pet-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;
}

.empty {
  padding: 60px;
  text-align: center;
}

@media (max-width: 900px) {
  .filters {
    grid-template-columns: 1fr 1fr;
    margin-top: -55px;
  }

  .pet-grid {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 580px) {
  .filters,
  .pet-grid {
    grid-template-columns: 1fr;
  }
}
</style>
