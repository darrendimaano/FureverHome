import { createClient } from "@supabase/supabase-js";
import { projectId, publicAnonKey } from "../../utils/supabase/info";

const generatedUrl = projectId ? `https://${projectId}.supabase.co` : "";
const url = import.meta.env.VITE_SUPABASE_URL || generatedUrl;
const key = import.meta.env.VITE_SUPABASE_ANON_KEY || publicAnonKey;

if (!url || !key) {
  throw new Error(
    "Supabase project configuration is missing. Provide the public project URL and anonymous key.",
  );
}

export const isSupabaseConfigured = Boolean(url && key);
export const supabase = createClient(url, key, {
  auth: { persistSession: true, autoRefreshToken: true },
});

export async function isGoogleAuthEnabled() {
  const response = await fetch(`${url}/auth/v1/settings`, {
    headers: { apikey: key },
  });
  if (!response.ok) return false;
  const settings = await response.json();
  return settings.external?.google === true;
}
