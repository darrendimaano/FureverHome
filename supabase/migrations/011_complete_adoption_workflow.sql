create or replace function public.complete_adoption(p_application_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_application public.adoption_applications%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Only an active administrator can complete an adoption';
  end if;

  select *
  into selected_application
  from public.adoption_applications
  where id = p_application_id
  for update;

  if not found then
    raise exception 'Adoption application not found';
  end if;

  if selected_application.status = 'adoption_completed' then
    return;
  end if;

  if selected_application.status not in ('under_review', 'approved') then
    raise exception 'Only an application under review can be completed';
  end if;

  if selected_application.assessment_id is null or not exists (
    select 1
    from public.assessment_records ar
    join public.appointments ap on ap.id = ar.appointment_id
    where ar.id = selected_application.assessment_id
      and ar.applicant_id = selected_application.applicant_id
      and ar.outcome = 'approved_to_proceed'
      and ap.pet_id = selected_application.pet_id
  ) then
    raise exception 'An eligible assessment for this pet is required';
  end if;

  update public.pets
  set status = 'adopted', is_published = false, updated_at = now()
  where id = selected_application.pet_id
    and status <> 'adopted';

  if not found then
    raise exception 'This pet is no longer available for adoption';
  end if;

  update public.adoption_applications
  set status = 'adoption_completed',
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      updated_at = now()
  where id = selected_application.id;

  insert into public.adoption_records (
    application_id,
    pet_id,
    adopter_id,
    completed_by,
    completed_at
  ) values (
    selected_application.id,
    selected_application.pet_id,
    selected_application.applicant_id,
    auth.uid(),
    now()
  ) on conflict (application_id) do nothing;
end;
$$;

revoke all on function public.complete_adoption(uuid) from public;
grant execute on function public.complete_adoption(uuid) to authenticated;

create or replace function public.mask_adopter_display_name(value text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when nullif(trim(value), '') is null then 'Adopter'
    when array_length(regexp_split_to_array(trim(value), '[[:space:]]+'), 1) = 1
      then split_part(trim(value), ' ', 1)
    else split_part(trim(value), ' ', 1) || ' ' ||
      left((regexp_split_to_array(trim(value), '[[:space:]]+'))[
        array_length(regexp_split_to_array(trim(value), '[[:space:]]+'), 1)
      ], 1) || '.'
  end;
$$;

create or replace view public.public_adoption_stories
with (security_invoker = false)
as
select
  ar.id,
  ar.pet_id,
  p.name as pet_name,
  p.species,
  photo.storage_path,
  public.mask_adopter_display_name(profile.full_name) as adopter_display_name,
  ar.completed_at
from public.adoption_records ar
join public.pets p on p.id = ar.pet_id
join public.profiles profile on profile.id = ar.adopter_id
left join lateral (
  select pp.storage_path
  from public.pet_photos pp
  where pp.pet_id = p.id
  order by pp.sort_order
  limit 1
) photo on true;

grant select on public.public_adoption_stories to anon, authenticated;
