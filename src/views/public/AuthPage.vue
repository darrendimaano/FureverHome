<script setup lang="ts">
import { computed, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import {
  IonButton,
  IonCheckbox,
  IonContent,
  IonInput,
  IonIcon,
  IonPage,
  IonSpinner,
} from "@ionic/vue";
import { logoGoogle } from "ionicons/icons";
import SiteHeader from "@/components/SiteHeader.vue";
import { useAppState } from "@/composables/useAppState";
import { isGoogleAuthEnabled, supabase } from "@/services/supabase";

const route = useRoute();
const router = useRouter();
const { state, login } = useAppState();
const name = ref("");
const email = ref(String(route.query.email || ""));
const password = ref("");
const verificationCode = ref("");
const recoveryCode = ref("");
const accepted = ref(false);
const loading = ref(false);
const error = ref("");
const message = ref("");
const mode = computed(() => String(route.meta.mode || "login"));
const showPassword = computed(() => ["login", "register", "reset"].includes(mode.value));
const title = computed(() => {
  if (mode.value === "register") return "Create your adopter account";
  if (mode.value === "verify") return "Verify your email";
  if (mode.value === "forgot") return "Reset your password";
  if (mode.value === "reset") return "Choose a new password";
  return "Welcome back";
});
const actionLabel = computed(() => {
  if (mode.value === "login") return "Sign in";
  if (mode.value === "register") return "Create account";
  if (mode.value === "verify") return "Verify code";
  if (mode.value === "reset") return "Update password";
  return "Send recovery code";
});
const validNewPassword = () => {
  if (password.value.length < 8) {
    throw new Error("Password must contain at least 8 characters.");
  }
  if (!/[^A-Za-z0-9]/.test(password.value)) {
    throw new Error("Password must include at least one special character.");
  }
};

const submit = async () => {
  error.value = "";
  message.value = "";
  if (!email.value.includes("@")) {
    error.value = "Enter a valid email address.";
    return;
  }
  loading.value = true;
  try {
    if (mode.value === "login") {
      if (!password.value) throw new Error("Enter your password.");
      await login(email.value, password.value);
      router.push(state.role === "admin" ? "/admin/dashboard" : "/dashboard");
    } else if (mode.value === "register") {
      validNewPassword();
      if (!name.value.trim() || !accepted.value) {
        throw new Error("Enter your name and accept the responsible ownership agreement.");
      }
      const { data, error: signUpError } = await supabase.auth.signUp({
        email: email.value,
        password: password.value,
        options: { data: { full_name: name.value, role: "adopter" } },
      });
      if (signUpError) throw signUpError;
      if (data.user && Array.isArray(data.user.identities) && data.user.identities.length === 0) {
        throw new Error(
          "An account already exists for this email. Sign in, or use a different email address.",
        );
      }
      if (data.session) {
        router.push("/dashboard");
        return;
      }
      router.push({ path: "/verify-email", query: { email: email.value } });
    } else if (mode.value === "verify") {
      if (!/^\d{8}$/.test(verificationCode.value)) {
        throw new Error("Enter the 8-digit verification code from your email.");
      }
      const { error: verificationError } = await supabase.auth.verifyOtp({
        email: email.value,
        token: verificationCode.value,
        type: "signup",
      });
      if (verificationError) throw verificationError;
      message.value = "Email verified successfully. You can now sign in.";
      setTimeout(() => router.push("/login"), 1000);
    } else if (mode.value === "forgot") {
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email.value);
      if (resetError) throw resetError;
      router.push({ path: "/reset-password", query: { email: email.value } });
    } else {
      validNewPassword();
      if (!/^\d{8}$/.test(recoveryCode.value)) {
        throw new Error("Enter the 8-digit recovery code from your email.");
      }
      const { error: recoveryError } = await supabase.auth.verifyOtp({
        email: email.value,
        token: recoveryCode.value,
        type: "recovery",
      });
      if (recoveryError) throw recoveryError;
      const { error: updateError } = await supabase.auth.updateUser({ password: password.value });
      if (updateError) throw updateError;
      await supabase.auth.signOut();
      message.value = "Password updated successfully. You can now sign in.";
      setTimeout(() => router.push("/login"), 1000);
    }
  } catch (caught) {
    error.value = caught instanceof Error ? caught.message : "Unable to complete this request.";
  } finally {
    loading.value = false;
  }
};

