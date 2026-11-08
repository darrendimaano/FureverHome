drop policy if exists "public verified videos" on public.pet_videos;
drop policy if exists "public reviewable pet videos" on public.pet_videos;

create policy "public reviewable pet videos"
on public.pet_videos for select
using (
  verification_status in ('pending', 'verified')
  and exists (
    select 1
    from public.pets
    where pets.id = pet_videos.pet_id
      and pets.is_published
      and pets.status <> 'archived'
  )
);
