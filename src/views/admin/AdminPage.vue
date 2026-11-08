<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import {
  IonButton,
  IonBadge,
  IonCheckbox,
  IonContent,
  IonIcon,
  IonInput,
  IonItem,
  IonLabel,
  IonList,
  IonModal,
  IonPage,
  IonProgressBar,
  IonSelect,
  IonSelectOption,
  IonTextarea,
  alertController,
  toastController,
} from "@ionic/vue";
import {
  barChartOutline,
  calendarOutline,
  cashOutline,
  closeOutline,
  documentTextOutline,
  downloadOutline,
  filmOutline,
  homeOutline,
  logOutOutline,
  pawOutline,
  peopleOutline,
  refreshOutline,
  shieldCheckmarkOutline,
} from "ionicons/icons";
import { useAppState } from "@/composables/useAppState";
import { pets, campaigns } from "@/services/catalog";
import { loadCatalog } from "@/services/catalog";
import { supabase } from "@/services/supabase";
import ShelterMap from "@/components/ShelterMap.vue";
import type { Pet } from "@/types";

const route = useRoute();
const router = useRouter();
const { state, logout } = useAppState();
const title = computed(() => String(route.meta.title || "Admin dashboard"));
const section = computed(() => String(route.meta.section || "dashboard"));
const staffInitials = computed(() => {
  const nameParts = state.userName.trim().split(/\s+/).filter(Boolean);
  if (!nameParts.length) return "AD";
  return `${nameParts[0][0]}${nameParts.length > 1 ? nameParts[nameParts.length - 1][0] : ""}`.toUpperCase();
});
const recordName = ref("");
type AdminUser = {
  id: string;
  email: string;
  full_name: string;
  role: "adopter" | "staff" | "admin";
  is_active: boolean;
  created_at: string;
};
const users = ref<AdminUser[]>([]);
const usersLoading = ref(false);
const usersError = ref("");
const userSearch = ref("");
const updatingUserId = ref("");
const deletingUserId = ref("");
const filteredUsers = computed(() => {
  const search = userSearch.value.trim().toLowerCase();
  if (!search) return users.value;
  return users.value.filter((user) =>
    `${user.full_name} ${user.email} ${user.role}`.toLowerCase().includes(search),
  );
});
const assessment = ref("");
const savingPet = ref(false);
const appointments = ref<Array<{
  id: string;
  applicant_id: string;
  starts_at: string;
  location: string;
  status: string;
  reason_for_adoption: string | null;
  pet_experience: string | null;
  household_information: string | null;
  additional_notes: string | null;
  pet: { name: string; breed: string } | null;
  applicant: { full_name: string; phone: string | null } | null;
  assessment: { outcome: string; recommendations: string | null; checklist: Record<string, boolean> } | null;
}>>([]);
const appointmentsLoading = ref(false);
const appointmentsError = ref("");
const selectedAppointmentId = ref("");
const assessmentModalOpen = ref(false);
const adoptionApplications = ref<Array<{
  id: string;
  applicant_id: string;
  pet_id: string;
  status: string;
  created_at: string;
  review_notes: string | null;
  form_data: Record<string, string | boolean>;
  applicant: { full_name: string; phone: string | null } | null;
  pet: { name: string; breed: string } | null;
}>>([]);
const adoptionApplicationsLoading = ref(false);
const adoptionApplicationsError = ref("");
const completedAdoptions = ref<Array<{
  id: string;
  completed_at: string;
  notes: string | null;
  pet: { name: string; breed: string } | null;
  adopter: { full_name: string } | null;
}>>([]);
const completedAdoptionsLoading = ref(false);
const completedAdoptionsError = ref("");
const selectedAdoptionApplicationId = ref("");
const adoptionReviewModalOpen = ref(false);
const approvingApplication = ref(false);
const declineReason = ref("");
const adminCampaigns = ref<Array<{
  id: string;
  title: string;
  purpose: string;
  description: string;
  target_amount: number;
  starts_on: string;
  ends_on: string;
  status: "draft" | "published" | "closed";
  raised: number;
}>>([]);
const adminCampaignsLoading = ref(false);
const adminCampaignsError = ref("");
const campaignModalOpen = ref(false);
const campaignSaving = ref(false);
const editingCampaignId = ref("");
const campaignForm = reactive({
  title: "",
  purpose: "",
  description: "",
  targetAmount: "",
  startsOn: "",
  endsOn: "",
  status: "draft" as "draft" | "published" | "closed",
});
const campaignPaymentSettings = reactive({ gcashNumber: "", qrStoragePath: "" });
const paymentSettingsError = ref("");
const selectedQrFile = ref<File | null>(null);
const savingPaymentSettings = ref(false);
const donations = ref<Array<{
  id: string;
  campaign_id: string;
  donor_id: string | null;
  donor_name: string | null;
  donor_email: string | null;
  amount: number;
  anonymous: boolean;
  message: string | null;
  payment_provider: string | null;
  payment_reference: string | null;
  payment_status: string;
  proof_storage_path: string | null;
  created_at: string;
  campaign: { title: string } | null;
}>>([]);
const donationsLoading = ref(false);
const donationsError = ref("");
const selectedDonationId = ref("");
const donationReviewModalOpen = ref(false);
const donationProofUrl = ref("");
const reviewingDonation = ref(false);
const assessmentOutcome = ref<"approved_to_proceed" | "additional_assessment_required" | "not_approved">("approved_to_proceed");
const assessmentComment = ref("");
const assessmentChecklist = reactive<Record<string, boolean>>({
  understands_responsibilities: false,
  suitable_living_environment: false,
  household_agreement: false,
  financial_readiness: false,
  time_for_daily_care: false,
  experience_or_willingness: false,
  safe_permanent_home: false,
});
const selectedImageFile = ref<File | null>(null);
const selectedVideoFile = ref<File | null>(null);
const petForm = reactive({
  name: "",
  species: "Dog" as "Dog" | "Cat",
  breed: "",
  age: "",
  gender: "Male" as "Male" | "Female",
  size: "Medium" as "Small" | "Medium" | "Large",
  location: "",
  address: "",
  latitude: "",
  longitude: "",
  vaccinated: false,
  vaccines: "",
  rescueStory: "",
  videoDescription: "",
  observedTrait: "",
  published: true,
});
const petMapCoordinates = computed(() => {
  const latitude = petForm.latitude.trim() ? Number(petForm.latitude) : null;
  const longitude = petForm.longitude.trim() ? Number(petForm.longitude) : null;
  if (
    latitude === null ||
    longitude === null ||
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) {
    return { latitude: null, longitude: null };
  }
  return { latitude, longitude };
});
const adminStats = reactive({
  pendingApplications: 0,
  upcomingAppointments: 0,
  confirmedDonations: 0,
});
const dashboardPets = ref<Array<{ id: string; species: string; status: string }>>([]);
const dashboardPetsError = ref("");
const dashboardPetCounts = computed(() => ({
  total: dashboardPets.value.length,
  dogs: dashboardPets.value.filter((pet) => pet.species === "Dog").length,
  available: dashboardPets.value.filter((pet) => pet.status === "available").length,
  adopted: dashboardPets.value.filter((pet) => pet.status === "adopted").length,
}));
type ReportPet = { id: string; name: string; species: string; status: string; created_at: string };
type ReportPetSummary = { name: string; species: string } | null;
const reportFilters = reactive({ startDate: "", endDate: "", species: "all", petId: "all" });
const reportLoading = ref(false);
const reportError = ref("");
const reportData = reactive({
  pets: [] as ReportPet[],
  appointments: [] as Array<{ id: string; pet_id: string; starts_at: string; status: string; pet: ReportPetSummary }>,
  assessments: [] as Array<{ id: string; outcome: string; assessed_at: string; recommendations: string | null; appointment: { pet_id: string; pet: ReportPetSummary } | null }>,
  applications: [] as Array<{ id: string; pet_id: string; status: string; created_at: string; submitted_at: string | null; review_notes: string | null; pet: ReportPetSummary }>,
  adoptions: [] as Array<{ id: string; pet_id: string; completed_at: string; pet: ReportPetSummary }>,
  donations: [] as Array<{
    id: string;
    campaign_id: string;
    amount: number | string;
    payment_status: string;
    created_at: string;
    donor_name: string | null;
    donor_email: string | null;
    anonymous: boolean;
    payment_provider: string | null;
    payment_reference: string | null;
    confirmed_at: string | null;
    campaign: { title: string } | null;
  }>,
  campaigns: [] as Array<{ id: string; title: string; target_amount: number | string; status: string }>,
});
const pipeline = computed(() => {
  const activePets = dashboardPets.value.filter((pet) =>
    ["available", "on_hold", "adopted"].includes(pet.status),
  );
  const total = activePets.length;
  const percentage = (status: string) =>
    total
      ? Math.round((activePets.filter((pet) => pet.status === status).length / total) * 100)
      : 0;
  return [
    ["Available", percentage("available")],
    ["On hold", percentage("on_hold")],
    ["Adopted", percentage("adopted")],
  ];
});

const reportPetOptions = computed(() => reportData.pets.filter((pet) =>
  reportFilters.species === "all" || pet.species === reportFilters.species,
));
const dateIsInReportRange = (value: string | null | undefined) => {
  if (!value) return false;
  const date = value.slice(0, 10);
  return (!reportFilters.startDate || date >= reportFilters.startDate) &&
    (!reportFilters.endDate || date <= reportFilters.endDate);
};
const matchesReportPet = (petId: string, pet: ReportPetSummary) => {
  if (reportFilters.petId !== "all" && petId !== reportFilters.petId) return false;
  return reportFilters.species === "all" || pet?.species === reportFilters.species;
};
const filteredReportAppointments = computed(() => reportData.appointments.filter((item) =>
  dateIsInReportRange(item.starts_at) && matchesReportPet(item.pet_id, item.pet),
));
const filteredReportAssessments = computed(() => reportData.assessments.filter((item) =>
  dateIsInReportRange(item.assessed_at) && Boolean(item.appointment) &&
    matchesReportPet(item.appointment!.pet_id, item.appointment!.pet),
));
const filteredReportApplications = computed(() => reportData.applications.filter((item) =>
  dateIsInReportRange(item.submitted_at || item.created_at) && matchesReportPet(item.pet_id, item.pet),
));
const filteredReportAdoptions = computed(() => reportData.adoptions.filter((item) =>
  dateIsInReportRange(item.completed_at) && matchesReportPet(item.pet_id, item.pet),
));
const filteredReportPets = computed(() => reportData.pets.filter((pet) =>
  matchesReportPet(pet.id, pet),
));
const filteredReportDonations = computed(() => reportData.donations.filter((item) =>
  dateIsInReportRange(item.created_at),
));
const reportDonationTotals = computed(() => {
  const donations = filteredReportDonations.value;
  return {
    count: donations.length,
    confirmedAmount: donations
      .filter((item) => item.payment_status === "confirmed")
      .reduce((total, item) => total + Number(item.amount), 0),
    pendingCount: donations.filter((item) =>
      ["pending", "offline_pending"].includes(item.payment_status),
    ).length,
    failedCount: donations.filter((item) =>
      ["failed", "refunded"].includes(item.payment_status),
    ).length,
  };
});
const reportDonationCampaigns = computed(() => {
  const totals = new Map<string, { raised: number; confirmedCount: number }>();
  for (const donation of filteredReportDonations.value) {
    const campaignId = donation.campaign_id;
    const total = totals.get(campaignId) || { raised: 0, confirmedCount: 0 };
    if (donation.payment_status === "confirmed") {
      total.raised += Number(donation.amount);
      total.confirmedCount += 1;
    }
    totals.set(campaignId, total);
  }
  return reportData.campaigns.map((campaign) => ({
    ...campaign,
    ...(totals.get(campaign.id) || { raised: 0, confirmedCount: 0 }),
    target: Number(campaign.target_amount),
  })).sort((left, right) => right.raised - left.raised);
});

const loadReports = async () => {
  reportLoading.value = true;
  reportError.value = "";
  const results = await Promise.all([
    supabase.from("pets").select("id, name, species, status, created_at").order("name"),
    supabase.from("appointments").select("id, pet_id, starts_at, status, pet:pets(name, species)").order("starts_at", { ascending: false }),
    supabase.from("assessment_records").select("id, outcome, assessed_at, recommendations, appointment:appointments!inner(pet_id, pet:pets(name, species))").order("assessed_at", { ascending: false }),
    supabase.from("adoption_applications").select("id, pet_id, status, created_at, submitted_at, review_notes, pet:pets(name, species)").order("created_at", { ascending: false }),
    supabase.from("adoption_records").select("id, pet_id, completed_at, pet:pets(name, species)").order("completed_at", { ascending: false }),
    supabase.from("donations").select("id, campaign_id, amount, payment_status, created_at, donor_name, donor_email, anonymous, payment_provider, payment_reference, confirmed_at, campaign:fundraising_campaigns(title)").order("created_at", { ascending: false }),
    supabase.from("fundraising_campaigns").select("id, title, target_amount, status").order("created_at", { ascending: false }),
  ]);
  const failedQuery = results.find((result) => result.error);
  if (failedQuery?.error) {
    reportError.value = failedQuery.error.message;
    reportLoading.value = false;
    return;
  }

  reportData.pets = results[0].data || [];
  reportData.appointments = results[1].data || [];
  reportData.assessments = results[2].data || [];
  reportData.applications = results[3].data || [];
  reportData.adoptions = results[4].data || [];
  reportData.donations = results[5].data || [];
  reportData.campaigns = results[6].data || [];
  reportLoading.value = false;
};

