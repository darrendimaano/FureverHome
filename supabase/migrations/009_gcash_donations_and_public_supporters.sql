alter table public.donations
  add column if not exists proof_storage_path text;

create table if not exists public.fundraising_payment_settings (
  id smallint primary key default 1 check (id = 1),
  gcash_number text not null default '',
  qr_storage_path text,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

alter table public.fundraising_payment_settings enable row level security;

drop policy if exists "public read fundraising payment settings" on public.fundraising_payment_settings;
create policy "public read fundraising payment settings"
  on public.fundraising_payment_settings for select using (true);

drop policy if exists "admins manage fundraising payment settings" on public.fundraising_payment_settings;
create policy "admins manage fundraising payment settings"
  on public.fundraising_payment_settings for all
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "create pending donation" on public.donations;
drop policy if exists "authenticated submit gcash donation" on public.donations;
create policy "authenticated submit gcash donation"
  on public.donations for insert
  with check (
    auth.uid() is not null
    and donor_id = auth.uid()
    and payment_status = 'offline_pending'
    and payment_provider = 'gcash'
    and proof_storage_path is not null
    and exists (
      select 1 from public.fundraising_campaigns c
      where c.id = campaign_id and c.status = 'published'
    )
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('fundraising-qr', 'fundraising-qr', true, 5242880, array['image/png', 'image/jpeg', 'image/webp']),
  ('donation-proofs', 'donation-proofs', false, 10485760, array['image/png', 'image/jpeg', 'image/webp', 'application/pdf'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public fundraising qr read" on storage.objects;
create policy "public fundraising qr read"
  on storage.objects for select using (bucket_id = 'fundraising-qr');

drop policy if exists "admins manage fundraising qr" on storage.objects;
create policy "admins manage fundraising qr"
  on storage.objects for all
  using (bucket_id = 'fundraising-qr' and public.is_admin())
  with check (bucket_id = 'fundraising-qr' and public.is_admin());

drop policy if exists "donors upload own donation proofs" on storage.objects;
create policy "donors upload own donation proofs"
  on storage.objects for insert
  with check (
    bucket_id = 'donation-proofs'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "admins read donation proofs" on storage.objects;
create policy "admins read donation proofs"
  on storage.objects for select
  using (bucket_id = 'donation-proofs' and public.is_admin());

drop policy if exists "admins manage donation proofs" on storage.objects;
create policy "admins manage donation proofs"
  on storage.objects for all
  using (bucket_id = 'donation-proofs' and public.is_admin())
  with check (bucket_id = 'donation-proofs' and public.is_admin());

create or replace function public.mask_campaign_name(value text)
returns text
language sql
immutable
set search_path = public
as $$
  select coalesce(string_agg(
    case
      when token ~ '^[[:alpha:]]\.$' then token
      when char_length(token) <= 2 then left(token, 1) || repeat('*', greatest(1, char_length(token) - 1))
      when char_length(token) = 3 then left(token, 1) || '*' || right(token, 1)
      else left(token, 2) || repeat('*', char_length(token) - 3) || right(token, 1)
    end,
    ' ' order by ordinal
  ), 'Supporter')
  from regexp_split_to_table(trim(coalesce(value, '')), '[[:space:]]+') with ordinality as parts(token, ordinal)
  where token <> '';
$$;

create or replace function public.mask_campaign_email(value text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when value is null or position('@' in value) < 2 then null
    else
      case
        when char_length(split_part(value, '@', 1)) <= 2
          then left(split_part(value, '@', 1), 1) || '*'
        when char_length(split_part(value, '@', 1)) = 3
          then left(split_part(value, '@', 1), 1) || '*' || right(split_part(value, '@', 1), 1)
        else left(split_part(value, '@', 1), 2) || repeat('*', char_length(split_part(value, '@', 1)) - 3) || right(split_part(value, '@', 1), 1)
      end
      || '@' || split_part(split_part(value, '@', 2), '.', 1)
      || case
        when position('.' in split_part(value, '@', 2)) > 0
          then substring(split_part(value, '@', 2) from position('.' in split_part(value, '@', 2)))
        else ''
      end
  end;
$$;

create or replace view public.campaign_public_donors as
select
  campaign_id,
  public.mask_campaign_name(donor_name) as display_name,
  public.mask_campaign_email(donor_email) as display_email,
  created_at
from public.donations
where payment_status = 'confirmed'
  and anonymous = false
  and nullif(trim(donor_name), '') is not null;

grant select on public.campaign_public_donors to anon, authenticated;
