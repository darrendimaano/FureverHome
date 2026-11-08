import { computed, reactive } from "vue";
import type { AppRole } from "@/types";
import { pets } from "@/services/catalog";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

type ActivityNotification = {
  id: string;
  title: string;
  text: string;
  link: string;
  createdAt: string;
  read: boolean;
};

const loadReadNotificationIds = (userId: string): Set<string> => {
  try {
    const stored = localStorage.getItem(`furever-home-read-notifications:${userId}`);
    const parsed: unknown = stored ? JSON.parse(stored) : [];
    return new Set(
      Array.isArray(parsed)
        ? parsed.filter((id): id is string => typeof id === "string")
        : [],
    );
  } catch (error) {
    console.error("Unable to load saved notification state.", error);
    throw new Error("Unable to load saved notification read status.");
  }
};

const state = reactive({
  role: "guest" as AppRole,
  userName: "",
  userId: "",
  sessionChecked: false,
  favorites: new Set<string>(),
  notifications: [] as ActivityNotification[],
});

export function useAppState() {
  const favoritePets = computed(() => pets.filter((pet) => state.favorites.has(pet.id)));

  const refreshNotifications = async (): Promise<string | null> => {
    if (!supabase) return "Notifications are unavailable because Supabase is not configured.";
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      state.notifications = [];
      return userError?.message || "Sign in to view your activity notifications.";
    }

    const userId = userData.user.id;
    const [appointmentResult, assessmentResult, applicationResult, donationResult] =
      await Promise.all([
        supabase
          .from("appointments")
          .select("id, status, starts_at, created_at, pet:pets(name)")
          .eq("applicant_id", userId)
          .order("created_at", { ascending: false }),
        supabase
          .from("assessment_records")
          .select("id, outcome, assessed_at, appointment:appointments(pet:pets(name))")
          .eq("applicant_id", userId)
          .order("assessed_at", { ascending: false }),
        supabase
          .from("adoption_applications")
          .select("id, status, created_at, updated_at, pet:pets(name)")
          .eq("applicant_id", userId)
          .neq("status", "draft")
          .order("updated_at", { ascending: false }),
        supabase
          .from("donations")
          .select("id, campaign_id, payment_status, created_at, campaign:fundraising_campaigns(title)")
          .eq("donor_id", userId)
          .order("created_at", { ascending: false }),
      ]);

    const queryError =
      appointmentResult.error ||
      assessmentResult.error ||
      applicationResult.error ||
      donationResult.error;
    if (queryError) return queryError.message;

    let readNotificationIds: Set<string>;
    try {
      readNotificationIds = loadReadNotificationIds(userId);
    } catch (error) {
      return error instanceof Error ? error.message : "Unable to load saved notification status.";
    }

    const notifications: ActivityNotification[] = [];
    for (const appointment of appointmentResult.data || []) {
      const petName = appointment.pet?.name || "your pet";
      const messages: Record<string, string> = {
        pending_confirmation: `Your assessment appointment for ${petName} is waiting for shelter confirmation.`,
        confirmed: `Your assessment appointment for ${petName} is confirmed.`,
        rescheduled: `Your assessment appointment for ${petName} was rescheduled.`,
        completed: `Your assessment appointment for ${petName} is complete.`,
        cancelled: `Your assessment appointment for ${petName} was cancelled.`,
        no_show: `Your appointment for ${petName} was marked as a no-show.`,
      };
      notifications.push({
        id: `appointment:${appointment.id}:${appointment.status}`,
        title: "Assessment appointment",
        text: messages[appointment.status] || `Your appointment for ${petName} was updated.`,
        link: "/appointments",
        createdAt: appointment.created_at,
        read: false,
      });
    }

    for (const assessment of assessmentResult.data || []) {
      const petName = assessment.appointment?.pet?.name || "your pet";
      const outcomes: Record<string, string> = {
        approved_to_proceed: "You are eligible to proceed with an adoption application.",
        additional_assessment_required: "The shelter requires an additional assessment.",
        not_approved: "The shelter has updated your assessment outcome.",
      };
      notifications.push({
        id: `assessment:${assessment.id}:${assessment.outcome}`,
        title: "Assessment update",
        text: `${petName}: ${outcomes[assessment.outcome] || assessment.outcome}.`,
        link: "/progress",
        createdAt: assessment.assessed_at,
        read: false,
      });
    }

    for (const application of applicationResult.data || []) {
      const petName = application.pet?.name || "your pet";
      const messages: Record<string, string> = {
        pending_assessment: `Your adoption application for ${petName} is waiting for assessment.`,
        assessment_required: `Your application for ${petName} needs an eligible assessment.`,
        under_review: `Your adoption application for ${petName} is under review.`,
        additional_information_required: `The shelter needs more information for your application for ${petName}.`,
        approved: `Your adoption application for ${petName} was approved.`,
        rejected: `Your adoption application for ${petName} was declined.`,
        adoption_completed: `The adoption of ${petName} is complete.`,
      };
      notifications.push({
        id: `application:${application.id}:${application.status}`,
        title: "Adoption application",
        text: messages[application.status] || `Your application for ${petName} was updated.`,
        link: "/applications",
        createdAt: application.updated_at || application.created_at,
        read: false,
      });
    }

    for (const donation of donationResult.data || []) {
      const campaign = donation.campaign?.title || "the fundraising campaign";
      const messages: Record<string, string> = {
        pending: `Your donation to ${campaign} is awaiting payment.`,
        offline_pending: `Your donation to ${campaign} is awaiting confirmation.`,
        confirmed: `Your donation to ${campaign} has been confirmed. Thank you for supporting the shelter.`,
        failed: `Your donation to ${campaign} was not confirmed. Please contact the shelter if you need help.`,
        refunded: `Your donation to ${campaign} has been refunded.`,
      };
      notifications.push({
        id: `donation:${donation.id}:${donation.payment_status}`,
        title: "Fundraising donation",
        text: messages[donation.payment_status] || `Your donation to ${campaign} was updated.`,
        link: `/fundraising/${donation.campaign_id}`,
        createdAt: donation.created_at,
        read: false,
      });
    }

    notifications.sort((left, right) => right.createdAt.localeCompare(left.createdAt));
    state.notifications = notifications.map((notification) => ({
      ...notification,
      read: readNotificationIds.has(notification.id),
    }));
    return null;
  };

  const persistReadNotificationIds = () => {
    if (!state.userId) return;
    try {
      localStorage.setItem(
        `furever-home-read-notifications:${state.userId}`,
        JSON.stringify(state.notifications.filter((item) => item.read).map((item) => item.id)),
      );
    } catch (error) {
      console.error("Unable to save notification read state.", error);
    }
  };

  const markNotificationRead = (id: string) => {
    const notification = state.notifications.find((item) => item.id === id);
    if (!notification || notification.read) return;
    notification.read = true;
    persistReadNotificationIds();
  };

  const markAllNotificationsRead = () => {
    state.notifications.forEach((notification) => {
      notification.read = true;
    });
    persistReadNotificationIds();
  };

  const toggleFavorite = (id: string) => {
    if (state.role === "guest") return false;
    if (state.favorites.has(id)) state.favorites.delete(id);
    else state.favorites.add(id);
    return true;
  };

  const login = async (email: string, password: string) => {
    if (!isSupabaseConfigured || !supabase) {
      throw new Error("Authentication is temporarily unavailable. Please try again later.");
    }
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("full_name, role, is_active")
      .eq("id", data.user.id)
      .maybeSingle();
    if (profileError || !profile || !profile.is_active) {
      await supabase.auth.signOut();
      throw new Error(
        profileError?.message || "This account is unavailable or has been deactivated.",
      );
    }
    state.userId = data.user.id;
    state.role = (profile?.role as AppRole) || "adopter";
    state.userName = profile?.full_name || email.split("@")[0] || "Adopter";
    state.sessionChecked = true;
    await refreshNotifications();
  };

  const restoreSession = async () => {
    state.sessionChecked = true;
    if (!supabase) return;

    const { data, error: sessionError } = await supabase.auth.getSession();
    if (sessionError) throw sessionError;
    const user = data.session?.user;
    if (!user) {
      state.role = "guest";
      state.userName = "";
      state.userId = "";
      state.notifications = [];
      return;
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("full_name, role, is_active")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || !profile.is_active) {
      await supabase.auth.signOut();
      state.role = "guest";
      state.userName = "";
      state.userId = "";
      state.notifications = [];
      return;
    }
    state.userId = user.id;
    state.role = (profile?.role as AppRole) || "adopter";
    state.userName =
      profile?.full_name ||
      user.user_metadata.full_name ||
      user.email?.split("@")[0] ||
      "Adopter";
    await refreshNotifications();
  };

  const logout = async () => {
    if (supabase) {
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
    }
    state.role = "guest";
    state.userName = "";
    state.userId = "";
    state.sessionChecked = true;
    state.notifications = [];
  };

  return {
    state,
    favoritePets,
    isSupabaseConfigured,
    refreshNotifications,
    markNotificationRead,
    markAllNotificationsRead,
    toggleFavorite,
    login,
    restoreSession,
    logout,
  };
}
