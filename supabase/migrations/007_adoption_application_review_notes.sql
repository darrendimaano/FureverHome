alter table public.adoption_applications
  add column if not exists review_notes text;