drop policy if exists "staff manage campaigns" on public.fundraising_campaigns;

create policy "admins manage fundraising campaigns"
  on public.fundraising_campaigns
  for all
  using (public.is_admin())
  with check (public.is_admin());