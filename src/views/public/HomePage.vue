<script setup lang="ts">
import {
  IonButton,
  IonContent,
  IonIcon,
  IonPage,
  IonProgressBar,
} from "@ionic/vue";
import {
  arrowForward,
  calendarClearOutline,
  checkmarkCircle,
  heartOutline,
  playCircleOutline,
  searchOutline,
} from "ionicons/icons";
import SiteHeader from "@/components/SiteHeader.vue";
import SiteFooter from "@/components/SiteFooter.vue";
import PetCard from "@/components/PetCard.vue";
import { adoptionStories, campaigns, pets } from "@/services/catalog";
</script>

<template>
  <ion-page>
    <site-header />
    <ion-content id="main-content">
      <section class="hero">
        <div class="container hero-grid">
          <div class="hero-copy">
            <div class="eyebrow">Responsible adoption starts here</div>
            <h1>Every Paw Deserves a <em>Home.</em></h1>
            <p class="lead">
              Meet rescued cats and dogs through verified care records, real behavior videos,
              and a thoughtful in-person assessment process.
            </p>
            <div class="hero-actions">
              <ion-button size="large" router-link="/pets">
                Browse pets <ion-icon slot="end" :icon="arrowForward" />
              </ion-button>
              <ion-button size="large" fill="outline" router-link="/fundraising">
                Support our mission
              </ion-button>
            </div>
            <div class="trust-row">
              <span><ion-icon :icon="checkmarkCircle" /> Verified records</span>
              <span><ion-icon :icon="checkmarkCircle" /> Guided matching</span>
            </div>
          </div>
          <div class="hero-image">
            <img
              src="https://images.unsplash.com/photo-1642625932641-3a52ad27e268?auto=format&fit=crop&w=1400&q=85"
              alt="A rescued cat and dog looking out of a window together"
            />
            <div class="match-card">
              <span class="match-icon"><ion-icon :icon="heartOutline" /></span>
              <div><strong>Thoughtful matches</strong><small>Care beyond adoption day</small></div>
            </div>
          </div>
        </div>
      </section>

      <section class="section">
        <div class="container">
          <div class="section-heading">
            <div>
              <div class="eyebrow">Waiting to meet you</div>
              <h2 class="section-title">Featured rescued pets</h2>
            </div>
            <ion-button fill="clear" router-link="/pets">
              View all pets <ion-icon slot="end" :icon="arrowForward" />
            </ion-button>
          </div>
          <div v-if="pets.length" class="grid grid-3">
            <pet-card v-for="pet in pets.slice(0, 3)" :key="pet.id" :pet="pet" />
          </div>
          <div v-else class="empty-state surface">
            No published pets are available yet. Authorized staff can add pets from the dashboard.
          </div>
        </div>
      </section>

      <section v-if="adoptionStories.length" class="section adoption-stories">
        <div class="container">
          <div class="section-heading">
            <div>
              <div class="eyebrow">Happy homecomings</div>
              <h2 class="section-title">Adopted with love</h2>
            </div>
          </div>
          <div class="adoption-story-grid">
            <article v-for="story in adoptionStories.slice(0, 3)" :key="story.id" class="adoption-story surface">
              <img :src="story.image" :alt="story.petName" />
              <div class="adoption-story-copy">
                <div class="eyebrow">{{ story.species }} · Adopted {{ story.completedAt }}</div>
                <h3>{{ story.petName }}</h3>
                <p>Found a home with <strong>{{ story.adopterDisplayName }}</strong></p>
              </div>
            </article>
          </div>
        </div>
      </section>

      <section class="section process">
        <div class="container">
          <div class="center-heading">
            <div class="eyebrow">A careful, caring process</div>
            <h2 class="section-title">How adoption works</h2>
            <p class="lead">A transparent path designed around the wellbeing of every pet.</p>
          </div>
          <div class="steps">
            <div v-for="(step, index) in [
              { icon: searchOutline, title: 'Find your match', text: 'Explore pet profiles, care details, and behavior evidence.' },
              { icon: playCircleOutline, title: 'See their real self', text: 'Watch staff-reviewed videos and read verified health records.' },
              { icon: calendarClearOutline, title: 'Meet in person', text: 'Book the required assessment with our shelter team.' },
              { icon: heartOutline, title: 'Begin together', text: 'Apply after eligibility review and complete adoption documents.' },
            ]" :key="step.title" class="step">
              <div class="step-icon"><ion-icon :icon="step.icon" /><span>0{{ index + 1 }}</span></div>
              <h3>{{ step.title }}</h3>
              <p>{{ step.text }}</p>
            </div>
          </div>
        </div>
      </section>

      <section class="section evidence">
        <div class="container evidence-grid">
          <div class="video-still">
            <img
              src="https://images.unsplash.com/photo-1653356162049-8cbf63358e87?auto=format&fit=crop&w=1200&q=82"
              alt="Rescued dog looking toward the camera"
            />
            <ion-button
              aria-label="View pet behavior videos"
              :router-link="pets[0] ? `/pets/${pets[0].id}` : '/pets'"
            >
              <ion-icon slot="icon-only" :icon="playCircleOutline" />
            </ion-button>
            <span>Staff reviewed · 0:42</span>
          </div>
          <div>
            <div class="eyebrow">Behavior evidence, not promises</div>
            <h2 class="section-title">See more than a photo.</h2>
            <p class="lead">
              Verified videos show observed behavior such as play, walking, eating, and
              interaction with people. They help you make an informed choice, but never replace
              veterinary or temperament assessment.
            </p>
            <ion-button fill="outline" router-link="/pets">Explore pet profiles</ion-button>
          </div>
        </div>
      </section>

      <section class="section">
        <div class="container">
          <div class="section-heading">
            <div>
              <div class="eyebrow">Make care possible</div>
              <h2 class="section-title">Current fundraising needs</h2>
            </div>
            <ion-button fill="clear" router-link="/fundraising">All campaigns</ion-button>
          </div>
          <div v-if="campaigns.length" class="campaign-grid">
            <div v-for="campaign in campaigns" :key="campaign.id" class="campaign surface">
              <img :src="campaign.image" :alt="campaign.title" />
              <div class="campaign-copy">
                <span class="status-pill">{{ campaign.status }}</span>
                <h3>{{ campaign.title }}</h3>
                <p>{{ campaign.purpose }}</p>
                <ion-progress-bar :value="campaign.raised / campaign.target" color="primary" />
                <div class="funds">
                  <strong>₱{{ campaign.raised.toLocaleString() }}</strong>
                  <span>of ₱{{ campaign.target.toLocaleString() }}</span>
                </div>
                <ion-button expand="block" :router-link="`/fundraising/${campaign.id}`">
                  View campaign
                </ion-button>
              </div>
            </div>
          </div>
          <div v-else class="empty-state surface">
            No active fundraising campaigns are published yet.
          </div>
        </div>
      </section>

      <section class="guidelines">
        <div class="container guidelines-inner">
          <div>
            <div class="eyebrow">A lifelong promise</div>
            <h2 class="section-title">Ready for responsible pet ownership?</h2>
            <p class="lead">
              Adoption means safe housing, daily time, veterinary care, patience, and a permanent
              commitment through every life stage.
            </p>
          </div>
          <ion-button size="large" color="light" router-link="/register">Start your journey</ion-button>
        </div>
      </section>
      <site-footer />
    </ion-content>
  </ion-page>
