# FurEver Home

Ionic Vue 3, TypeScript, Vite, and Supabase-ready pet adoption application.

## Development

- Install dependencies with `pnpm install`.
- Start local development with `pnpm dev`.
- Create a production build with `pnpm build`.
- Format source files with `pnpm format`.

## Project structure

- `src/main.ts` initializes Vue, Ionic Vue, and Vue Router.
- `src/App.vue` contains the root Ionic router outlet.
- `src/router/` defines public, adopter, and staff routes.
- `src/components/` contains reusable Ionic Vue components.
- `src/views/public/` contains public website pages.
- `src/views/adopter/` contains authenticated adopter pages.
- `src/views/admin/` contains protected staff pages.
- `src/services/` contains mock data and the Supabase client boundary.
- `src/composables/` contains shared reactive application state.
- `src/theme/` contains Ionic theme variables and shared styles.
- `supabase/migrations/` contains the PostgreSQL schema and security policies.

## Code quality

- Use Vue single-file components with TypeScript.
- Keep database access outside view components.
- Use Ionic Vue components and Ionicons for controls and icons.
- Never expose private keys or Supabase service-role credentials in frontend code.
- Clearly label mock behavior and do not claim that unconfigured services succeeded.
- Preserve role-based route protection and database row-level security.
