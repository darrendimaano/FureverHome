# FurEver Home

FurEver Home is a responsive Ionic Vue web application for responsible cat and dog adoption. It includes public pet discovery, staff-reviewed behavior evidence, required physical assessment appointments, gated adoption applications, fundraising, adopter accounts, and an administrative workspace.

## Technology

- Ionic Framework and Ionic Vue
- Vue 3, TypeScript, Vue Router
- Vite
- Ionicons
- Supabase Auth, PostgreSQL, and Storage integration points

## Local setup

1. Install Node.js and pnpm versions defined in `.mise.toml`.
2. Install dependencies:

   ```bash
   pnpm install
   ```

3. Copy `.env.example` to `.env` and optionally add a Supabase project URL and public anonymous key.
4. Start the application:

   ```bash
   pnpm dev
   ```

5. Open the URL reported by Vite.

## Service availability

The application uses the connected Supabase project for authentication and live records. Features
that require an unconfigured external provider, such as online payments, remain disabled and never
claim a successful transaction.

## Supabase setup

1. Create a Supabase project.
2. Run the SQL files in `supabase/migrations/` in filename order in the SQL editor or with the
   Supabase CLI. Migration `012_pet_shelter_map_location.sql` adds the shelter address and map
   coordinates used by the staff pin picker and public pet details map. Migration
   `013_public_pet_video_visibility.sql` lets the public pet details page show pending-review
   behavior videos for published pets; it does not mark videos as verified. If an existing project
   still hides uploaded videos, also run `014_repair_public_pet_video_access.sql` to restore that
   read policy and add the optional video attribution column when absent. Migration
   `015_admin_user_management.sql` enables the admin user list and safe account deactivation/
   reactivation, and restricts app data access for inactive accounts. Migration
   `016_admin_delete_empty_adopter.sql` allows administrators to permanently delete adopter accounts
   only when they have no linked activity records; accounts with history must be blocked instead.
3. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
4. Configure email redirect URLs for `/reset-password`.
5. In **Authentication → Email Templates → Confirm signup**, set the subject to
   `Your FurEver Home verification code` and replace the template with
   `supabase/email-templates/confirm-signup.html`. The template uses `{{ .Token }}`
   so signup confirmation works with an 8-digit code instead of a localhost link.
   In **Reset password**, set the subject to `Reset your FurEver Home password` and use
   `supabase/email-templates/reset-password.html`. This template also uses `{{ .Token }}`
   and the application verifies it as an 8-digit recovery code without a redirect link.
6. Review Storage MIME type and file-size limits for `pet-images`, `pet-videos`, and `application-documents`.
7. Add payment-provider webhooks in a trusted server or Edge Function. Only that trusted layer should set `donations.payment_status` to `confirmed`.
8. Create the first administrator through a trusted database operation. Never expose or use the service-role key in browser code.

### Google sign-in

1. Create OAuth web credentials in Google Cloud Console.
2. Add the Supabase callback URL shown under **Authentication → Providers → Google** to the
   Google credential's authorized redirect URIs.
3. Enable the Google provider in Supabase and add the client ID and secret.
4. Add local and production app URLs to **Authentication → URL Configuration → Redirect URLs**.

New Google users are assigned the `adopter` role by the database profile trigger. Privileged
roles are never accepted from OAuth metadata.

The migration creates UUID keys, constraints, role helpers, row-level security policies, storage policies, and a confirmed-donation totals view. Before production, review policies against local legal requirements and test them with adopter, staff, administrator, and anonymous sessions.

## Application structure

```text
src/
  components/       Reusable Ionic Vue UI
  composables/       Shared reactive application state
  router/            Route definitions and role guards
  services/          Supabase client and live data services
  theme/             Ionic theme and shared responsive styles
  types/             Domain types
  views/
    public/          Landing, pets, fundraising, authentication
    adopter/         Dashboard, appointments, account workflows
    admin/           Protected staff workspace
supabase/
  migrations/        PostgreSQL schema, RLS, and storage policies
```

## Security notes

- Browser code uses only the public anonymous key.
- Adopters can read only their own private records.
- Staff authorization is checked through database roles and RLS, not UI visibility alone.
- Videos uploaded by authorized staff are marked verified immediately; only authorized staff can
  upload them, issue assessment results, or review applications.
- Completing an appointment does not grant adoption eligibility automatically.
- Applications cannot proceed without an authorized eligible assessment.
- Campaign totals derive only from confirmed donation records.
- Application documents and assessment notes are private.
