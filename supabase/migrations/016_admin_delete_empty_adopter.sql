create or replace function public.admin_delete_empty_adopter(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_role public.app_role;
  target_email text;
begin
  if not public.is_admin() then
    raise exception 'Only an active administrator can delete a user';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'You cannot delete your own account';
  end if;

  select profile.role, account.email
  into target_role, target_email
  from public.profiles profile
  join auth.users account on account.id = profile.id
  where profile.id = p_user_id
  for update of profile;

  if not found then
    raise exception 'User account not found';
  end if;

  if target_role <> 'adopter' then
    raise exception 'Only adopter accounts can be permanently deleted';
  end if;

  if exists (select 1 from public.appointments where applicant_id = p_user_id)
    or exists (select 1 from public.assessment_records where applicant_id = p_user_id or assessor_id = p_user_id)
    or exists (select 1 from public.adoption_applications where applicant_id = p_user_id or reviewed_by = p_user_id)
    or exists (select 1 from public.application_documents where uploaded_by = p_user_id)
    or exists (select 1 from public.adoption_records where adopter_id = p_user_id or completed_by = p_user_id)
    or exists (select 1 from public.donations where donor_id = p_user_id or confirmed_by = p_user_id)
    or exists (select 1 from public.pets where created_by = p_user_id)
    or exists (select 1 from public.pet_videos where uploaded_by = p_user_id or verified_by = p_user_id)
    or exists (select 1 from public.fundraising_campaigns where created_by = p_user_id)
    or exists (select 1 from public.fundraising_payment_settings where updated_by = p_user_id)
    or exists (select 1 from public.audit_logs where actor_id = p_user_id) then
    raise exception 'This adopter has linked records. Block the account instead to preserve its history.';
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(),
    'user_deleted',
    'profile',
    p_user_id,
    jsonb_build_object('email', target_email, 'role', target_role)
  );

  delete from auth.users where id = p_user_id;
end;
$$;

revoke all on function public.admin_delete_empty_adopter(uuid) from public;
grant execute on function public.admin_delete_empty_adopter(uuid) to authenticated;

notify pgrst, 'reload schema';
