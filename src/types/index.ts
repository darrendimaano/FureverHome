export type PetVideo = {
  url: string;
  contentType: "video/mp4" | "video/webm";
  description: string;
  observedTrait: string;
  uploadedAt: string;
  verificationStatus: "pending" | "verified" | "rejected";
  sourceAttribution?: string;
};

export type Pet = {
  id: string;
  name: string;
  species: "Dog" | "Cat";
  breed: string;
  age: string;
  ageGroup: "Young" | "Adult" | "Senior";
  gender: "Male" | "Female";
  size: "Small" | "Medium" | "Large";
  location: string;
  address: string;
  latitude: number | null;
  longitude: number | null;
  health: string;
  vaccinationStatus?: string;
  status: "Available" | "On hold" | "Adopted";
  image: string;
  personality: string;
  story: string;
  videos?: PetVideo[];
  favorite?: boolean;
};

export type Campaign = {
  id: string;
  title: string;
  purpose: string;
  image: string;
  target: number;
  raised: number;
  endDate: string;
  status: "Active" | "Ended" | "Closed";
};

export type AdoptionStory = {
  id: string;
  petId: string;
  petName: string;
  species: string;
  image: string;
  adopterDisplayName: string;
  completedAt: string;
};

export type AppRole = "guest" | "adopter" | "admin";
