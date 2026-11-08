drop policy if exists "public campaigns" on public.fundraising_campaigns;

create policy "public published and closed campaigns"
  on public.fundraising_campaigns
  for select
  using (status in ('published', 'closed') or public.is_staff());