const continueWithGoogle = async () => {
  error.value = "";
  loading.value = true;
  if (!(await isGoogleAuthEnabled())) {
    loading.value = false;
    error.value =
      "Google sign-in is not enabled yet. Configure the Google provider in Supabase Authentication first.";
    return;
  }
  const { error: oauthError } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: {
      redirectTo:
        import.meta.env.VITE_OAUTH_REDIRECT_URI ||
        `${window.location.origin}/dashboard`,
    },
  });
  if (oauthError) {
    loading.value = false;
    error.value =
      oauthError.message ||
      "Google sign-in is unavailable. Enable the Google provider in Supabase first.";
  }
};

const resendCode = async () => {
  error.value = "";
  message.value = "";
  if (!supabase || !email.value.includes("@")) {
    error.value = "Enter the email address used during registration.";
    return;
  }
  loading.value = true;
  const { error: resendError } = await supabase.auth.resend({
    type: "signup",
    email: email.value,
  });
  loading.value = false;
  if (resendError) {
    error.value = resendError.message;
    return;
  }
  message.value = "A new verification code was sent. Check your inbox and spam folder.";
};

const resendRecoveryCode = async () => {
  error.value = "";
  message.value = "";
  if (!email.value.includes("@")) {
    error.value = "Enter the email address linked to your account.";
    return;
  }
  loading.value = true;
  const { error: resendError } = await supabase.auth.resetPasswordForEmail(email.value);
  loading.value = false;
  if (resendError) {
    error.value = resendError.message;
    return;
  }
  message.value = "A new recovery code was sent. Check your inbox and spam folder.";
};

</script>

<template>
  <ion-page>
    <site-header />
    <ion-content id="main-content">
      <div class="auth-shell">
        <div class="auth-image">
          <img
            src="https://images.unsplash.com/photo-1648752007903-6b681160ca8e?auto=format&fit=crop&w=1000&q=82"
            alt="A rescued dog resting beside a cat"
          />
          <div>
            <strong>Better beginnings start with care.</strong>
            <p>Join a community committed to safe, responsible adoption.</p>
          </div>
        </div>
        <div class="auth-panel surface">
          <div class="eyebrow">FurEver Home</div>
          <h1>{{ title }}</h1>
          <p v-if="mode === 'login'">Sign in to manage favorites, appointments, and applications.</p>
          <p v-else-if="mode === 'verify'">
            Enter the 8-digit code sent to <strong>{{ email }}</strong>.
          </p>
          <p v-else-if="mode === 'reset'">
            Enter the recovery code sent to <strong>{{ email }}</strong>, then choose a new
            password.
          </p>
          <div v-if="error" class="error" role="alert">{{ error }}</div>
          <div v-if="message" class="success" role="status">{{ message }}</div>
          <ion-input
            v-if="mode === 'register'"
            v-model="name"
            fill="outline"
            label="Full name"
            label-placement="stacked"
          />
          <ion-input v-model="email" type="email" fill="outline" label="Email" label-placement="stacked" />
          <ion-input
            v-if="mode === 'verify'"
            v-model="verificationCode"
            type="text"
            inputmode="numeric"
            maxlength="8"
            fill="outline"
            label="8-digit verification code"
            label-placement="stacked"
            placeholder="00000000"
            autocomplete="one-time-code"
          />
          <ion-input
            v-if="mode === 'reset'"
            v-model="recoveryCode"
            type="text"
            inputmode="numeric"
            maxlength="8"
            fill="outline"
            label="8-digit recovery code"
            label-placement="stacked"
            placeholder="00000000"
            autocomplete="one-time-code"
          />
          <ion-input
            v-if="showPassword"
            v-model="password"
            type="password"
            fill="outline"
            :label="mode === 'reset' ? 'New password' : 'Password'"
            label-placement="stacked"
          />
          <small v-if="mode === 'register' || mode === 'reset'" class="password-hint">
            Use at least 8 characters and include one special character, such as !, @, #, or $.
          </small>
          <ion-checkbox v-if="mode === 'register'" v-model="accepted" label-placement="end">
            I agree to responsible pet ownership requirements.
          </ion-checkbox>
          <ion-button expand="block" size="large" :disabled="loading" @click="submit">
            <ion-spinner v-if="loading" name="crescent" />
            <span v-else>{{ actionLabel }}</span>
          </ion-button>
          <template v-if="mode === 'login' || mode === 'register'">
            <div class="auth-divider"><span>or</span></div>
            <ion-button expand="block" fill="outline" color="secondary" :disabled="loading" @click="continueWithGoogle">
              <ion-icon slot="start" :icon="logoGoogle" />
              Continue with Google
            </ion-button>
          </template>
          <ion-button v-if="mode === 'verify'" fill="clear" :disabled="loading" @click="resendCode">
            Send a new code
          </ion-button>
          <ion-button v-if="mode === 'reset'" fill="clear" :disabled="loading" @click="resendRecoveryCode">
            Send a new recovery code
          </ion-button>
          <ion-button v-if="mode === 'login'" fill="clear" router-link="/forgot-password">Forgot password?</ion-button>
          <ion-button v-if="mode === 'login'" fill="clear" router-link="/register">Create an account</ion-button>
          <ion-button v-else fill="clear" router-link="/login">Return to sign in</ion-button>
        </div>
      </div>
    </ion-content>
  </ion-page>