</template>

<style scoped>
.hero {
  overflow: hidden;
  background: linear-gradient(120deg, #fff9f0 0%, #f5e7d8 100%);
}

.hero-grid {
  display: grid;
  min-height: 650px;
  grid-template-columns: 1.02fr 0.98fr;
  align-items: center;
  gap: 70px;
}

.hero-copy {
  padding-block: 60px;
}

h1 {
  max-width: 700px;
  margin: 16px 0 22px;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: clamp(3.2rem, 6vw, 5.5rem);
  font-weight: 600;
  line-height: 0.98;
  letter-spacing: -0.04em;
}

h1 em {
  color: var(--ion-color-primary);
  font-weight: 500;
}

.hero-actions,
.trust-row,
.section-heading,
.funds {
  display: flex;
  align-items: center;
}

.hero-actions {
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 30px;
}

.trust-row {
  gap: 24px;
  margin-top: 28px;
  color: var(--ink-muted);
  font-size: 0.85rem;
}

.trust-row span {
  display: flex;
  align-items: center;
  gap: 6px;
}

.trust-row ion-icon {
  color: var(--ion-color-tertiary);
}

.hero-image {
  position: relative;
  height: 540px;
}

.hero-image::before {
  position: absolute;
  inset: -25px 25px 25px -25px;
  border: 2px solid rgba(217, 97, 43, 0.2);
  border-radius: 46% 46% 18% 18%;
  content: "";
  transform: rotate(-3deg);
}

.hero-image > img {
  position: relative;
  width: 100%;
  height: 100%;
  border-radius: 46% 46% 18% 18%;
  object-fit: cover;
}

.match-card {
  display: flex;
  position: absolute;
  bottom: 28px;
  left: -40px;
  align-items: center;
  gap: 12px;
  border: 1px solid var(--border);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.94);
  padding: 14px 18px;
  box-shadow: var(--shadow);
}

