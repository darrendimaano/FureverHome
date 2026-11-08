import { createRouter, createWebHistory } from "@ionic/vue-router";
import type { RouteRecordRaw } from "vue-router";
import { useAppState } from "@/composables/useAppState";

const routes: RouteRecordRaw[] = [
  { path: "/", component: () => import("@/views/public/HomePage.vue") },
  { path: "/pets", component: () => import("@/views/public/PetsPage.vue") },
  { path: "/pets/:id", component: () => import("@/views/public/PetDetailsPage.vue") },
  { path: "/fundraising", component: () => import("@/views/public/FundraisingPage.vue") },
  { path: "/fundraising/:id", component: () => import("@/views/public/FundraisingPage.vue") },
  { path: "/login", component: () => import("@/views/public/AuthPage.vue"), meta: { mode: "login" } },
  { path: "/register", component: () => import("@/views/public/AuthPage.vue"), meta: { mode: "register" } },
  { path: "/verify-email", component: () => import("@/views/public/AuthPage.vue"), meta: { mode: "verify" } },
  { path: "/forgot-password", component: () => import("@/views/public/AuthPage.vue"), meta: { mode: "forgot" } },
  { path: "/reset-password", component: () => import("@/views/public/AuthPage.vue"), meta: { mode: "reset" } },
  { path: "/faq", name: "faq", component: () => import("@/views/public/InfoPage.vue"), meta: { title: "Frequently asked questions" } },
  { path: "/privacy", component: () => import("@/views/public/InfoPage.vue"), meta: { title: "Privacy policy" } },
  { path: "/dashboard", component: () => import("@/views/adopter/DashboardPage.vue"), meta: { auth: true } },
  { path: "/favorites", component: () => import("@/views/adopter/PortalPage.vue"), meta: { auth: true, title: "Favorite pets", section: "favorites" } },
  { path: "/appointments", component: () => import("@/views/adopter/PortalPage.vue"), meta: { auth: true, title: "Appointments", section: "appointments" } },
  { path: "/progress", component: () => import("@/views/adopter/PortalPage.vue"), meta: { auth: true, title: "Adoption progress", section: "progress" } },
  { path: "/appointments/book/:petId", component: () => import("@/views/adopter/AppointmentBookPage.vue"), meta: { auth: true } },
  { path: "/applications/new/:petId", component: () => import("@/views/adopter/AdoptionApplicationPage.vue"), meta: { auth: true, title: "Adoption application" } },
  { path: "/applications", component: () => import("@/views/adopter/PortalPage.vue"), meta: { auth: true, title: "Adoption applications", section: "applications" } },
  { path: "/applications/:id", component: () => import("@/views/adopter/PortalPage.vue"), meta: { auth: true, title: "Application details", section: "applications" } },
  { path: "/donations", component: () => import("@/views/adopter/PortalPage.vue"), meta: { auth: true, title: "Donation history", section: "donations" } },
  { path: "/profile", component: () => import("@/views/adopter/PortalPage.vue"), meta: { auth: true, title: "Profile", section: "profile" } },
  { path: "/notifications", component: () => import("@/views/adopter/PortalPage.vue"), meta: { auth: true, title: "Notifications", section: "notifications" } },
  { path: "/admin/dashboard", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Dashboard overview", section: "dashboard" } },
  { path: "/admin/pets", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Pet management", section: "pets" } },
  { path: "/admin/pets/new", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Add rescued pet", section: "pet-form" } },
  { path: "/admin/pets/:id/edit", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Edit pet record", section: "pet-form" } },
  { path: "/admin/videos", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Video review", section: "videos" } },
  { path: "/admin/appointments", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Appointment management", section: "appointments" } },
  { path: "/admin/assessments", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Assessment records", section: "assessments" } },
  { path: "/admin/applications", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Adoption applications", section: "applications" } },
  { path: "/admin/adoptions", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Completed adoptions", section: "adoptions" } },
  { path: "/admin/fundraising", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Fundraising campaigns", section: "fundraising" } },
  { path: "/admin/donations", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Donation records", section: "donations" } },
  { path: "/admin/users", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "User management", section: "users" } },
  { path: "/admin/reports", component: () => import("@/views/admin/AdminPage.vue"), meta: { staff: true, title: "Reports", section: "reports" } },
  { path: "/:pathMatch(.*)*", redirect: "/" },
];

const router = createRouter({ history: createWebHistory(import.meta.env.BASE_URL), routes });

router.beforeEach(async (to) => {
  const { state, restoreSession, refreshNotifications } = useAppState();
  await restoreSession();
  if (to.path === "/dashboard" && state.role === "admin") {
    return "/admin/dashboard";
  }
  if (to.meta.staff && state.role !== "admin") return "/login";
  if (to.meta.auth && state.role === "guest") return "/login";
  if (to.meta.auth && to.path !== "/notifications") await refreshNotifications();
  return true;
});

export default router;
