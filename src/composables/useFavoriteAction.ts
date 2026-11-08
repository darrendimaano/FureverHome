import { useRouter } from "vue-router";
import { alertController } from "@ionic/vue";
import { useAppState } from "@/composables/useAppState";

export function useFavoriteAction() {
  const router = useRouter();
  const { toggleFavorite } = useAppState();

  const handleFavorite = async (petId: string) => {
    if (toggleFavorite(petId)) return;

    const alert = await alertController.create({
      header: "Login required",
      message: "Please log in or sign up to add pets to your favorites.",
      buttons: [
        { text: "Log in", handler: () => router.push("/login") },
        { text: "Sign up", handler: () => router.push("/register") },
        { text: "Cancel", role: "cancel" },
      ],
    });
    await alert.present();
  };

  return { handleFavorite };
}
