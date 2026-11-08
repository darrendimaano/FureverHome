<script setup lang="ts">
import { IonButton, IonCard, IonCardContent, IonChip, IonIcon } from "@ionic/vue";
import {
  femaleOutline,
  heart,
  heartOutline,
  locationOutline,
  maleOutline,
  shieldCheckmarkOutline,
} from "ionicons/icons";
import type { Pet } from "@/types";
import { useAppState } from "@/composables/useAppState";
import { useFavoriteAction } from "@/composables/useFavoriteAction";

defineProps<{ pet: Pet }>();
const { state } = useAppState();
const { handleFavorite } = useFavoriteAction();
</script>

<template>
  <ion-card class="pet-card">
    <div class="photo-wrap">
      <img :src="pet.image" :alt="`${pet.name}, a rescued ${pet.breed}`" />
      <ion-button
        class="favorite"
        fill="solid"
        color="light"
        :aria-label="`Favorite ${pet.name}`"
        @click="handleFavorite(pet.id)"
      >
        <ion-icon
          slot="icon-only"
          :color="state.favorites.has(pet.id) ? 'primary' : 'medium'"
          :icon="state.favorites.has(pet.id) ? heart : heartOutline"
        />
      </ion-button>
      <span class="availability">{{ pet.status }}</span>
    </div>
    <ion-card-content>
      <div class="pet-heading">
        <div>
          <small>{{ pet.species }} · {{ pet.breed }}</small>
          <h3>{{ pet.name }}</h3>
        </div>
        <ion-icon :icon="pet.gender === 'Female' ? femaleOutline : maleOutline" />
      </div>
      <div class="chips">
        <ion-chip>{{ pet.age }}</ion-chip>
        <ion-chip>{{ pet.size }}</ion-chip>
        <ion-chip color="tertiary">
          <ion-icon :icon="shieldCheckmarkOutline" />
          {{ pet.health }}
        </ion-chip>
      </div>
      <p class="location"><ion-icon :icon="locationOutline" /> {{ pet.location }}</p>
      <ion-button expand="block" :router-link="`/pets/${pet.id}`">Meet {{ pet.name }}</ion-button>
    </ion-card-content>
  </ion-card>
</template>

<style scoped>
.pet-card {
  overflow: hidden;
  transition: transform 180ms ease, box-shadow 180ms ease;
}

.pet-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow);
}

.photo-wrap {
  position: relative;
  aspect-ratio: 1.15;
  overflow: hidden;
  background: var(--cream);
}

.photo-wrap img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.favorite {
  position: absolute;
  top: 12px;
  right: 12px;
  width: 40px;
  height: 40px;
  margin: 0;
  --border-radius: 50%;
  --box-shadow: 0 5px 16px rgba(47, 38, 34, 0.14);
}

.availability {
  position: absolute;
  bottom: 12px;
  left: 12px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.92);
  padding: 7px 11px;
  color: #406039;
  font-size: 0.75rem;
  font-weight: 800;
}

.pet-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.pet-heading small {
  color: var(--ink-muted);
}

h3 {
  margin: 4px 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.65rem;
}

.chips {
  display: flex;
  flex-wrap: wrap;
  margin: 12px -6px 8px;
}

ion-chip {
  height: 28px;
  font-size: 0.73rem;
}

.location {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--ink-muted);
  font-size: 0.85rem;
}
</style>