.match-card small,
.match-card strong {
  display: block;
}

.match-card small {
  margin-top: 3px;
  color: var(--ink-muted);
}

.match-icon {
  display: grid;
  width: 42px;
  height: 42px;
  place-items: center;
  border-radius: 50%;
  background: #fbe7df;
  color: var(--ion-color-primary);
}

.section-heading {
  justify-content: space-between;
  margin-bottom: 32px;
}

.empty-state {
  padding: 36px;
  color: var(--ink-muted);
  text-align: center;
}

.process {
  background: var(--cream);
}

.center-heading {
  max-width: 650px;
  margin: 0 auto 46px;
  text-align: center;
}

.steps {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 34px;
}

.step {
  position: relative;
  text-align: center;
}

.step-icon {
  display: grid;
  position: relative;
  width: 76px;
  height: 76px;
  margin: 0 auto 18px;
  place-items: center;
  border-radius: 24px;
  background: white;
  color: var(--ion-color-primary);
  font-size: 1.7rem;
  box-shadow: 0 10px 28px rgba(76, 48, 37, 0.08);
}

.step-icon span {
  position: absolute;
  top: -8px;
  right: -8px;
  border-radius: 999px;
  background: var(--ion-color-secondary);
  padding: 5px 7px;
  color: white;
  font-size: 0.62rem;
  font-weight: 800;
}

.step h3,
.campaign h3 {
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.3rem;
}

.step p,
.campaign p {
  color: var(--ink-muted);
  line-height: 1.6;
}

.evidence {
  background: #3c2a22;
  color: white;
}

.evidence .section-title,
.evidence .lead {
  color: white;
}

.evidence .lead {
  opacity: 0.74;
}

.evidence-grid {
  display: grid;
  grid-template-columns: 1.05fr 0.95fr;
  align-items: center;
  gap: 70px;
}

.video-still {
  position: relative;
  aspect-ratio: 1.45;
  overflow: hidden;
  border-radius: 28px;
}

.video-still img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  opacity: 0.8;
}

.video-still ion-button {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 68px;
  height: 68px;
  transform: translate(-50%, -50%);
  --border-radius: 50%;
}

.video-still span {
  position: absolute;
  bottom: 18px;
  left: 18px;
  border-radius: 999px;
  background: rgba(36, 24, 20, 0.78);
  padding: 8px 12px;
  font-size: 0.78rem;
}

.campaign-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
}

.adoption-story-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 20px;
}

.adoption-story {
  overflow: hidden;
}

.adoption-story > img {
  width: 100%;
  height: 220px;
  object-fit: cover;
}

.adoption-story-copy {
  padding: 18px;
}

.adoption-story-copy .eyebrow {
  font-size: 0.72rem;
}

.adoption-story-copy h3 {
  margin: 7px 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.35rem;
}

.adoption-story-copy p {
  margin: 0;
  color: var(--ink-muted);
}

.adoption-story-copy p strong {
  color: var(--ion-color-primary);
}

.campaign {
  display: grid;
  grid-template-columns: 42% 58%;
  overflow: hidden;
}

.campaign > img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.campaign-copy {
  padding: 26px;
}

.campaign ion-progress-bar {
  height: 8px;
  border-radius: 99px;
}

.funds {
  justify-content: space-between;
  margin: 10px 0 18px;
}

.funds strong {
  color: var(--ion-color-primary);
}

.funds span {
  color: var(--ink-muted);
  font-size: 0.8rem;
}

.guidelines {
  padding: 70px 0;
  background: var(--ion-color-primary);
}

.guidelines .section-title,
.guidelines .lead,
.guidelines .eyebrow {
  color: white;
}

.guidelines .lead {
  opacity: 0.84;
}

.guidelines-inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 50px;
}

.guidelines-inner > div {
  max-width: 750px;
}

@media (max-width: 900px) {
  .hero-grid,
  .evidence-grid {
    grid-template-columns: 1fr;
  }

  .hero-grid {
    padding-block: 36px 60px;
  }

  .hero-image {
    height: 430px;
  }

  .steps {
    grid-template-columns: 1fr 1fr;
  }

  .campaign-grid {
    grid-template-columns: 1fr;
  }

  .adoption-story-grid {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 600px) {
  .hero-image {
    height: 350px;
  }

  .match-card {
    left: 12px;
  }

  .steps,
  .campaign,
  .campaign-grid {
    grid-template-columns: 1fr;
  }

  .campaign > img {
    height: 220px;
  }

  .adoption-story-grid {
    grid-template-columns: 1fr;
  }

  .guidelines-inner,
  .section-heading {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
