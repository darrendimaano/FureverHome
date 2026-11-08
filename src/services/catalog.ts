import { reactive } from "vue";
import { isSupabaseConfigured, supabase } from "@/services/supabase";
import type { AdoptionStory, Campaign, Pet, PetVideo } from "@/types";

type BackendMode = "loading" | "live" | "unavailable" | "schema-missing";

export const backendState = reactive({
  mode: "loading" as BackendMode,
  message: "Checking the connected database…",
});

export const pets = reactive<Pet[]>([]);
export const campaigns = reactive<Campaign[]>([]);
export const adoptionStories = reactive<AdoptionStory[]>([]);

export const petImageUrl = (photos: Array<{ storage_path: string; sort_order: number }> | null) => {
  const path = photos?.sort((a, b) => a.sort_order - b.sort_order)[0]?.storage_path;
  if (!path) return "/favicon.svg";
  if (/^https?:\/\//.test(path)) return path;
  return supabase.storage.from("pet-images").getPublicUrl(path).data.publicUrl;
};

const petVideoUrl = (path: string) => {
  if (/^https?:\/\//.test(path)) return path;
  return supabase.storage.from("pet-videos").getPublicUrl(path).data.publicUrl;
};

const petVideoContentType = (path: string): PetVideo["contentType"] => {
  const pathname = path.split(/[?#]/, 1)[0].toLowerCase();
  return pathname.endsWith(".webm") ? "video/webm" : "video/mp4";
};

const mapVideos = (
  videos:
    | Array<{
        storage_path: string;
        description: string;
        observed_trait: string;
        uploaded_at: string;
        verification_status: "pending" | "verified" | "rejected";
      }>
    | null,
): PetVideo[] =>
  (videos || [])
    .map((video) => ({
      url: petVideoUrl(video.storage_path),
      contentType: petVideoContentType(video.storage_path),
      description: video.description,
      observedTrait: video.observed_trait,
      uploadedAt: video.uploaded_at,
      verificationStatus: video.verification_status,
    }))
    .sort((left, right) => right.uploadedAt.localeCompare(left.uploadedAt));

const campaignImageUrl = (path: string | null) => {
  if (!path) return "/favicon.svg";
  return supabase.storage.from("pet-images").getPublicUrl(path).data.publicUrl;
};

const coordinateValue = (value: unknown): number | null => {
  if (value === null || value === undefined || value === "") return null;
  const coordinate = Number(value);
  return Number.isFinite(coordinate) ? coordinate : null;
};

export async function refreshPetLocation(petId: string): Promise<string | null> {
  if (!isSupabaseConfigured || !supabase) {
    return "Live shelter location is unavailable.";
  }

  const { data, error } = await supabase
    .from("pets")
    .select("id, location, address, latitude, longitude")
    .eq("id", petId)
    .single();
  if (error) return error.message;

  const pet = pets.find((item) => item.id === petId);
  if (!pet) return "Pet details are not loaded.";
  pet.location = data.location;
  pet.address = data.address || "";
  pet.latitude = coordinateValue(data.latitude);
  pet.longitude = coordinateValue(data.longitude);
  return null;
}

export async function loadCatalog() {
  if (!isSupabaseConfigured || !supabase) {
    backendState.mode = "unavailable";
    backendState.message = "The live data service is unavailable.";
    return;
  }

  const [petResult, campaignResult, totalsResult, adoptionResult] = await Promise.all([
    supabase
      .from("pets")
      .select(
        "*, pet_photos(storage_path, sort_order), pet_videos(storage_path, description, observed_trait, uploaded_at, verification_status)",
      )
      .eq("is_published", true)
      .neq("status", "archived")
      .neq("status", "adopted")
      .order("created_at", { ascending: false }),
    supabase
      .from("fundraising_campaigns")
      .select("*")
      .in("status", ["published", "closed"])
      .order("created_at", { ascending: false }),
    supabase.from("campaign_confirmed_totals").select("campaign_id, confirmed_total"),
    supabase
      .from("public_adoption_stories")
      .select("id, pet_id, pet_name, species, storage_path, adopter_display_name, completed_at")
      .order("completed_at", { ascending: false }),
  ]);

  if (petResult.error || campaignResult.error || totalsResult.error) {
    backendState.mode = "schema-missing";
    backendState.message =
      "Unable to load live records from Supabase.";
    pets.splice(0, pets.length);
    campaigns.splice(0, campaigns.length);
    return;
  }

  const livePets: Pet[] = (petResult.data || []).map((pet) => {
    const age = pet.birth_date
      ? Math.max(0, new Date().getFullYear() - new Date(pet.birth_date).getFullYear())
      : null;
    return {
      id: pet.id,
      name: pet.name,
      species: pet.species,
      breed: pet.breed,
      age: age === null ? "Age not recorded" : `${age} years`,
      ageGroup: age === null || age < 3 ? "Young" : age >= 8 ? "Senior" : "Adult",
      gender: pet.gender === "Female" ? "Female" : "Male",
      size: pet.size || "Medium",
      location: pet.location,
      address: pet.address || "",
      latitude: coordinateValue(pet.latitude),
      longitude: coordinateValue(pet.longitude),
      health: pet.health_condition || "Assessment recorded",
      vaccinationStatus: pet.vaccination_status || "Vaccination not recorded",
      status:
        pet.status === "available"
          ? "Available"
          : pet.status === "adopted"
            ? "Adopted"
            : "On hold",
      image: petImageUrl(pet.pet_photos),
      personality: pet.personality || "Personality notes are being prepared.",
      story: pet.rescue_story || "Rescue story is being prepared.",
      videos: mapVideos(pet.pet_videos),
    };
  });

  const totals = new Map(
    (totalsResult.data || []).map((total) => [
      total.campaign_id,
      Number(total.confirmed_total),
    ]),
  );
  const liveCampaigns: Campaign[] = (campaignResult.data || []).map(
    (campaign) => {
      const endedByDate = campaign.ends_on < new Date().toISOString().slice(0, 10);
      return {
      id: campaign.id,
      title: campaign.title,
      purpose: campaign.purpose,
      image: campaignImageUrl(campaign.cover_path),
      target: Number(campaign.target_amount),
      raised: totals.get(campaign.id) || 0,
      endDate: new Date(campaign.ends_on).toLocaleDateString(),
      status: campaign.status === "closed" ? "Closed" : endedByDate ? "Ended" : "Active",
    };
    },
  );
  const liveAdoptionStories: AdoptionStory[] = (adoptionResult.data || []).map((story) => ({
    id: story.id,
    petId: story.pet_id,
    petName: story.pet_name,
    species: story.species,
    image: campaignImageUrl(story.storage_path),
    adopterDisplayName: story.adopter_display_name,
    completedAt: new Date(story.completed_at).toLocaleDateString(),
  }));

  pets.splice(0, pets.length, ...livePets);
  campaigns.splice(0, campaigns.length, ...liveCampaigns);
  adoptionStories.splice(0, adoptionStories.length, ...liveAdoptionStories);
  backendState.mode = "live";
  backendState.message = "Live records loaded from Supabase.";
}