</template>

<style scoped>
.auth-shell {
  display: grid;
  min-height: calc(100vh - 76px);
  grid-template-columns: 1fr 1fr;
  align-items: stretch;
  background: var(--cream);
}

.auth-image {
  position: relative;
  overflow: hidden;
}

.auth-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.auth-image::after {
  position: absolute;
  inset: 0;
  background: linear-gradient(transparent 45%, rgba(49, 31, 23, 0.86));
  content: "";
}

.auth-image > div {
  position: absolute;
  z-index: 1;
  right: 60px;
  bottom: 60px;
  left: 60px;
  color: white;
}

.auth-image strong {
  font-family: Georgia, serif;
  font-size: 2.2rem;
}

.auth-panel {
  align-self: center;
  width: min(520px, calc(100% - 50px));
  margin: 50px auto;
  padding: 42px;
}

.auth-panel h1 {
  margin: 8px 0;
  color: var(--ion-color-secondary);
  font-family: Georgia, serif;
  font-size: 2.5rem;
}

.auth-panel > p {
  margin-bottom: 28px;
  color: var(--ink-muted);
}

.auth-panel ion-input,
.auth-panel ion-checkbox {
  margin-bottom: 14px;
}

.password-hint {
  display: block;
  margin: -5px 0 16px;
  color: var(--ink-muted);
  line-height: 1.5;
}

.auth-divider {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 14px 0;
  color: var(--ink-muted);
  font-size: 0.78rem;
  text-transform: uppercase;
}

.auth-divider::before,
.auth-divider::after {
  height: 1px;
  flex: 1;
  background: var(--border);
  content: "";
}

.error,
.success {
  margin: 16px 0;
  border-radius: 12px;
  padding: 13px;
  font-size: 0.84rem;
  line-height: 1.5;
}

.error {
  background: #fce7e5;
  color: #8c2f29;
}

.success {
  background: var(--success-soft);
  color: #3e5d37;
}

@media (max-width: 800px) {
  .auth-shell {
    grid-template-columns: 1fr;
  }

  .auth-image {
    display: none;
  }
}
</style>
