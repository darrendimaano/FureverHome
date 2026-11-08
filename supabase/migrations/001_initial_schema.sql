create extension if not exists "pgcrypto";

create type public.app_role as enum ('adopter', 'staff', 'admin');
create type public.pet_status as enum ('draft', 'available', 'on_hold', 'adopted', 'archived');
create type public.review_status as enum ('pending', 'verified', 'rejected');
create type public.appointment_status as enum ('pending_confirmation', 'confirmed', 'rescheduled', 'completed', 'cancelled', 'no_show');
create type public.assessment_outcome as enum ('approved_to_proceed', 'additional_assessment_required', 'not_approved');
create type public.application_status as enum ('draft', 'pending_assessment', 'assessment_required', 'under_review', 'additional_information_required', 'approved', 'rejected', 'adoption_completed');
create type public.payment_status as enum ('pending', 'confirmed', 'failed', 'refunded', 'offline_pending');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  role public.app_role not null default 'adopter',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.pets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  species text not null check (species in ('Dog', 'Cat')),
  breed text not null,
  birth_date date,
  gender text check (gender in ('Male', 'Female', 'Unknown')),
  size text check (size in ('Small', 'Medium', 'Large')),
  location text not null,
  personality text,
  health_condition text,
  vaccination_status text,
  deworming_status text,
  sterilization_status text,
  feeding_preferences text,
  special_care text,
  rescue_story text,
  status public.pet_status not null default 'draft',
  is_published boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.pet_photos (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,
  storage_path text not null,
  alt_text text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.pet_videos (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,
  storage_path text not null,
  description text not null,
  observed_trait text not null,
  uploaded_by uuid not null references public.profiles(id),
  uploaded_at timestamptz not null default now(),
  verification_status public.review_status not null default 'pending',
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  rejection_reason text
);

create table public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  pet_id uuid not null references public.pets(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, pet_id)
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  applicant_id uuid not null references public.profiles(id),
  pet_id uuid not null references public.pets(id),
  starts_at timestamptz not null,
  location text not null,
  contact_number text not null,
  reason_for_adoption text,
  pet_experience text,
  household_information text,
  additional_notes text,
  status public.appointment_status not null default 'pending_confirmation',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (starts_at, location),
  unique (applicant_id, pet_id, starts_at)
);

create table public.assessment_records (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null unique references public.appointments(id) on delete cascade,
  applicant_id uuid not null references public.profiles(id),
  assessor_id uuid not null references public.profiles(id),
  outcome public.assessment_outcome not null,
  checklist jsonb not null default '{}'::jsonb,
  private_notes text,
  recommendations text,
  assessed_at timestamptz not null default now()
);