const exportReportsCsv = () => {
  const rows: Array<Array<string | number>> = [["Report", "Date", "Pet or campaign", "Status or result", "Amount", "Reason or comment", "Donor", "Email", "Payment method", "Payment reference"]];
  for (const appointment of filteredReportAppointments.value) {
    rows.push(["Appointment", appointment.starts_at, appointment.pet?.name || "", appointment.status, "", ""]);
  }
  for (const assessment of filteredReportAssessments.value) {
    rows.push(["Assessment", assessment.assessed_at, assessment.appointment?.pet?.name || "", assessment.outcome, "", assessment.recommendations || ""]);
  }
  for (const application of filteredReportApplications.value) {
    rows.push(["Application", application.submitted_at || application.created_at, application.pet?.name || "", application.status, "", application.review_notes || ""]);
  }
  for (const adoption of filteredReportAdoptions.value) {
    rows.push(["Adoption", adoption.completed_at, adoption.pet?.name || "", "completed", "", ""]);
  }
  for (const donation of filteredReportDonations.value) {
    rows.push([
      "Donation",
      donation.created_at,
      donation.campaign?.title || "",
      donation.payment_status,
      donation.amount,
      "",
      donation.anonymous ? "Anonymous" : donation.donor_name || "",
      donation.anonymous ? "" : donation.donor_email || "",
      donation.payment_provider || "",
      donation.payment_reference || "",
    ]);
  }
  for (const pet of filteredReportPets.value) {
    rows.push(["Pet status", pet.created_at, pet.name, pet.status, "", pet.species]);
  }
  const escapeCell = (value: string | number) => `"${String(value).replaceAll('"', '""')}"`;
  const csv = rows.map((row) => row.map(escapeCell).join(",")).join("\r\n");
  const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = `furever-reports-${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  URL.revokeObjectURL(url);
};

const menu = [
  [homeOutline, "Overview", "/admin/dashboard"],
  [pawOutline, "Pet management", "/admin/pets"],
  [calendarOutline, "Appointments", "/admin/appointments"],
  [documentTextOutline, "Applications", "/admin/applications"],
  [shieldCheckmarkOutline, "Adoptions", "/admin/adoptions"],
  [cashOutline, "Fundraising", "/admin/fundraising"],
  [cashOutline, "Donations", "/admin/donations"],
  [peopleOutline, "Users", "/admin/users"],
  [barChartOutline, "Reports", "/admin/reports"],
];

const signOut = async () => {
  try {
    await logout();
    window.location.replace(router.resolve("/").href);
  } catch (error) {
    const toast = await toastController.create({
      message: error instanceof Error ? error.message : "Unable to log out. Please try again.",
      color: "danger",
      duration: 3000,
    });
    await toast.present();
  }
};

const loadAdminStats = async () => {
  const [applications, appointments, donations] = await Promise.all([
    supabase
      .from("adoption_applications")
      .select("id", { count: "exact", head: true })
      .in("status", ["pending_assessment", "assessment_required", "under_review"]),
    supabase
      .from("appointments")
      .select("id", { count: "exact", head: true })
      .gte("starts_at", new Date().toISOString())
      .in("status", ["pending_confirmation", "confirmed", "rescheduled"]),
    supabase.from("donations").select("amount").eq("payment_status", "confirmed"),
  ]);
  adminStats.pendingApplications = applications.count || 0;
  adminStats.upcomingAppointments = appointments.count || 0;
  adminStats.confirmedDonations = (donations.data || []).reduce(
    (total, donation) => total + Number(donation.amount),
    0,
  );
};

const loadDashboardPets = async () => {
  const { data, error } = await supabase
    .from("pets")
    .select("id, species, status")
    .neq("status", "archived");
  if (error) {
    dashboardPetsError.value = error.message;
    return;
  }
  dashboardPets.value = data || [];
  dashboardPetsError.value = "";
};

const selectedAppointment = computed(() =>
  appointments.value.find((appointment) => appointment.id === selectedAppointmentId.value) || null,
);
const selectedAdoptionApplication = computed(() =>
  adoptionApplications.value.find((application) => application.id === selectedAdoptionApplicationId.value) || null,
);
const selectedDonation = computed(() => donations.value.find((donation) => donation.id === selectedDonationId.value) || null);
const campaignQrUrl = computed(() => campaignPaymentSettings.qrStoragePath
  ? supabase.storage.from("fundraising-qr").getPublicUrl(campaignPaymentSettings.qrStoragePath).data.publicUrl
  : "");
const adoptionApplicationFields = computed(() => {
  const labels: Record<string, string> = {
    full_name: "Full name",
    phone: "Contact number",
    email: "Email",
    address: "Home address",
    household: "Household members",
    residence_type: "Residence type",
    landlord_permission: "Landlord permission",
    existing_pets: "Other pets",
    pet_experience: "Pet care experience",
    hours_alone: "Hours pet is alone",
    reason: "Reason for adopting",
    emergency_contact: "Emergency contact",
  };
  return Object.entries(selectedAdoptionApplication.value?.form_data || {}).map(([key, value]) => ({
    label: labels[key] || key,
    value: typeof value === "boolean" ? (value ? "Yes" : "No") : value,
  }));
});

const loadAppointments = async () => {
  appointmentsLoading.value = true;
  appointmentsError.value = "";
  const { data, error } = await supabase
    .from("appointments")
    .select("id, applicant_id, starts_at, location, status, reason_for_adoption, pet_experience, household_information, additional_notes, pet:pets(name, breed), applicant:profiles!appointments_applicant_id_fkey(full_name, phone)")
    .order("created_at", { ascending: false });

  if (error) {
    appointmentsError.value = error.message;
    appointmentsLoading.value = false;
    return;
  }

  const rows = data || [];
  const appointmentIds = rows.map((appointment) => appointment.id);
  const { data: assessments, error: assessmentError } = appointmentIds.length
    ? await supabase
        .from("assessment_records")
        .select("appointment_id, outcome, recommendations, checklist")
        .in("appointment_id", appointmentIds)
    : { data: [], error: null };

  if (assessmentError) {
    appointmentsError.value = assessmentError.message;
    appointmentsLoading.value = false;
    return;
  }

  appointments.value = rows.map((appointment) => ({
    ...appointment,
    assessment: (assessments || []).find((item) => item.appointment_id === appointment.id) || null,
  }));
  appointmentsLoading.value = false;
};

const loadAdoptionApplications = async () => {
  adoptionApplicationsLoading.value = true;
  adoptionApplicationsError.value = "";
  const { data, error } = await supabase
    .from("adoption_applications")
    .select("id, applicant_id, pet_id, status, created_at, review_notes, form_data, applicant:profiles!adoption_applications_applicant_id_fkey(full_name, phone), pet:pets(name, breed)")
    .neq("status", "adoption_completed")
    .order("created_at", { ascending: false });
  if (error) adoptionApplicationsError.value = error.message;
  else adoptionApplications.value = data || [];
  adoptionApplicationsLoading.value = false;
};

const loadCompletedAdoptions = async () => {
  completedAdoptionsLoading.value = true;
  completedAdoptionsError.value = "";
  const { data, error } = await supabase
    .from("adoption_records")
    .select("id, completed_at, notes, pet:pets(name, breed), adopter:profiles!adoption_records_adopter_id_fkey(full_name)")
    .order("completed_at", { ascending: false });
  if (error) completedAdoptionsError.value = error.message;
  else completedAdoptions.value = data || [];
  completedAdoptionsLoading.value = false;
};

const loadAdminCampaigns = async () => {
  adminCampaignsLoading.value = true;
  adminCampaignsError.value = "";
  const [campaignResult, totalsResult, settingsResult] = await Promise.all([
    supabase
      .from("fundraising_campaigns")
      .select("id, title, purpose, description, target_amount, starts_on, ends_on, status")
      .order("created_at", { ascending: false }),
    supabase.from("campaign_confirmed_totals").select("campaign_id, confirmed_total"),
    supabase.from("fundraising_payment_settings").select("gcash_number, qr_storage_path").eq("id", 1).maybeSingle(),
  ]);
  const settingsTableMissing = settingsResult.error?.code === "PGRST205" || settingsResult.error?.code === "42P01";
  if (campaignResult.error || totalsResult.error || (settingsResult.error && !settingsTableMissing)) {
    adminCampaignsError.value = campaignResult.error?.message || totalsResult.error?.message || settingsResult.error?.message || "Unable to load campaigns.";
    adminCampaignsLoading.value = false;
    return;
  }
  const totals = new Map((totalsResult.data || []).map((item) => [item.campaign_id, Number(item.confirmed_total)]));
  adminCampaigns.value = (campaignResult.data || []).map((campaign) => ({
    ...campaign,
    target_amount: Number(campaign.target_amount),
    raised: totals.get(campaign.id) || 0,
  }));
  paymentSettingsError.value = settingsTableMissing
    ? "Payment settings table is missing. Apply migration 009 and refresh the Supabase schema cache."
    : "";
  campaignPaymentSettings.gcashNumber = settingsResult.data?.gcash_number || "";
  campaignPaymentSettings.qrStoragePath = settingsResult.data?.qr_storage_path || "";
  adminCampaignsLoading.value = false;
};

const loadDonations = async () => {
  donationsLoading.value = true;
  donationsError.value = "";
  const { data, error } = await supabase
    .from("donations")
    .select("id, campaign_id, donor_id, donor_name, donor_email, amount, anonymous, message, payment_provider, payment_reference, payment_status, proof_storage_path, created_at, campaign:fundraising_campaigns(title)")
    .order("created_at", { ascending: false });
  if (error) donationsError.value = error.message;
  else donations.value = data || [];
  donationsLoading.value = false;
};

const selectQrFile = async (event: Event) => {
  const file = await selectedFileFrom(event);
  if (!file) return;
  if (!file.type.startsWith("image/") || file.size > 5 * 1024 * 1024) {
    selectedQrFile.value = null;
    const toast = await toastController.create({ message: "Choose a QR image no larger than 5 MB.", color: "danger", duration: 2600 });
    return toast.present();
  }
  selectedQrFile.value = file;
};

const saveCampaignPaymentSettings = async () => {
  const number = campaignPaymentSettings.gcashNumber.trim();
  if (!number && !campaignPaymentSettings.qrStoragePath && !selectedQrFile.value) {
    const toast = await toastController.create({ message: "Add a GCash number or upload a QR image.", color: "danger", duration: 2600 });
    return toast.present();
  }
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    const toast = await toastController.create({ message: "Sign in again to update payment details.", color: "danger", duration: 2600 });
    return toast.present();
  }

  savingPaymentSettings.value = true;
  let qrStoragePath = campaignPaymentSettings.qrStoragePath || null;
  let newlyUploadedPath = "";
  if (selectedQrFile.value) {
    const safeName = selectedQrFile.value.name.replace(/[^a-zA-Z0-9._-]/g, "-");
    newlyUploadedPath = `qr/${crypto.randomUUID()}-${safeName}`;
    const upload = await supabase.storage.from("fundraising-qr").upload(newlyUploadedPath, selectedQrFile.value, {
      contentType: selectedQrFile.value.type,
      upsert: false,
    });
    if (upload.error) {
      savingPaymentSettings.value = false;
      const toast = await toastController.create({ message: upload.error.message, color: "danger", duration: 3000 });
      return toast.present();
    }
    qrStoragePath = newlyUploadedPath;
  }

  const previousPath = campaignPaymentSettings.qrStoragePath;
  const { error } = await supabase.from("fundraising_payment_settings").upsert({
    id: 1,
    gcash_number: number,
    qr_storage_path: qrStoragePath,
    updated_by: authData.user.id,
    updated_at: new Date().toISOString(),
  });
  savingPaymentSettings.value = false;
  if (error && newlyUploadedPath) await supabase.storage.from("fundraising-qr").remove([newlyUploadedPath]);
  const toast = await toastController.create({
    message: error ? error.message : "GCash payment details saved.",
    color: error ? "danger" : "success",
    duration: 2600,
  });
  await toast.present();
  if (!error) {
    campaignPaymentSettings.gcashNumber = number;
    campaignPaymentSettings.qrStoragePath = qrStoragePath || "";
    selectedQrFile.value = null;
    if (previousPath && previousPath !== qrStoragePath) await supabase.storage.from("fundraising-qr").remove([previousPath]);
  }
};

const selectDonationForReview = async (donation: (typeof donations.value)[number]) => {
  selectedDonationId.value = donation.id;
  donationProofUrl.value = "";
  donationReviewModalOpen.value = true;
  if (!donation.proof_storage_path) return;
  const { data, error } = await supabase.storage.from("donation-proofs").createSignedUrl(donation.proof_storage_path, 600);
  if (error) {
    const toast = await toastController.create({ message: error.message, color: "danger", duration: 3000 });
    await toast.present();
  } else donationProofUrl.value = data.signedUrl;
};

const reviewDonation = async (approved: boolean) => {
  const donation = selectedDonation.value;
  if (!donation || reviewingDonation.value) return;
  reviewingDonation.value = true;
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    reviewingDonation.value = false;
    const toast = await toastController.create({ message: "Sign in again to review this donation.", color: "danger", duration: 2600 });
    return toast.present();
  }
  const { error } = await supabase.from("donations").update({
    payment_status: approved ? "confirmed" : "failed",
    confirmed_by: approved ? authData.user.id : null,
    confirmed_at: approved ? new Date().toISOString() : null,
  }).eq("id", donation.id);
  reviewingDonation.value = false;
  const toast = await toastController.create({
    message: error ? error.message : approved ? "Donation confirmed and added to the supporters list." : "Donation proof declined.",
    color: error ? "danger" : approved ? "success" : "warning",
    duration: 3000,
  });
  await toast.present();
  if (!error) {
    donationReviewModalOpen.value = false;
    await Promise.all([loadDonations(), loadCatalog()]);
  }
};

const resetCampaignForm = () => {
  editingCampaignId.value = "";
  campaignForm.title = "";
  campaignForm.purpose = "";
  campaignForm.description = "";
  campaignForm.targetAmount = "";
  campaignForm.startsOn = new Date().toISOString().slice(0, 10);
  campaignForm.endsOn = "";
  campaignForm.status = "draft";
};

const openCampaignForm = (campaign?: (typeof adminCampaigns.value)[number]) => {
  resetCampaignForm();
  if (campaign) {
    editingCampaignId.value = campaign.id;
    campaignForm.title = campaign.title;
    campaignForm.purpose = campaign.purpose;
    campaignForm.description = campaign.description;
    campaignForm.targetAmount = String(campaign.target_amount);
    campaignForm.startsOn = campaign.starts_on;
    campaignForm.endsOn = campaign.ends_on;
    campaignForm.status = campaign.status;
  }
  campaignModalOpen.value = true;
};

const saveCampaign = async () => {
  const targetAmount = Number(campaignForm.targetAmount);
  if (!campaignForm.title.trim() || !campaignForm.purpose.trim() || !campaignForm.description.trim() ||
      !campaignForm.startsOn || !campaignForm.endsOn || !Number.isFinite(targetAmount) || targetAmount <= 0 ||
      campaignForm.endsOn < campaignForm.startsOn) {
    const toast = await toastController.create({
      message: "Complete all fields, use a positive goal, and choose a valid date range.",
      color: "danger",
      duration: 2800,
    });
    return toast.present();
  }

  campaignSaving.value = true;
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    campaignSaving.value = false;
    const toast = await toastController.create({ message: "Sign in again to save this campaign.", color: "danger", duration: 2600 });
    return toast.present();
  }
  const payload = {
    title: campaignForm.title.trim(),
    purpose: campaignForm.purpose.trim(),
    description: campaignForm.description.trim(),
    target_amount: targetAmount,
    starts_on: campaignForm.startsOn,
    ends_on: campaignForm.endsOn,
    status: campaignForm.status,
  };
  const result = editingCampaignId.value
    ? await supabase.from("fundraising_campaigns").update(payload).eq("id", editingCampaignId.value)
    : await supabase.from("fundraising_campaigns").insert({ ...payload, created_by: authData.user.id });
  campaignSaving.value = false;
  const toast = await toastController.create({
    message: result.error
      ? result.error.code === "42501"
        ? "Supabase denied this change. Apply migration 008 and verify your profile is an active admin."
        : result.error.message
      : "Fundraising campaign saved.",
    color: result.error ? "danger" : "success",
    duration: 2600,
  });
  await toast.present();
  if (!result.error) {
    campaignModalOpen.value = false;
    await Promise.all([loadAdminCampaigns(), loadCatalog()]);
  }
};

const selectAdoptionApplication = (application: (typeof adoptionApplications.value)[number]) => {
  selectedAdoptionApplicationId.value = application.id;
  declineReason.value = application.review_notes || "";
  adoptionReviewModalOpen.value = true;
};

const approveAdoptionApplication = async () => {
  const application = selectedAdoptionApplication.value;
  if (!application || approvingApplication.value) return;
  approvingApplication.value = true;
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    approvingApplication.value = false;
    const toast = await toastController.create({ message: "Sign in again to approve this application.", color: "danger", duration: 2600 });
    return toast.present();
  }
  const { error } = await supabase.rpc("complete_adoption", { p_application_id: application.id });
  approvingApplication.value = false;
  const toast = await toastController.create({
    message: error ? error.message : "Adoption completed. The pet was removed from public listings.",
    color: error ? "danger" : "success",
    duration: 2600,
  });
  await toast.present();
  if (!error) {
    await Promise.all([loadAdoptionApplications(), loadCompletedAdoptions(), loadAdminStats(), loadCatalog()]);
    adoptionReviewModalOpen.value = false;
  }
};

const declineAdoptionApplication = async () => {
  const application = selectedAdoptionApplication.value;
  if (!application || approvingApplication.value) return;
  if (!declineReason.value.trim()) {
    const toast = await toastController.create({ message: "Add a reason so the adopter knows what to correct.", color: "danger", duration: 2600 });
    return toast.present();
  }

  approvingApplication.value = true;
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    approvingApplication.value = false;
    const toast = await toastController.create({ message: "Sign in again to decline this application.", color: "danger", duration: 2600 });
    return toast.present();
  }
  const { error } = await supabase
    .from("adoption_applications")
    .update({
      status: "rejected",
      review_notes: declineReason.value.trim(),
      reviewed_by: authData.user.id,
      reviewed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("id", application.id);
  approvingApplication.value = false;

  const toast = await toastController.create({
    message: error ? error.message : "Application declined. The reason is now visible to the adopter.",
    color: error ? "danger" : "success",
    duration: 2800,
  });
  await toast.present();
  if (!error) {
    await loadAdoptionApplications();
    await loadAdminStats();
    adoptionReviewModalOpen.value = false;
  }
};

const selectAppointment = (appointment: (typeof appointments.value)[number]) => {
  selectedAppointmentId.value = appointment.id;
  assessmentModalOpen.value = true;
  assessmentOutcome.value = (appointment.assessment?.outcome as typeof assessmentOutcome.value) || "approved_to_proceed";
  assessmentComment.value = appointment.assessment?.recommendations || "";
  for (const key of Object.keys(assessmentChecklist)) {
    assessmentChecklist[key] = Boolean(appointment.assessment?.checklist?.[key]);
  }
};

const saveAppointmentAssessment = async () => {
  const appointment = selectedAppointment.value;
  if (!appointment) return;
  if (!assessmentComment.value.trim()) {
    const toast = await toastController.create({
      message: "Add a comment explaining the assessment result before saving.",
      color: "danger",
      duration: 2600,
    });
    return toast.present();
  }

  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    const toast = await toastController.create({ message: "Sign in again to save this assessment.", color: "danger", duration: 2600 });
    return toast.present();
  }

  const { error } = await supabase.from("assessment_records").upsert({
    appointment_id: appointment.id,
    applicant_id: appointment.applicant_id,
    assessor_id: authData.user.id,
    outcome: assessmentOutcome.value,
    checklist: { ...assessmentChecklist },
    recommendations: assessmentComment.value.trim(),
    assessed_at: new Date().toISOString(),
  }, { onConflict: "appointment_id" });

  if (!error) {
    const { error: appointmentError } = await supabase
      .from("appointments")
      .update({ status: "completed", updated_at: new Date().toISOString() })
      .eq("id", appointment.id);
    if (appointmentError) {
      const toast = await toastController.create({ message: appointmentError.message, color: "danger", duration: 3000 });
      await toast.present();
      await loadAppointments();
      return;
    }
  }

  const toast = await toastController.create({
    message: error ? error.message : "Assessment saved. The result is available in the adopter's Appointments page.",
    color: error ? "danger" : "success",
    duration: 2600,
  });
  await toast.present();
  if (!error) {
    await loadAppointments();
    assessmentModalOpen.value = false;
  }
};

const appointmentOutcomeLabel = (outcome: string) => ({
  approved_to_proceed: "Eligible to proceed",
  additional_assessment_required: "More assessment required",
  not_approved: "Not eligible to adopt",
}[outcome] || outcome);

const appointmentOutcomeColor = (outcome: string) =>
  outcome === "approved_to_proceed" ? "success" : outcome === "not_approved" ? "danger" : "warning";

const notifyUnavailable = async (action: string) => {
  const toast = await toastController.create({
    message: `${action} requires a selected live record and completed required fields.`,
    color: "warning",
    duration: 2600,
  });
  await toast.present();
};

const loadAdminUsers = async () => {
  usersLoading.value = true;
  usersError.value = "";
  const { data, error } = await supabase.rpc("admin_list_users");
  if (error) {
    usersError.value = error.message;
    usersLoading.value = false;
    return;
  }
  users.value = (data || []) as AdminUser[];
  usersLoading.value = false;
};

const setUserActive = async (user: AdminUser) => {
  if (user.id === state.userId) return;
  const activating = !user.is_active;
  const alert = await alertController.create({
    header: `${activating ? "Unblock" : "Block"} ${user.full_name}?`,
    message: activating
      ? "This user will be able to sign in and use their account again."
      : "This disables the account's access to protected app data. Their records will be kept.",
    buttons: [
      { text: "Cancel", role: "cancel" },
      {
        text: activating ? "Unblock user" : "Block user",
        role: "confirm",
        handler: () => true,
      },
    ],
  });
  await alert.present();
  const { role: action } = await alert.onDidDismiss();
  if (action !== "confirm") return;

  updatingUserId.value = user.id;
  const { error } = await supabase.rpc("admin_set_user_active", {
    p_user_id: user.id,
    p_is_active: activating,
  });
  if (!error) {
    await loadAdminUsers();
  } else {
    const toast = await toastController.create({
      message: error.message,
      color: "danger",
      duration: 3200,
    });
    await toast.present();
  }
  updatingUserId.value = "";
};

const deleteUser = async (user: AdminUser) => {
  if (user.id === state.userId || user.role !== "adopter") return;
  const alert = await alertController.create({
    header: `Permanently delete ${user.full_name}?`,
    message: `This permanently deletes ${user.email} and cannot be undone. Enter the exact email address to confirm. Users with adoption, appointment, donation, or audit history cannot be deleted; block them instead.`,
    inputs: [
      {
        name: "email",
        type: "email",
        value: user.email,
        placeholder: user.email,
        attributes: { autocomplete: "off" },
      },
    ],
    buttons: [
      { text: "Cancel", role: "cancel" },
      {
        text: "Delete permanently",
        role: "confirm",
        cssClass: "alert-button-danger",
        handler: (values) =>
          String(values.email || "").trim().toLowerCase() === user.email.trim().toLowerCase(),
      },
    ],
  });
  await alert.present();
  const { role: action } = await alert.onDidDismiss();
  if (action !== "confirm") return;

  deletingUserId.value = user.id;
  const { error } = await supabase.rpc("admin_delete_empty_adopter", {
    p_user_id: user.id,
  });
  if (!error) {
    await loadAdminUsers();
    const toast = await toastController.create({
      message: `${user.email} was permanently deleted.`,
      color: "success",
      duration: 2800,
    });
    await toast.present();
  } else {
    const toast = await toastController.create({
      message: error.message,
      color: "danger",
      duration: 3600,
    });
    await toast.present();
  }
  deletingUserId.value = "";
};

const resetPetForm = () => {
  petForm.name = "";
  petForm.species = "Dog";
  petForm.breed = "";
  petForm.age = "";
  petForm.gender = "Male";
  petForm.size = "Medium";
  petForm.location = "";
  petForm.address = "";
  petForm.latitude = "";
  petForm.longitude = "";
  petForm.vaccinated = false;
  petForm.vaccines = "";
  petForm.rescueStory = "";
  petForm.videoDescription = "";
  petForm.observedTrait = "";
  petForm.published = true;
  selectedImageFile.value = null;
  selectedVideoFile.value = null;
};

const loadPetForm = () => {
  resetPetForm();
  const id = String(route.params.id || "");
  if (!id) return;
  const pet = pets.find((item) => item.id === id);
  if (!pet) return;
  petForm.name = pet.name;
  petForm.species = pet.species;
  petForm.breed = pet.breed;
  petForm.age = pet.age.match(/\d+/)?.[0] || "";
  petForm.gender = pet.gender;
  petForm.size = pet.size;
  petForm.location = pet.location;
  petForm.address = pet.address;
  petForm.latitude = pet.latitude?.toString() || "";
  petForm.longitude = pet.longitude?.toString() || "";
  petForm.vaccinated = Boolean(
    pet.vaccinationStatus &&
      !pet.vaccinationStatus.toLowerCase().includes("not"),
  );
  petForm.vaccines = pet.vaccinationStatus || "";
  petForm.rescueStory = pet.story;
  petForm.published = pet.status !== "Adopted";
};

const selectedFileFrom = async (event: Event) => {
  const component = event.target as EventTarget & {
    getInputElement?: () => Promise<HTMLInputElement>;
  };
  const input = await component.getInputElement?.();
  return input?.files?.[0] || null;
};

const selectPetImage = async (event: Event) => {
  selectedImageFile.value = await selectedFileFrom(event);
};

const selectPetVideo = async (event: Event) => {
  selectedVideoFile.value = await selectedFileFrom(event);
};

const selectPetLocation = (coordinates: { latitude: number; longitude: number }) => {
  petForm.latitude = coordinates.latitude.toFixed(6);
  petForm.longitude = coordinates.longitude.toFixed(6);
};

const savePet = async () => {
  if (
    !petForm.name.trim() ||
    !petForm.breed.trim() ||
    !petForm.age ||
    !petForm.location.trim() ||
    !petForm.address.trim() ||
    !petForm.latitude.trim() ||
    !petForm.longitude.trim() ||
    !petForm.rescueStory.trim()
  ) {
    const toast = await toastController.create({
      message: "Complete the pet details, exact shelter address, map pin, and rescue story.",
      color: "danger",
      duration: 2600,
    });
    return toast.present();
  }

  const latitude = Number(petForm.latitude);
  const longitude = Number(petForm.longitude);
  if (
    !Number.isFinite(latitude) ||
    latitude < -90 ||
    latitude > 90 ||
    !Number.isFinite(longitude) ||
    longitude < -180 ||
    longitude > 180
  ) {
    const toast = await toastController.create({
      message: "Enter valid coordinates: latitude from -90 to 90 and longitude from -180 to 180.",
      color: "danger",
      duration: 3000,
    });
    return toast.present();
  }

  const age = Number(petForm.age);
  if (!Number.isInteger(age) || age < 0 || age > 40) {
    const toast = await toastController.create({
      message: "Enter a valid age from 0 to 40 years.",
      color: "danger",
      duration: 2600,
    });
    return toast.present();
  }
  if (petForm.vaccinated && !petForm.vaccines.trim()) {
    const toast = await toastController.create({
      message: "List the vaccines already administered.",
      color: "danger",
      duration: 2600,
    });
    return toast.present();
  }

  const files = [selectedImageFile.value, selectedVideoFile.value].filter(
    (file): file is File => Boolean(file),
  );
  for (const file of files) {
    const isImage = file.type.startsWith("image/");
    const isVideo = file.type.startsWith("video/");
    if (!isImage && !isVideo) {
      const toast = await toastController.create({
        message: "Choose a JPG, PNG, WebP, MP4, or WebM file.",
        color: "danger",
        duration: 2600,
      });
      return toast.present();
    }
    const limit = isImage ? 10 * 1024 * 1024 : 100 * 1024 * 1024;
    if (file.size > limit) {
      const toast = await toastController.create({
        message: isImage ? "Images must be 10 MB or smaller." : "Videos must be 100 MB or smaller.",
        color: "danger",
        duration: 2600,
      });
      return toast.present();
    }
    if (isVideo && (!petForm.videoDescription.trim() || !petForm.observedTrait.trim())) {
      const toast = await toastController.create({
        message: "Add a video description and observed behavior before uploading.",
        color: "danger",
        duration: 2600,
      });
      return toast.present();
    }
  }

  savingPet.value = true;
  const { data: authData } = await supabase.auth.getUser();
  if (!authData.user) {
    savingPet.value = false;
    return;
  }

  const petPayload = {
    name: petForm.name.trim(),
    species: petForm.species,
    breed: petForm.breed.trim(),
    birth_date: `${new Date().getFullYear() - age}-01-01`,
    gender: petForm.gender,
    size: petForm.size,
    location: petForm.location.trim(),
    address: petForm.address.trim(),
    latitude,
    longitude,
    health_condition: petForm.vaccinated ? "Vaccinated" : "Not vaccinated",
    vaccination_status: petForm.vaccinated
      ? petForm.vaccines.trim()
      : "Not vaccinated",
    rescue_story: petForm.rescueStory.trim(),
    status: petForm.published ? "available" : "draft",
    is_published: petForm.published,
    updated_at: new Date().toISOString(),
  };
  const existingId = String(route.params.id || "");
  const result = existingId
    ? await supabase.from("pets").update(petPayload).eq("id", existingId).select("id").single()
    : await supabase
        .from("pets")
        .insert({ ...petPayload, created_by: authData.user.id })
        .select("id")
        .single();

  if (result.error || !result.data) {
    savingPet.value = false;
    const toast = await toastController.create({
      message: result.error?.message || "Unable to save the pet record.",
      color: "danger",
      duration: 3200,
    });
    return toast.present();
  }

  let mediaError: string | null = null;
  for (const file of files) {
    const isVideo = file.type.startsWith("video/");
    const bucket = isVideo ? "pet-videos" : "pet-images";
    const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "-");
    const storagePath = `${result.data.id}/${crypto.randomUUID()}-${safeName}`;
    const upload = await supabase.storage
      .from(bucket)
      .upload(storagePath, file, { contentType: file.type, upsert: false });
    if (upload.error) {
      mediaError = upload.error.message;
      break;
    } else if (isVideo) {
      const metadata = await supabase.from("pet_videos").insert({
        pet_id: result.data.id,
        storage_path: storagePath,
        description: petForm.videoDescription.trim(),
        observed_trait: petForm.observedTrait.trim(),
        uploaded_by: authData.user.id,
        verification_status: "verified",
        verified_by: authData.user.id,
        verified_at: new Date().toISOString(),
      });
      mediaError = metadata.error?.message || null;
    } else {
      const metadata = await supabase.from("pet_photos").insert({
        pet_id: result.data.id,
        storage_path: storagePath,
        alt_text: `${petForm.name}, a rescued ${petForm.breed}`,
        sort_order: 0,
      });
      mediaError = metadata.error?.message || null;
    }
    if (mediaError) break;
  }

  await loadCatalog();
  savingPet.value = false;
  const toast = await toastController.create({
    message: mediaError
      ? `Pet saved, but media upload failed: ${mediaError}`
      : "Pet record saved successfully.",
    color: mediaError ? "warning" : "success",
    duration: 3400,
  });
  await toast.present();
  if (!mediaError) router.push("/admin/pets");
};

const archivePet = async (pet: Pet) => {
  const alert = await alertController.create({
    header: `Archive ${pet.name}?`,
    message: "The pet will be removed from public listings. This action can be reversed in Supabase.",
    buttons: [
      { text: "Cancel", role: "cancel" },
      {
        text: "Archive",
        handler: async () => {
          const { error } = await supabase
            .from("pets")
            .update({ status: "archived", is_published: false })
            .eq("id", pet.id);
          if (!error) {
            const index = pets.findIndex((item) => item.id === pet.id);
            if (index >= 0) pets.splice(index, 1);
          }
          const toast = await toastController.create({
            message: error ? error.message : `${pet.name} was archived.`,
            color: error ? "danger" : "success",
            duration: 2200,
          });
          await toast.present();
        },
      },
    ],
  });
  await alert.present();
};

onMounted(() => {
  void Promise.all([loadAdminStats(), loadDashboardPets()]);
});
watch(section, (currentSection) => {
  if (currentSection === "users") loadAdminUsers();
  if (currentSection === "appointments") loadAppointments();
  if (currentSection === "applications") loadAdoptionApplications();
  if (currentSection === "adoptions") loadCompletedAdoptions();
  if (currentSection === "reports") loadReports();
  if (currentSection === "fundraising") loadAdminCampaigns();
  if (currentSection === "donations") loadDonations();
}, { immediate: true });
watch(() => route.params.id, loadPetForm, { immediate: true });
</script>

<template>
  <ion-page>
    <div class="admin-shell">
      <aside>
        <div class="admin-brand"><ion-icon :icon="pawOutline" /> FurEver Home</div>
        <div class="staff-label">Administrator workspace</div>
        <ion-list>
          <ion-item v-for="item in menu" :key="String(item[2])" button :router-link="String(item[2])" router-direction="root" :class="{ active: route.path === item[2] }">
            <ion-icon slot="start" :icon="item[0]" />
            <ion-label>{{ item[1] }}</ion-label>
          </ion-item>
        </ion-list>
        <ion-button fill="clear" @click="signOut">
          <ion-icon slot="start" :icon="logOutOutline" />Log out
        </ion-button>
      </aside>
      <ion-content>
        <header class="admin-top">
          <div><small>FurEver Home / {{ title }}</small><h1>{{ title }}</h1></div>
          <div class="staff"><span>{{ state.userName }}</span><b>{{ staffInitials }}</b></div>
        </header>
        <main>
          <template v-if="section === 'dashboard'">
            <div class="stats">
              <div v-for="stat in [
                ['Total rescued pets', dashboardPetCounts.total],
                ['Available pets', dashboardPetCounts.available],
                ['Adopted pets', dashboardPetCounts.adopted],
                ['Pending applications', adminStats.pendingApplications],
                ['Upcoming appointments', adminStats.upcomingAppointments],
                ['Active campaigns', campaigns.length],
                ['Confirmed donations', `₱${adminStats.confirmedDonations.toLocaleString()}`],
              ]" :key="stat[0]" class="surface"><span>{{ stat[0] }}</span><strong>{{ stat[1] }}</strong><small>Live Supabase data</small></div>
            </div>
            <div v-if="dashboardPetsError" class="empty surface" role="alert">
              <h2>Pet status summary unavailable</h2>
              <p>{{ dashboardPetsError }}</p>
            </div>
            <div v-if="!dashboardPetsError" class="charts">
              <div class="surface">
                <h2>Cats versus dogs</h2>
                <div class="donut"><span>{{ dashboardPetCounts.dogs }}<small>dogs</small></span></div>
              </div>
              <div class="surface">
                <h2>Adoption pipeline</h2>
                <div v-for="row in pipeline" :key="row[0]" class="bar-row">
                  <span>{{ row[0] }}</span><i><b :style="{ width: `${row[1]}%` }"></b></i><strong>{{ row[1] }}%</strong>
                </div>
              </div>
            </div>
          </template>

          <template v-else-if="section === 'pets'">
            <div class="toolbar">
              <ion-input v-model="recordName" fill="outline" placeholder="Search pets" />
              <ion-button router-link="/admin/pets/new">Add pet</ion-button>
            </div>
            <div class="table surface user-table">
              <div v-for="pet in pets" :key="pet.id" class="table-row">
                <img :src="pet.image" :alt="pet.name" />
                <div><strong>{{ pet.name }}</strong><small>{{ pet.breed }} · {{ pet.location }}</small></div>
                <span class="status-pill">{{ pet.status }}</span>
                <ion-button fill="clear" :router-link="`/admin/pets/${pet.id}/edit`">Edit</ion-button>
                <ion-button fill="clear" color="danger" @click="archivePet(pet)">Archive</ion-button>
              </div>
            </div>
          </template>

          <template v-else-if="section === 'pet-form'">
            <div class="admin-form surface">
              <h2>Pet record</h2>
              <ion-input v-model="petForm.name" fill="outline" label="Pet name *" label-placement="stacked" />
              <div class="two">
                <ion-select v-model="petForm.species" fill="outline" label="Species *" label-placement="stacked"><ion-select-option value="Dog">Dog</ion-select-option><ion-select-option value="Cat">Cat</ion-select-option></ion-select>
                <ion-input v-model="petForm.breed" fill="outline" label="Breed *" label-placement="stacked" />
              </div>
              <div class="three">
                <ion-input v-model="petForm.age" type="number" min="0" max="40" fill="outline" label="Age in years *" label-placement="stacked" />
                <ion-select v-model="petForm.gender" fill="outline" label="Sex *" label-placement="stacked"><ion-select-option value="Male">Male</ion-select-option><ion-select-option value="Female">Female</ion-select-option></ion-select>
                <ion-select v-model="petForm.size" fill="outline" label="Size *" label-placement="stacked"><ion-select-option value="Small">Small</ion-select-option><ion-select-option value="Medium">Medium</ion-select-option><ion-select-option value="Large">Large</ion-select-option></ion-select>
              </div>
              <ion-input v-model="petForm.location" fill="outline" label="Shelter name or area *" label-placement="stacked" />
              <ion-input v-model="petForm.address" fill="outline" label="Exact shelter address *" label-placement="stacked" />
              <div class="map-picker-copy">
                <strong>Pin the shelter on the map *</strong>
                <span>Click the map or enter the exact coordinates below. The address above is additional location information.</span>
                <span v-if="petForm.latitude && petForm.longitude">
                  Pin: {{ Number(petForm.latitude).toFixed(6) }}, {{ Number(petForm.longitude).toFixed(6) }}
                </span>
              </div>
              <div class="two">
                <ion-input
                  v-model="petForm.latitude"
                  type="number"
                  min="-90"
                  max="90"
                  step="any"
                  fill="outline"
                  label="Latitude *"
                  label-placement="stacked"
                  placeholder="13.389824"
                />
                <ion-input
                  v-model="petForm.longitude"
                  type="number"
                  min="-180"
                  max="180"
                  step="any"
                  fill="outline"
                  label="Longitude *"
                  label-placement="stacked"
                  placeholder="121.162206"
                />
              </div>
              <shelter-map
                :latitude="petMapCoordinates.latitude"
                :longitude="petMapCoordinates.longitude"
                interactive
                @select="selectPetLocation"
              />
              <ion-checkbox v-model="petForm.vaccinated" label-placement="end">Vaccinated</ion-checkbox>
              <ion-input v-if="petForm.vaccinated" v-model="petForm.vaccines" fill="outline" label="Vaccines administered *" label-placement="stacked" placeholder="Example: Rabies, DHPP, Bordetella" />
              <ion-textarea v-model="petForm.rescueStory" fill="outline" label="Rescue story *" label-placement="stacked" />
              <ion-input type="file" accept="image/jpeg,image/png,image/webp" fill="outline" label="Pet photo" label-placement="stacked" @ionChange="selectPetImage" />
              <ion-input type="file" accept="video/mp4,video/webm" fill="outline" label="Behavior video" label-placement="stacked" @ionChange="selectPetVideo" />
              <template v-if="selectedVideoFile">
                <ion-input v-model="petForm.observedTrait" fill="outline" label="Observed behavior *" label-placement="stacked" />
                <ion-textarea v-model="petForm.videoDescription" fill="outline" label="Video description *" label-placement="stacked" />
                <p class="upload-note">Videos uploaded by authorized staff are published as verified immediately.</p>
              </template>
              <ion-checkbox v-model="petForm.published" label-placement="end">Published and available</ion-checkbox>
              <ion-button :disabled="savingPet" @click="savePet">{{ savingPet ? "Saving and uploading…" : "Save pet" }}</ion-button>
            </div>
          </template>

          <template v-else-if="section === 'appointments'">
            <div v-if="appointmentsLoading" class="empty surface">
              <p>Loading appointment requests...</p>
            </div>
            <div v-else-if="appointmentsError" class="empty surface">
              <h2>Appointments unavailable</h2>
              <p>{{ appointmentsError }}</p>
            </div>
            <div v-else class="appointment-workspace">
              <section class="appointment-list surface">
                <h2>Appointment requests</h2>
                <p>Select a booking to review the adopter and record an assessment.</p>
                <button
                  v-for="appointment in appointments"
                  :key="appointment.id"
                  class="appointment-entry"
                  :class="{ selected: selectedAppointmentId === appointment.id }"
                  @click="selectAppointment(appointment)"
                >
                  <span class="appointment-entry-head">
                    <strong>{{ appointment.applicant?.full_name || "Adopter" }}</strong>
                    <ion-badge :color="appointment.assessment ? appointmentOutcomeColor(appointment.assessment.outcome) : 'warning'">
                      {{ appointment.assessment ? appointmentOutcomeLabel(appointment.assessment.outcome) : appointment.status.replaceAll("_", " ") }}
                    </ion-badge>
                  </span>
                  <span>{{ appointment.pet?.name || "Pet" }} · {{ appointment.pet?.breed || "" }}</span>
                  <small>{{ new Date(appointment.starts_at).toLocaleString() }} · {{ appointment.location }}</small>
                </button>
                <p v-if="!appointments.length" class="no-appointments">No appointments have been booked yet.</p>
              </section>

            </div>
          </template>

          <template v-else-if="section === 'applications'">
            <div v-if="adoptionApplicationsLoading" class="empty surface"><p>Loading adoption applications...</p></div>
            <div v-else-if="adoptionApplicationsError" class="empty surface">
              <h2>Applications unavailable</h2>
              <p>{{ adoptionApplicationsError }}</p>
            </div>
            <section v-else class="adoption-list surface">
              <div class="adoption-list-heading">
                <div>
                  <h2>Adoption applications</h2>
                  <p>Select an application to review the adopter's information.</p>
                </div>
                <span>{{ adoptionApplications.length }} submitted</span>
              </div>
              <button
                v-for="application in adoptionApplications"
                :key="application.id"
                class="adoption-entry"
                @click="selectAdoptionApplication(application)"
              >
                <span class="adoption-entry-main">
                  <strong>{{ application.applicant?.full_name || String(application.form_data.full_name || "Adopter") }}</strong>
                  <span>{{ application.pet?.name || "Pet" }} · {{ application.pet?.breed || "" }}</span>
                  <small>Submitted {{ new Date(application.created_at).toLocaleString() }}</small>
                </span>
                <ion-badge :color="['approved', 'adoption_completed'].includes(application.status) ? 'success' : application.status === 'rejected' ? 'danger' : 'warning'">
                  {{ application.status.replaceAll("_", " ") }}
                </ion-badge>
              </button>
              <div v-if="!adoptionApplications.length" class="adoption-empty">
                No adoption applications have been submitted yet.
              </div>
            </section>
          </template>

          <template v-else-if="section === 'adoptions'">
            <div v-if="completedAdoptionsLoading" class="empty surface"><p>Loading completed adoptions...</p></div>
            <div v-else-if="completedAdoptionsError" class="empty surface">
              <h2>Adoption records unavailable</h2>
              <p>{{ completedAdoptionsError }}</p>
            </div>
            <section v-else class="adoption-list surface">
              <div class="adoption-list-heading">
                <div>
                  <h2>Completed adoptions</h2>
                  <p>Pets matched with their adopters.</p>
                </div>
                <span>{{ completedAdoptions.length }} completed</span>
              </div>
              <article v-for="adoption in completedAdoptions" :key="adoption.id" class="completed-adoption-entry">
                <div>
                  <strong>{{ adoption.pet?.name || "Pet" }}</strong>
                  <span>{{ adoption.pet?.breed || "" }}</span>
                </div>
                <div>
                  <small>Adopted by</small>
                  <strong>{{ adoption.adopter?.full_name || "Adopter" }}</strong>
                </div>
                <small>Completed {{ new Date(adoption.completed_at).toLocaleDateString() }}</small>
              </article>
              <div v-if="!completedAdoptions.length" class="adoption-empty">
                No completed adoptions yet.
              </div>
            </section>
          </template>

          <template v-else-if="section === 'assessments'">
            <div class="admin-form surface">
              <h2>Assessment record</h2>
              <p>Only an authorized administrator can issue or change this result.</p>
              <ion-select v-model="assessment" fill="outline" label="Assessment outcome" label-placement="stacked">
                <ion-select-option value="approved">Approved to Proceed</ion-select-option>
                <ion-select-option value="additional">Additional Assessment Required</ion-select-option>
                <ion-select-option value="not-approved">Not Approved at This Time</ion-select-option>
              </ion-select>
              <ion-checkbox v-for="item in ['Understands pet care responsibilities', 'Suitable living environment', 'Household agreement', 'Financial readiness', 'Time for daily care', 'Experience or willingness to learn', 'Safe and permanent home']" :key="item" label-placement="end">{{ item }}</ion-checkbox>
              <ion-textarea fill="outline" label="Notes and recommendations" label-placement="stacked" />
              <ion-button :disabled="!assessment" @click="notifyUnavailable('Saving an assessment')">Save authorized result</ion-button>
            </div>
          </template>

          <template v-else-if="section === 'users'">
            <section class="user-management">
              <div class="toolbar">
                <ion-input
                  v-model="userSearch"
                  fill="outline"
                  aria-label="Search users"
                  placeholder="Search by name, email, or role"
                />
                <ion-button fill="outline" :disabled="usersLoading" @click="loadAdminUsers">
                  <ion-icon slot="start" :icon="refreshOutline" />
                  Refresh
                </ion-button>
              </div>
              <div v-if="usersLoading" class="empty surface">
                <ion-progress-bar type="indeterminate" />
                <p>Loading user accounts...</p>
              </div>
              <div v-else-if="usersError" class="empty surface" role="alert">
                <h2>User list unavailable</h2>
                <p>{{ usersError }}</p>
                <ion-button @click="loadAdminUsers">Retry</ion-button>
              </div>
              <div v-else class="table surface">
                <div class="adoption-list-heading">
                  <div>
                    <h2>User accounts</h2>
                    <p>Block access without deleting the user's adoption or donation history.</p>
                  </div>
                  <span>{{ filteredUsers.length }} users</span>
                </div>
                <div v-for="user in filteredUsers" :key="user.id" class="table-row user-row">
                  <div class="user-details">
                    <strong>{{ user.full_name }}</strong>
                    <small>{{ user.email }}</small>
                    <small>Joined {{ new Date(user.created_at).toLocaleDateString() }} · {{ user.role }}</small>
                  </div>
                  <ion-badge :color="user.is_active ? 'success' : 'medium'">
                    {{ user.is_active ? "Active" : "Blocked" }}
                  </ion-badge>
                  <ion-button
                    v-if="user.id !== state.userId"
                    :color="user.is_active ? 'danger' : 'success'"
                    fill="outline"
                    size="small"
                    :disabled="Boolean(updatingUserId)"
                    @click="setUserActive(user)"
                  >
                    {{ updatingUserId === user.id ? "Saving..." : user.is_active ? "Block" : "Unblock" }}
                  </ion-button>
                  <ion-badge v-else color="light">You</ion-badge>
                  <ion-button
                    v-if="user.id !== state.userId && user.role === 'adopter'"
                    color="danger"
                    fill="clear"
                    size="small"
                    :disabled="Boolean(updatingUserId) || Boolean(deletingUserId)"
                    @click="deleteUser(user)"
                  >
                    {{ deletingUserId === user.id ? "Deleting..." : "Delete" }}
                  </ion-button>
                </div>
                <p v-if="!filteredUsers.length" class="adoption-empty">
                  {{ users.length ? "No users match your search." : "No user accounts found." }}
                </p>
              </div>
            </section>
          </template>

          <template v-else-if="section === 'reports'">
            <div v-if="reportLoading" class="empty surface"><p>Loading live reports...</p></div>
            <div v-else-if="reportError" class="empty surface">
              <h2>Reports unavailable</h2>
              <p>{{ reportError }}</p>
              <ion-button @click="loadReports">Retry</ion-button>
            </div>
            <div v-else class="reports-page">
              <div class="report-toolbar surface">
                <ion-input v-model="reportFilters.startDate" type="date" fill="outline" label="From" label-placement="stacked" />
                <ion-input v-model="reportFilters.endDate" type="date" fill="outline" label="To" label-placement="stacked" />
                <ion-select v-model="reportFilters.species" fill="outline" label="Species" label-placement="stacked">
                  <ion-select-option value="all">All species</ion-select-option>
                  <ion-select-option value="Dog">Dogs</ion-select-option>
                  <ion-select-option value="Cat">Cats</ion-select-option>
                </ion-select>
                <ion-select v-model="reportFilters.petId" fill="outline" label="Pet" label-placement="stacked">
                  <ion-select-option value="all">All pets</ion-select-option>
                  <ion-select-option v-for="pet in reportPetOptions" :key="pet.id" :value="pet.id">{{ pet.name }}</ion-select-option>
                </ion-select>
                <div class="report-actions">
                  <ion-button fill="outline" :disabled="reportLoading" @click="loadReports">
                    <ion-icon slot="start" :icon="refreshOutline" />Refresh
                  </ion-button>
                  <ion-button :disabled="reportLoading" @click="exportReportsCsv">
                    <ion-icon slot="start" :icon="downloadOutline" />Export CSV
                  </ion-button>
                </div>
              </div>

              <div class="report-stats">
                <div class="surface"><span>Appointment requests</span><strong>{{ filteredReportAppointments.length }}</strong></div>
                <div class="surface"><span>Eligible assessments</span><strong>{{ filteredReportAssessments.filter((item) => item.outcome === 'approved_to_proceed').length }}</strong></div>
                <div class="surface"><span>Applications submitted</span><strong>{{ filteredReportApplications.length }}</strong></div>
                <div class="surface"><span>Applications approved</span><strong>{{ filteredReportApplications.filter((item) => ['approved', 'adoption_completed'].includes(item.status)).length }}</strong></div>
                <div class="surface"><span>Applications declined</span><strong>{{ filteredReportApplications.filter((item) => item.status === 'rejected').length }}</strong></div>
                <div class="surface"><span>Completed adoptions</span><strong>{{ filteredReportAdoptions.length }}</strong></div>
                <div class="surface"><span>Donation transactions</span><strong>{{ reportDonationTotals.count }}</strong></div>
                <div class="surface"><span>Confirmed donations</span><strong>₱{{ reportDonationTotals.confirmedAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</strong></div>
                <div class="surface"><span>Pending donations</span><strong>{{ reportDonationTotals.pendingCount }}</strong></div>
                <div class="surface"><span>Failed / refunded</span><strong>{{ reportDonationTotals.failedCount }}</strong></div>
              </div>

              <div class="report-grid">
                <section class="report-panel surface">
                  <h2>Adoption funnel</h2>
                  <div v-for="item in [
                    ['Appointment requests', filteredReportAppointments.length],
                    ['Eligible assessments', filteredReportAssessments.filter((row) => row.outcome === 'approved_to_proceed').length],
                    ['Applications submitted', filteredReportApplications.length],
                    ['Approved applications', filteredReportApplications.filter((row) => ['approved', 'adoption_completed'].includes(row.status)).length],
                    ['Declined applications', filteredReportApplications.filter((row) => row.status === 'rejected').length],
                    ['Completed adoptions', filteredReportAdoptions.length],
                  ]" :key="item[0]" class="report-row">
                    <span>{{ item[0] }}</span><strong>{{ item[1] }}</strong>
                  </div>
                </section>

                <section class="report-panel surface">
                  <h2>Current pet status</h2>
                  <div v-for="status in ['available', 'on_hold', 'adopted', 'archived']" :key="status" class="report-row">
                    <span>{{ status.replaceAll('_', ' ') }}</span>
                    <strong>{{ filteredReportPets.filter((pet) => pet.status === status).length }}</strong>
                  </div>
                </section>

                <section class="report-panel surface">
                  <h2>Recent appointments</h2>
                  <div v-if="filteredReportAppointments.length" class="report-record-list">
                    <div v-for="appointment in filteredReportAppointments.slice(0, 8)" :key="appointment.id" class="report-record">
                      <span><strong>{{ appointment.pet?.name || 'Pet' }}</strong><small>{{ new Date(appointment.starts_at).toLocaleString() }}</small></span>
                      <ion-badge color="warning">{{ appointment.status.replaceAll('_', ' ') }}</ion-badge>
                    </div>
                  </div>
                  <p v-else class="report-empty">No appointments in this date range.</p>
                </section>

                <section class="report-panel surface">
                  <h2>Decline reasons</h2>
                  <div v-if="filteredReportApplications.some((item) => item.status === 'rejected')" class="report-record-list">
                    <div v-for="application in filteredReportApplications.filter((item) => item.status === 'rejected').slice(0, 8)" :key="application.id" class="report-record decline-record">
                      <span><strong>{{ application.pet?.name || 'Pet' }}</strong><small>{{ application.review_notes || 'No review reason provided' }}</small></span>
                    </div>
                  </div>
                  <p v-else class="report-empty">No declined applications in this date range.</p>
                </section>

                <section class="report-panel surface report-wide">
                  <h2>Donation transactions</h2>
                  <p class="report-note">Showing donations created within the selected date range. Only confirmed payments count toward fundraising totals.</p>
                  <div v-if="filteredReportDonations.length" class="transaction-table-wrap">
                    <table class="transaction-table">
                      <thead>
                        <tr>
                          <th>Date</th>
                          <th>Donor</th>
                          <th>Campaign</th>
                          <th>Payment method</th>
                          <th>Reference</th>
                          <th>Status</th>
                          <th class="amount-cell">Amount</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="donation in filteredReportDonations" :key="donation.id">
                          <td>{{ new Date(donation.created_at).toLocaleString() }}</td>
                          <td>
                            <strong>{{ donation.anonymous ? "Anonymous" : donation.donor_name || "Donor" }}</strong>
                            <small v-if="!donation.anonymous && donation.donor_email">{{ donation.donor_email }}</small>
                          </td>
                          <td>{{ donation.campaign?.title || "Campaign" }}</td>
                          <td>{{ donation.payment_provider || "Not recorded" }}</td>
                          <td>{{ donation.payment_reference || "—" }}</td>
                          <td>
                            <ion-badge :color="donation.payment_status === 'confirmed' ? 'success' : ['failed', 'refunded'].includes(donation.payment_status) ? 'danger' : 'warning'">
                              {{ donation.payment_status.replaceAll("_", " ") }}
                            </ion-badge>
                          </td>
                          <td class="amount-cell">₱{{ Number(donation.amount).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                  <p v-else class="report-empty">No donation transactions in this date range.</p>
                </section>

                <section class="report-panel surface report-wide">
                  <h2>Fundraising by campaign</h2>
                  <div v-if="reportDonationCampaigns.length" class="report-record-list">
                    <div v-for="campaign in reportDonationCampaigns" :key="campaign.title" class="report-record">
                      <span class="campaign-report-detail">
                        <strong>{{ campaign.title }}</strong>
                        <small>{{ campaign.confirmedCount }} confirmed donations · {{ campaign.status }}</small>
                        <span class="campaign-progress"><i :style="{ width: `${Math.min(100, campaign.raised / campaign.target * 100)}%` }"></i></span>
                      </span>
                      <strong>₱{{ campaign.raised.toLocaleString() }} / ₱{{ campaign.target.toLocaleString() }}</strong>
                    </div>
                  </div>
                  <p v-else class="report-empty">No donations in this date range.</p>
                  <small class="report-note">Campaign totals include confirmed donations only. Species and pet filters do not apply to donations.</small>
                </section>
              </div>
            </div>
          </template>

          <template v-else-if="section === 'fundraising'">
            <div v-if="adminCampaignsLoading" class="empty surface"><p>Loading fundraising campaigns...</p></div>
            <div v-else-if="adminCampaignsError" class="empty surface">
              <h2>Campaigns unavailable</h2>
              <p>{{ adminCampaignsError }}</p>
              <ion-button @click="loadAdminCampaigns">Retry</ion-button>
            </div>
            <div v-else class="campaign-admin">
              <section class="payment-settings surface">
                <div>
                  <h2>GCash payment instructions</h2>
                  <p>This number and QR code are shown to donors on the public fundraising page.</p>
                </div>
                <ion-input v-model="campaignPaymentSettings.gcashNumber" fill="outline" label="GCash number" label-placement="stacked" placeholder="09XX XXX XXXX" />
                <ion-input type="file" accept="image/png,image/jpeg,image/webp" fill="outline" label="Upload or replace GCash QR image" label-placement="stacked" @ionChange="selectQrFile" />
                <small v-if="selectedQrFile">Selected QR: {{ selectedQrFile.name }}</small>
                <img v-if="campaignQrUrl" class="admin-gcash-qr" :src="campaignQrUrl" alt="Current GCash donation QR code" />
                <div v-if="paymentSettingsError" class="payment-settings-warning" role="status">
                  {{ paymentSettingsError }}
                </div>
                <ion-button :disabled="savingPaymentSettings || Boolean(paymentSettingsError)" @click="saveCampaignPaymentSettings">
                  {{ savingPaymentSettings ? "Saving..." : "Save payment details" }}
                </ion-button>
              </section>
              <div class="campaign-admin-toolbar">
                <p>Manage campaign details, goals, dates, and public visibility.</p>
                <ion-button @click="openCampaignForm()">Create campaign</ion-button>
              </div>
              <div v-if="!adminCampaigns.length" class="empty surface">
                <ion-icon :icon="cashOutline" />
                <h2>No fundraising campaigns</h2>
                <p>Create a campaign to publish it on the public fundraising page.</p>
                <ion-button @click="openCampaignForm()">Create campaign</ion-button>
              </div>
              <div v-else class="campaign-admin-list">
                <article v-for="campaign in adminCampaigns" :key="campaign.id" class="campaign-admin-item surface">
                  <div class="campaign-admin-heading">
                    <div>
                      <ion-badge :color="campaign.status === 'published' ? 'success' : campaign.status === 'closed' ? 'medium' : 'warning'">
                        {{ campaign.status }}
                      </ion-badge>
                      <h2>{{ campaign.title }}</h2>
                      <p>{{ campaign.purpose }}</p>
                    </div>
                    <ion-button fill="outline" @click="openCampaignForm(campaign)">Edit campaign</ion-button>
                  </div>
                  <p class="campaign-admin-description">{{ campaign.description }}</p>
                  <ion-progress-bar :value="Math.min(1, campaign.raised / campaign.target_amount)" />
                  <div class="campaign-admin-meta">
                    <strong>₱{{ campaign.raised.toLocaleString() }} raised</strong>
                    <span>₱{{ campaign.target_amount.toLocaleString() }} goal</span>
                    <span>{{ campaign.starts_on }} to {{ campaign.ends_on }}</span>
                  </div>
                </article>
              </div>
            </div>
          </template>

          <template v-else-if="section === 'donations'">
            <div v-if="donationsLoading" class="empty surface"><p>Loading GCash submissions...</p></div>
            <div v-else-if="donationsError" class="empty surface">
              <h2>Donation submissions unavailable</h2>
              <p>{{ donationsError }}</p>
              <ion-button @click="loadDonations">Retry</ion-button>
            </div>
            <section v-else class="donation-admin-list surface">
              <div class="adoption-list-heading">
                <div>
                  <h2>GCash donation submissions</h2>
                  <p>Review each proof before confirming it in campaign totals.</p>
                </div>
                <span>{{ donations.filter((item) => item.payment_status === 'offline_pending').length }} pending</span>
              </div>
              <button v-for="donation in donations" :key="donation.id" class="donation-admin-entry" @click="selectDonationForReview(donation)">
                <span class="adoption-entry-main">
                  <strong>{{ donation.donor_name || "Donor" }} · ₱{{ Number(donation.amount).toLocaleString() }}</strong>
                  <span>{{ donation.campaign?.title || "Fundraising campaign" }}</span>
                  <small>{{ donation.donor_email }} · {{ new Date(donation.created_at).toLocaleString() }}</small>
                </span>
                <span class="donation-entry-actions">
                  <ion-badge :color="donation.payment_status === 'confirmed' ? 'success' : donation.payment_status === 'failed' ? 'danger' : 'warning'">
                    {{ donation.payment_status.replaceAll('_', ' ') }}
                  </ion-badge>
                  <span class="donation-review-action">Review proof</span>
                </span>
              </button>
              <div v-if="!donations.length" class="adoption-empty">No donation submissions yet.</div>
            </section>
          </template>

          <template v-else>
            <div class="empty surface">
              <ion-icon :icon="section === 'videos' ? filmOutline : section === 'fundraising' || section === 'donations' ? cashOutline : documentTextOutline" />
              <h2>{{ title }}</h2>
              <p>No live records are awaiting action in this section.</p>
            </div>
          </template>
        </main>
      </ion-content>
    </div>
    <ion-modal
      :is-open="assessmentModalOpen"
      class="assessment-modal"
      @didDismiss="assessmentModalOpen = false"
    >
      <ion-content v-if="selectedAppointment" class="assessment-modal-content">
        <div class="assessment-modal-inner">
          <header class="assessment-modal-header">
            <div>
              <div class="eyebrow">Appointment assessment</div>
              <h2>Adoption eligibility</h2>
            </div>
            <ion-button fill="clear" aria-label="Close assessment" @click="assessmentModalOpen = false">
              <ion-icon slot="icon-only" :icon="closeOutline" />
            </ion-button>
          </header>
          <div class="assessment-summary">
            <strong>{{ selectedAppointment.applicant?.full_name || "Adopter" }} · {{ selectedAppointment.pet?.name || "Pet" }}</strong>
            <span>{{ new Date(selectedAppointment.starts_at).toLocaleString() }} · {{ selectedAppointment.location }}</span>
            <span v-if="selectedAppointment.applicant?.phone">Contact: {{ selectedAppointment.applicant.phone }}</span>
            <p v-if="selectedAppointment.reason_for_adoption"><b>Reason for adopting:</b> {{ selectedAppointment.reason_for_adoption }}</p>
            <p v-if="selectedAppointment.pet_experience"><b>Pet experience:</b> {{ selectedAppointment.pet_experience }}</p>
            <p v-if="selectedAppointment.household_information"><b>Household:</b> {{ selectedAppointment.household_information }}</p>
            <p v-if="selectedAppointment.additional_notes"><b>Additional notes:</b> {{ selectedAppointment.additional_notes }}</p>
          </div>
          <ion-select v-model="assessmentOutcome" fill="outline" label="Eligibility result *" label-placement="stacked">
            <ion-select-option value="approved_to_proceed">Eligible to proceed</ion-select-option>
            <ion-select-option value="additional_assessment_required">Additional assessment required</ion-select-option>
            <ion-select-option value="not_approved">Not eligible to adopt</ion-select-option>
          </ion-select>
          <div class="assessment-checklist">
            <ion-checkbox v-model="assessmentChecklist.understands_responsibilities" label-placement="end">Understands pet care responsibilities</ion-checkbox>
            <ion-checkbox v-model="assessmentChecklist.suitable_living_environment" label-placement="end">Suitable living environment</ion-checkbox>
            <ion-checkbox v-model="assessmentChecklist.household_agreement" label-placement="end">Household agreement</ion-checkbox>
            <ion-checkbox v-model="assessmentChecklist.financial_readiness" label-placement="end">Financial readiness</ion-checkbox>
            <ion-checkbox v-model="assessmentChecklist.time_for_daily_care" label-placement="end">Time for daily care</ion-checkbox>
            <ion-checkbox v-model="assessmentChecklist.experience_or_willingness" label-placement="end">Experience or willingness to learn</ion-checkbox>
            <ion-checkbox v-model="assessmentChecklist.safe_permanent_home" label-placement="end">Safe and permanent home</ion-checkbox>
          </div>
          <ion-textarea
            v-model="assessmentComment"
            fill="outline"
            label="Comment for adopter *"
            label-placement="stacked"
            placeholder="Explain the result. This comment will be visible to the adopter."
            :auto-grow="true"
          />
          <ion-button expand="block" :disabled="!assessmentComment.trim()" @click="saveAppointmentAssessment">
            Save assessment and show result to adopter
          </ion-button>
        </div>
      </ion-content>
    </ion-modal>
    <ion-modal
      :is-open="adoptionReviewModalOpen"
      class="application-review-modal"
      @didDismiss="adoptionReviewModalOpen = false"
    >
      <ion-content v-if="selectedAdoptionApplication" class="application-review-content">
        <div class="application-review-inner">
          <header class="assessment-modal-header">
            <div>
              <div class="eyebrow">Adoption review</div>
              <h2>{{ selectedAdoptionApplication.pet?.name || "Pet" }} application</h2>
            </div>
            <ion-button fill="clear" aria-label="Close application" @click="adoptionReviewModalOpen = false">
              <ion-icon slot="icon-only" :icon="closeOutline" />
            </ion-button>
          </header>
          <div class="assessment-summary">
            <strong>{{ selectedAdoptionApplication.applicant?.full_name || "Adopter" }}</strong>
            <span>{{ selectedAdoptionApplication.applicant?.phone || "No contact number provided" }}</span>
            <span>Submitted {{ new Date(selectedAdoptionApplication.created_at).toLocaleString() }}</span>
            <span>Application status: {{ selectedAdoptionApplication.status.replaceAll("_", " ") }}</span>
          </div>
          <dl class="application-answers">
            <div v-for="field in adoptionApplicationFields" :key="field.label">
              <dt>{{ field.label }}</dt>
              <dd>{{ field.value || "Not provided" }}</dd>
            </div>
          </dl>
          <template v-if="['under_review', 'approved'].includes(selectedAdoptionApplication.status)">
            <ion-textarea
              v-if="selectedAdoptionApplication.status === 'under_review'"
              v-model="declineReason"
              fill="outline"
              label="Reason or comment for decline *"
              label-placement="stacked"
              placeholder="Explain what the adopter should correct before applying again."
              :auto-grow="true"
            />
            <div class="application-review-actions">
              <ion-button
                v-if="selectedAdoptionApplication.status === 'under_review'"
                color="danger"
                fill="outline"
                :disabled="approvingApplication || !declineReason.trim()"
                @click="declineAdoptionApplication"
              >
                {{ approvingApplication ? "Saving..." : "Decline application" }}
              </ion-button>
              <ion-button :disabled="approvingApplication" @click="approveAdoptionApplication">
                {{ approvingApplication ? "Completing..." : "Complete adoption" }}
              </ion-button>
            </div>
          </template>
          <ion-badge v-else :color="selectedAdoptionApplication.status === 'rejected' ? 'danger' : 'success'">
            {{ selectedAdoptionApplication.status.replaceAll("_", " ") }}
          </ion-badge>
        </div>
      </ion-content>
    </ion-modal>
    <ion-modal
      :is-open="campaignModalOpen"
      class="campaign-editor-modal"
      @didDismiss="campaignModalOpen = false"
    >
      <ion-content class="campaign-editor-content">
        <div class="campaign-editor-inner">
          <header class="assessment-modal-header">
            <div>
              <div class="eyebrow">Fundraising</div>
              <h2>{{ editingCampaignId ? "Edit campaign" : "Create campaign" }}</h2>
            </div>
            <ion-button fill="clear" aria-label="Close campaign editor" @click="campaignModalOpen = false">
              <ion-icon slot="icon-only" :icon="closeOutline" />
            </ion-button>
          </header>
          <ion-input v-model="campaignForm.title" fill="outline" label="Campaign title *" label-placement="stacked" />
          <ion-input v-model="campaignForm.purpose" fill="outline" label="Short purpose *" label-placement="stacked" />
          <ion-textarea v-model="campaignForm.description" fill="outline" label="Campaign description *" label-placement="stacked" :auto-grow="true" />
          <ion-input v-model="campaignForm.targetAmount" type="number" min="1" step="0.01" fill="outline" label="Fundraising goal (PHP) *" label-placement="stacked" />
          <div class="two">
            <ion-input v-model="campaignForm.startsOn" type="date" fill="outline" label="Start date *" label-placement="stacked" />
            <ion-input v-model="campaignForm.endsOn" type="date" fill="outline" label="End date *" label-placement="stacked" />
          </div>
          <ion-select v-model="campaignForm.status" fill="outline" label="Campaign status" label-placement="stacked">
            <ion-select-option value="draft">Draft</ion-select-option>
            <ion-select-option value="published">Published</ion-select-option>
            <ion-select-option value="closed">Closed</ion-select-option>
          </ion-select>
          <ion-button expand="block" :disabled="campaignSaving" @click="saveCampaign">
            {{ campaignSaving ? "Saving..." : "Save campaign" }}
          </ion-button>
        </div>
      </ion-content>
    </ion-modal>
    <ion-modal
      :is-open="donationReviewModalOpen"
      class="donation-review-modal"
      @didDismiss="donationReviewModalOpen = false"
    >
      <ion-content v-if="selectedDonation" class="donation-review-content">
        <div class="donation-review-inner">
          <header class="assessment-modal-header">
            <div>
              <div class="eyebrow">GCash payment review</div>
              <h2>Donation proof</h2>
            </div>
            <ion-button fill="clear" aria-label="Close donation review" @click="donationReviewModalOpen = false">
              <ion-icon slot="icon-only" :icon="closeOutline" />
            </ion-button>
          </header>
          <div class="assessment-summary">
            <strong>{{ selectedDonation.donor_name || "Donor" }} · ₱{{ Number(selectedDonation.amount).toLocaleString() }}</strong>
            <span>{{ selectedDonation.donor_email }}</span>
            <span>{{ selectedDonation.campaign?.title || "Fundraising campaign" }}</span>
            <span v-if="selectedDonation.payment_reference">GCash reference: {{ selectedDonation.payment_reference }}</span>
            <span>{{ selectedDonation.anonymous ? "Anonymous on public supporter list" : "Masked supporter listing after confirmation" }}</span>
            <p v-if="selectedDonation.message">Message: {{ selectedDonation.message }}</p>
          </div>
          <div v-if="donationProofUrl" class="donation-proof-preview">
            <a :href="donationProofUrl" target="_blank" rel="noreferrer">Open original proof</a>
            <img v-if="!selectedDonation.proof_storage_path?.toLowerCase().endsWith('.pdf')" :src="donationProofUrl" alt="Donor's GCash proof of payment" />
          </div>
          <p v-else class="report-empty">No proof of payment is attached.</p>
          <div v-if="selectedDonation.payment_status === 'offline_pending'" class="application-review-actions">
            <ion-button color="danger" fill="outline" :disabled="reviewingDonation" @click="reviewDonation(false)">
              {{ reviewingDonation ? "Saving..." : "Decline proof" }}
            </ion-button>
            <ion-button :disabled="reviewingDonation || !selectedDonation.proof_storage_path" @click="reviewDonation(true)">
              {{ reviewingDonation ? "Saving..." : "Confirm donation" }}
            </ion-button>
          </div>
          <ion-badge v-else :color="selectedDonation.payment_status === 'confirmed' ? 'success' : 'danger'">
            {{ selectedDonation.payment_status.replaceAll('_', ' ') }}
          </ion-badge>
        </div>
      </ion-content>
    </ion-modal>
  </ion-page>
</template>

<style scoped>
.admin-shell {
  display: grid;
  height: 100%;
  grid-template-columns: 260px 1fr;
  background: var(--cream);
}

aside {
  display: flex;
  height: 100vh;
  flex-direction: column;
  border-right: 1px solid var(--border);
  background: #fffdfa;
  color: var(--ion-color-secondary);
}

.admin-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 28px 22px 8px;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.3rem;
  font-weight: 700;
}

.staff-label {
  padding: 0 22px 18px;
  color: var(--ink-muted);
  font-size: 0.72rem;
}

aside ion-list {
  flex: 1;
  background: transparent;
}

aside ion-item {
  --background: transparent;
  --color: var(--ion-color-secondary);
  --border-color: transparent;
  --border-radius: 8px;
  --padding-start: 14px;
  margin: 3px 10px;
  transition: transform 180ms ease, box-shadow 180ms ease;
}

aside ion-item:hover {
  transform: translateX(3px);
}

aside ion-item.active {
  --background: #fff0e6;
  --color: var(--ion-color-primary);
  font-weight: 750;
}

aside ion-item ion-icon {
  color: var(--ion-color-primary);
}

aside > ion-button {
  --color: var(--ink-muted);
  margin: 12px 14px 18px;
}

.admin-top {
  display: flex;
  height: 94px;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid var(--border);
  background: rgba(255, 253, 249, 0.96);
  padding: 0 34px;
  box-shadow: 0 1px 0 var(--border);
}

.admin-top small {
  color: var(--ink-muted);
}

.admin-top h1 {
  margin: 5px 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.8rem;
}

.staff {
  display: flex;
  align-items: center;
  gap: 12px;
}

.staff b {
  display: grid;
  width: 42px;
  height: 42px;
  place-items: center;
  border-radius: 50%;
  background: var(--cream-deep);
  color: var(--ion-color-secondary);
}

main {
  padding: 28px 34px 70px;
  animation: admin-content-in 420ms cubic-bezier(0.2, 0.7, 0.2, 1) both;
}

.backend-note {
  margin-bottom: 22px;
  border-radius: 10px;
  background: #fff3d6;
  padding: 12px;
  color: #69481d;
  font-size: 0.82rem;
}

.stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 18px;
}

.stats > div {
  display: grid;
  gap: 7px;
  padding: 22px;
  animation: admin-content-in 520ms cubic-bezier(0.2, 0.7, 0.2, 1) both;
  transition: transform 180ms ease, box-shadow 180ms ease;
}

.stats > div:hover,
.charts > div:hover {
  transform: translateY(-3px);
  box-shadow: 0 16px 38px rgba(76, 48, 37, 0.12);
}

.stats > div:nth-child(1) { animation-delay: 40ms; }
.stats > div:nth-child(2) { animation-delay: 90ms; }
.stats > div:nth-child(3) { animation-delay: 140ms; }
.stats > div:nth-child(4) { animation-delay: 190ms; }
.stats > div:nth-child(5) { animation-delay: 240ms; }
.stats > div:nth-child(6) { animation-delay: 290ms; }

.charts > div {
  animation: admin-content-in 560ms 300ms cubic-bezier(0.2, 0.7, 0.2, 1) both;
  transition: transform 180ms ease, box-shadow 180ms ease;
}

.donut {
  animation: chart-pop 700ms 420ms cubic-bezier(0.2, 0.8, 0.2, 1) both;
}

.bar-row b {
  transform: scaleX(0);
  transform-origin: left center;
  animation: bar-grow 850ms 480ms cubic-bezier(0.2, 0.8, 0.2, 1) forwards;
}

.stats span,
.stats small {
  color: var(--ink-muted);
}

.stats strong {
  color: var(--ion-color-secondary);
  font-size: 2rem;
}

.reports-page {
  display: grid;
  gap: 18px;
}

.report-toolbar {
  display: grid;
  grid-template-columns: repeat(4, minmax(120px, 1fr)) auto;
  align-items: end;
  gap: 14px;
  padding: 18px;
}

.report-actions {
  display: flex;
  gap: 8px;
}

.report-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 14px;
}

.report-stats > div {
  display: grid;
  gap: 8px;
  padding: 18px;
}

.report-stats span {
  color: var(--ink-muted);
  font-size: 0.85rem;
}

.report-stats strong {
  color: var(--ion-color-secondary);
  font-size: 1.8rem;
}

.report-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.report-panel {
  min-width: 0;
  padding: 20px;
}

.report-panel h2 {
  margin: 0 0 14px;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.25rem;
}

.report-wide {
  grid-column: 1 / -1;
}

.transaction-table-wrap {
  max-width: 100%;
  overflow-x: auto;
}

.transaction-table {
  width: 100%;
  border-collapse: collapse;
  text-align: left;
  white-space: nowrap;
}

.transaction-table th,
.transaction-table td {
  border-bottom: 1px solid var(--border);
  padding: 12px 10px;
  vertical-align: middle;
}

.transaction-table th {
  color: var(--ink-muted);
  font-size: 0.8rem;
  font-weight: 700;
}

.transaction-table td {
  color: var(--ion-color-secondary);
  font-size: 0.88rem;
}

.transaction-table td small {
  display: block;
  margin-top: 4px;
  color: var(--ink-muted);
}

.transaction-table .amount-cell {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.report-row,
.report-record {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  border-top: 1px solid var(--border);
  padding: 12px 2px;
  color: var(--ion-color-secondary);
}

.report-row strong,
.report-record > strong {
  flex-shrink: 0;
}

.report-record-list {
  display: grid;
}

.report-record > span {
  display: grid;
  min-width: 0;
  gap: 4px;
}

.campaign-report-detail {
  flex: 1;
}

.campaign-progress {
  display: block;
  height: 7px;
  overflow: hidden;
  border-radius: 99px;
  background: var(--cream-deep);
}

.campaign-progress i {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--ion-color-primary);
}

.report-record small,
.report-note,
.report-empty {
  color: var(--ink-muted);
}

.report-record small {
  overflow-wrap: anywhere;
}

.decline-record {
  align-items: flex-start;
}

.report-note {
  display: block;
  margin-top: 12px;
  line-height: 1.5;
}

.report-empty {
  margin: 0;
  border-top: 1px solid var(--border);
  padding: 14px 2px;
}

.charts {
  display: grid;
  grid-template-columns: 0.8fr 1.2fr;
  gap: 18px;
  margin-top: 18px;
}

.charts > div,
.admin-form,
.empty {
  padding: 28px;
}

.charts h2,
.admin-form h2,
.empty h2 {
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
}

.donut {
  display: grid;
  width: 180px;
  height: 180px;
  margin: 20px auto;
  place-items: center;
  border: 28px solid var(--ion-color-primary);
  border-right-color: var(--cream-deep);
  border-radius: 50%;
}

.donut span {
  text-align: center;
  font-size: 1.7rem;
  font-weight: 800;
}

.donut small {
  display: block;
  color: var(--ink-muted);
  font-size: 0.7rem;
}

.bar-row {
  display: grid;
  grid-template-columns: 90px 1fr 45px;
  align-items: center;
  gap: 10px;
  margin: 24px 0;
}

.bar-row i {
  height: 10px;
  overflow: hidden;
  border-radius: 99px;
  background: var(--cream-deep);
}

.bar-row b {
  display: block;
  height: 100%;
  border-radius: 99px;
  background: var(--ion-color-primary);
}

.toolbar {
  display: flex;
  gap: 14px;
  margin-bottom: 20px;
}

.appointment-workspace {
  max-width: 980px;
}

.appointment-list {
  min-width: 0;
  padding: 22px;
}

.appointment-list h2,
.assessment-form h2 {
  margin-top: 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
}

.appointment-list > p {
  color: var(--ink-muted);
  font-size: 0.88rem;
}

.appointment-entry {
  display: grid;
  width: 100%;
  gap: 8px;
  border: 0;
  border-bottom: 1px solid var(--border);
  border-radius: 0;
  background: transparent;
  padding: 15px 10px;
  color: var(--ion-color-secondary);
  font: inherit;
  text-align: left;
  cursor: pointer;
}

.appointment-entry:last-of-type {
  border-bottom: 0;
}

.appointment-entry.selected {
  border-left: 3px solid var(--ion-color-primary);
  background: #fff4ed;
  padding-left: 12px;
}

.appointment-entry-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.appointment-entry-head ion-badge {
  flex-shrink: 0;
  text-transform: capitalize;
}

.appointment-entry small {
  color: var(--ink-muted);
}

.adoption-list {
  max-width: 980px;
  padding: 22px;
}

.adoption-list-heading,
.adoption-entry {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.adoption-list-heading {
  margin-bottom: 12px;
}

.adoption-list-heading h2 {
  margin: 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
}

.adoption-list-heading p {
  margin: 7px 0 0;
  color: var(--ink-muted);
}

.adoption-list-heading > span {
  flex-shrink: 0;
  color: var(--ink-muted);
  font-size: 0.85rem;
}

.adoption-entry {
  width: 100%;
  border: 0;
  border-top: 1px solid var(--border);
  background: transparent;
  padding: 16px 10px;
  color: var(--ion-color-secondary);
  font: inherit;
  text-align: left;
  cursor: pointer;
}

.adoption-entry:hover {
  background: #fff4ed;
}

.adoption-entry-main {
  display: grid;
  gap: 5px;
}

.adoption-entry-main small {
  color: var(--ink-muted);
}

.adoption-entry ion-badge {
  flex-shrink: 0;
  text-transform: capitalize;
}

.adoption-empty {
  border-top: 1px solid var(--border);
  padding: 20px 10px;
  color: var(--ink-muted);
}

.completed-adoption-entry {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) auto;
  align-items: center;
  gap: 18px;
  border-top: 1px solid var(--border);
  padding: 16px 10px;
}

.completed-adoption-entry > div {
  display: grid;
  gap: 4px;
}

.completed-adoption-entry span,
.completed-adoption-entry small {
  color: var(--ink-muted);
}

.completed-adoption-entry > div:nth-child(2) strong {
  color: var(--ion-color-primary);
}

.completed-adoption-entry > small {
  text-align: right;
}

.campaign-admin {
  display: grid;
  max-width: 1080px;
  gap: 18px;
}

.campaign-admin-toolbar,
.campaign-admin-heading,
.campaign-admin-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.campaign-admin-toolbar p {
  margin: 0;
  color: var(--ink-muted);
}

.campaign-admin-list {
  display: grid;
  gap: 14px;
}

.campaign-admin-item {
  display: grid;
  gap: 14px;
  padding: 20px;
}

.campaign-admin-heading {
  align-items: flex-start;
}

.campaign-admin-heading h2 {
  margin: 9px 0 4px;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.5rem;
}

.campaign-admin-heading p,
.campaign-admin-description {
  margin: 0;
  color: var(--ink-muted);
  line-height: 1.5;
}

.campaign-admin-item ion-progress-bar {
  height: 9px;
  border-radius: 99px;
}

.campaign-admin-meta {
  flex-wrap: wrap;
  color: var(--ink-muted);
  font-size: 0.88rem;
}

.campaign-admin-meta strong {
  color: var(--ion-color-primary);
}

.payment-settings {
  display: grid;
  max-width: 680px;
  gap: 14px;
  padding: 22px;
}

.payment-settings h2 {
  margin: 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
}

.payment-settings p {
  margin: 6px 0 0;
  color: var(--ink-muted);
}

.admin-gcash-qr {
  width: min(100%, 240px);
  max-height: 260px;
  object-fit: contain;
}

.donation-admin-list {
  max-width: 1080px;
  padding: 22px;
}

.donation-admin-entry {
  display: flex;
  width: 100%;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  border: 0;
  border-top: 1px solid var(--border);
  background: transparent;
  padding: 16px 10px;
  color: var(--ion-color-secondary);
  font: inherit;
  text-align: left;
  cursor: pointer;
}

.donation-admin-entry:hover {
  background: #fff4ed;
}

.donation-entry-actions {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  gap: 12px;
}

.donation-review-action {
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 7px 10px;
  color: var(--ion-color-secondary);
  font-size: 0.8rem;
  font-weight: 700;
}

ion-modal.donation-review-modal {
  --width: min(720px, calc(100% - 32px));
  --height: min(88vh, 820px);
  --border-radius: 14px;
  --box-shadow: 0 24px 72px rgba(47, 38, 34, 0.24);
}

.donation-review-content {
  --background: #fffdfa;
}

.donation-review-inner {
  display: grid;
  max-width: 720px;
  gap: 18px;
  margin-inline: auto;
  padding: 26px;
}

.donation-proof-preview {
  display: grid;
  justify-items: start;
  gap: 12px;
}

.donation-proof-preview img {
  width: min(100%, 520px);
  max-height: 56vh;
  border: 1px solid var(--border);
  border-radius: 8px;
  object-fit: contain;
}

ion-modal.campaign-editor-modal {
  --width: min(680px, calc(100% - 32px));
  --height: min(88vh, 800px);
  --border-radius: 14px;
  --box-shadow: 0 24px 72px rgba(47, 38, 34, 0.24);
}

.campaign-editor-content {
  --background: #fffdfa;
}

.campaign-editor-inner {
  display: grid;
  max-width: 680px;
  gap: 16px;
  margin-inline: auto;
  padding: 26px;
}

.no-appointments {
  padding: 14px 0;
}

.assessment-summary {
  display: grid;
  gap: 7px;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: #fbf8f4;
  padding: 16px;
}

.assessment-summary span,
.assessment-summary p {
  margin: 0;
  color: var(--ink-muted);
  line-height: 1.5;
}

.assessment-summary b {
  color: var(--ion-color-secondary);
}

.assessment-checklist {
  display: grid;
  gap: 12px;
  padding: 6px 2px;
}

ion-modal.assessment-modal {
  --width: min(760px, calc(100% - 32px));
  --height: min(88vh, 820px);
  --border-radius: 14px;
  --box-shadow: 0 24px 72px rgba(47, 38, 34, 0.24);
}

ion-modal.application-review-modal {
  --width: min(720px, calc(100% - 32px));
  --height: min(86vh, 780px);
  --border-radius: 14px;
  --box-shadow: 0 24px 72px rgba(47, 38, 34, 0.24);
}

.assessment-modal-content {
  --background: #fffdfa;
}

.application-review-content {
  --background: #fffdfa;
}

.assessment-modal-inner {
  display: grid;
  max-width: 760px;
  gap: 18px;
  margin-inline: auto;
  padding: 28px;
}

.application-review-inner {
  display: grid;
  max-width: 720px;
  gap: 18px;
  margin-inline: auto;
  padding: 28px;
}

.application-answers {
  display: grid;
  gap: 0;
  margin: 0;
  border-top: 1px solid var(--border);
}

.application-answers > div {
  display: grid;
  grid-template-columns: minmax(145px, 0.7fr) 1.3fr;
  gap: 14px;
  border-bottom: 1px solid var(--border);
  padding: 12px 4px;
}

.application-answers dt {
  color: var(--ink-muted);
  font-size: 0.9rem;
}

.application-answers dd {
  margin: 0;
  color: var(--ion-color-secondary);
  overflow-wrap: anywhere;
}

.application-review-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

.assessment-modal-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.assessment-modal-header h2 {
  margin: 5px 0 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 1.8rem;
}

.table-row {
  display: grid;
  grid-template-columns: 60px 1fr auto auto auto;
  align-items: center;
  gap: 16px;
  border-bottom: 1px solid var(--border);
  padding: 14px;
}

.user-row {
  grid-template-columns: minmax(0, 1fr) auto auto auto;
}

.user-details {
  min-width: 0;
  overflow-wrap: anywhere;
}

.table-row:last-child {
  border-bottom: 0;
}

.table-row img {
  width: 54px;
  height: 54px;
  border-radius: 12px;
  object-fit: cover;
}

.table-row strong,
.table-row small {
  display: block;
}

.table-row small {
  margin-top: 4px;
  color: var(--ink-muted);
}

.admin-form {
  display: grid;
  max-width: 760px;
  gap: 14px;
}

.admin-form p,
.empty p {
  color: var(--ink-muted);
}

.two {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
}

.three {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 14px;
}

.empty {
  text-align: center;
}

.empty > ion-icon {
  color: var(--ion-color-primary);
  font-size: 3rem;
}

@keyframes admin-content-in {
  from {
    opacity: 0;
    transform: translateY(10px);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes chart-pop {
  from {
    opacity: 0;
    transform: scale(0.88) rotate(-8deg);
  }

  to {
    opacity: 1;
    transform: scale(1) rotate(0);
  }
}

@keyframes bar-grow {
  to {
    transform: scaleX(1);
  }
}

@media (max-width: 850px) {
  .admin-shell {
    grid-template-columns: 78px 1fr;
  }

  .admin-brand,
  .staff-label,
  aside ion-label,
  aside > ion-button {
    display: none;
  }

  .stats {
    grid-template-columns: 1fr 1fr;
  }

  .charts {
    grid-template-columns: 1fr;
  }

  .report-toolbar {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .report-actions {
    grid-column: 1 / -1;
  }

  .report-stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .report-grid {
    grid-template-columns: 1fr;
  }

  .report-wide {
    grid-column: auto;
  }
}

@media (max-width: 620px) {
  .two,
  .three {
    grid-template-columns: 1fr;
  }

  .campaign-admin-toolbar,
  .campaign-admin-heading,
  .donation-admin-entry {
    align-items: stretch;
    flex-direction: column;
  }

  .completed-adoption-entry {
    grid-template-columns: 1fr 1fr;
  }

  .completed-adoption-entry > small {
    grid-column: 1 / -1;
    text-align: left;
  }

  .donation-entry-actions {
    justify-content: space-between;
  }

  .campaign-admin-meta {
    align-items: flex-start;
    flex-direction: column;
    gap: 8px;
  }
}

@media (max-width: 600px) {
  .report-toolbar,
  .report-stats {
    grid-template-columns: 1fr;
  }

  .report-actions {
    flex-direction: column;
  }

  .assessment-modal-inner {
    gap: 14px;
    padding: 20px 16px;
  }

  .application-review-inner {
    gap: 14px;
    padding: 20px 16px;
  }

  .campaign-editor-inner {
    gap: 14px;
    padding: 20px 16px;
  }

  .donation-review-inner {
    gap: 14px;
    padding: 20px 16px;
  }

  .application-answers > div {
    grid-template-columns: 1fr;
    gap: 5px;
  }

  .application-review-actions {
    flex-direction: column-reverse;
  }
}

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: 0.01ms !important;
  }
}
</style>