create table public.adoption_applications (
  id uuid primary key default gen_random_uuid(),
  applicant_id uuid not null references public.profiles(id),
  pet_id uuid not null references public.pets(id),
  assessment_id uuid references public.assessment_records(id),
  status public.application_status not null default 'draft',
  form_data jsonb not null default '{}'::jsonb,
  agreement_accepted_at timestamptz,
  submitted_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.application_documents (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.adoption_applications(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id),
  storage_path text not null,
  document_type text not null,
  created_at timestamptz not null default now()
);

create table public.adoption_records (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null unique references public.adoption_applications(id),
  pet_id uuid not null references public.pets(id),
  adopter_id uuid not null references public.profiles(id),
  completed_by uuid not null references public.profiles(id),
  completed_at timestamptz not null default now(),
  notes text
);

create table public.fundraising_campaigns (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  purpose text not null,
  description text not null,
  cover_path text,
  target_amount numeric(12,2) not null check (target_amount > 0),
  starts_on date not null,
  ends_on date not null,
  status text not null check (status in ('draft', 'published', 'closed')),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);

create table public.donations (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.fundraising_campaigns(id),
  donor_id uuid references public.profiles(id),
  donor_name text,
  donor_email text,
  amount numeric(12,2) not null check (amount > 0),
  anonymous boolean not null default false,
  message text,
  payment_provider text,
  payment_reference text unique,
  payment_status public.payment_status not null default 'pending',
  confirmed_by uuid references public.profiles(id),
  confirmed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  link text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (
  select 1 from public.profiles
  where id = auth.uid() and role in ('staff', 'admin') and is_active
) $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (
  select 1 from public.profiles
  where id = auth.uid() and role = 'admin' and is_active
) $$;

alter table public.profiles enable row level security;
alter table public.pets enable row level security;
alter table public.pet_photos enable row level security;
alter table public.pet_videos enable row level security;
alter table public.favorites enable row level security;
alter table public.appointments enable row level security;
alter table public.assessment_records enable row level security;
alter table public.adoption_applications enable row level security;
alter table public.application_documents enable row level security;
alter table public.adoption_records enable row level security;
alter table public.fundraising_campaigns enable row level security;
alter table public.donations enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles own select" on public.profiles for select using (id = auth.uid() or public.is_staff());
create policy "profiles own update" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy "admins manage profiles" on public.profiles for all using (public.is_admin()) with check (public.is_admin());
create policy "public published pets" on public.pets for select using (is_published and status <> 'archived' or public.is_staff());
create policy "staff manage pets" on public.pets for all using (public.is_staff()) with check (public.is_staff());
create policy "public published photos" on public.pet_photos for select using (exists (select 1 from public.pets p where p.id = pet_id and p.is_published));
create policy "staff manage photos" on public.pet_photos for all using (public.is_staff()) with check (public.is_staff());
create policy "public verified videos" on public.pet_videos for select using (verification_status = 'verified' or public.is_staff());
create policy "staff manage videos" on public.pet_videos for all using (public.is_staff()) with check (public.is_staff());
create policy "users manage favorites" on public.favorites for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "appointments own or staff" on public.appointments for select using (applicant_id = auth.uid() or public.is_staff());
create policy "users create appointments" on public.appointments for insert with check (applicant_id = auth.uid());
create policy "staff manage appointments" on public.appointments for all using (public.is_staff()) with check (public.is_staff());
create policy "assessments applicant summary" on public.assessment_records for select using (applicant_id = auth.uid() or public.is_staff());
create policy "staff manage assessments" on public.assessment_records for all using (public.is_staff()) with check (public.is_staff());
create policy "applications own or staff" on public.adoption_applications for select using (applicant_id = auth.uid() or public.is_staff());
create policy "users create own applications" on public.adoption_applications for insert with check (applicant_id = auth.uid());
create policy "staff manage applications" on public.adoption_applications for all using (public.is_staff()) with check (public.is_staff());
create policy "documents own or staff" on public.application_documents for select using (
  public.is_staff() or exists (select 1 from public.adoption_applications a where a.id = application_id and a.applicant_id = auth.uid())
);
create policy "users upload own documents" on public.application_documents for insert with check (
  uploaded_by = auth.uid() and exists (select 1 from public.adoption_applications a where a.id = application_id and a.applicant_id = auth.uid())
);
create policy "adoptions own or staff" on public.adoption_records for select using (adopter_id = auth.uid() or public.is_staff());
create policy "staff manage adoptions" on public.adoption_records for all using (public.is_staff()) with check (public.is_staff());
create policy "public campaigns" on public.fundraising_campaigns for select using (status = 'published' or public.is_staff());
create policy "staff manage campaigns" on public.fundraising_campaigns for all using (public.is_staff()) with check (public.is_staff());
create policy "donations own or staff" on public.donations for select using (donor_id = auth.uid() or public.is_staff());
create policy "create pending donation" on public.donations for insert with check (payment_status in ('pending', 'offline_pending'));
create policy "staff manage donations" on public.donations for all using (public.is_staff()) with check (public.is_staff());
create policy "notifications own" on public.notifications for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "staff audit select" on public.audit_logs for select using (public.is_staff());
create policy "system audit insert" on public.audit_logs for insert with check (actor_id = auth.uid() and public.is_staff());

create view public.campaign_confirmed_totals as
select campaign_id, coalesce(sum(amount), 0)::numeric(12,2) as confirmed_total
from public.donations
where payment_status = 'confirmed'
group by campaign_id;

insert into storage.buckets (id, name, public)
values ('pet-images', 'pet-images', true), ('pet-videos', 'pet-videos', true), ('application-documents', 'application-documents', false)
on conflict (id) do nothing;

create policy "public pet media" on storage.objects for select using (bucket_id in ('pet-images', 'pet-videos'));
create policy "staff upload pet media" on storage.objects for insert with check (bucket_id in ('pet-images', 'pet-videos') and public.is_staff());
create policy "private document owner access" on storage.objects for select using (
  bucket_id = 'application-documents' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_staff())
);
create policy "private document owner upload" on storage.objects for insert with check (
  bucket_id = 'application-documents' and (storage.foldername(name))[1] = auth.uid()::text
);
