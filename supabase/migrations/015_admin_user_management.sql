create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and is_active
  )
$$;

revoke all on function public.is_active_user() from public;
grant execute on function public.is_active_user() to authenticated;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles',
    'favorites',
    'appointments',
    'assessment_records',
    'adoption_applications',
    'application_documents',
    'adoption_records',
    'donations',
    'notifications'
  ] loop
    execute format('drop policy if exists active_account_required on public.%I', table_name);
    execute format(
      'create policy active_account_required on public.%I as restrictive for all to authenticated using (public.is_active_user()) with check (public.is_active_user())',
      table_name
    );
  end loop;
end;
$$;

create or replace function public.admin_list_users()
returns table (
  id uuid,
  email text,
  full_name text,
  role public.app_role,
  is_active boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception 'Only an active administrator can view users';
  end if;

  return query
  select
    profile.id,
    account.email::text,
    profile.full_name,
    profile.role,
    profile.is_active,
    profile.created_at
  from public.profiles profile
  join auth.users account on account.id = profile.id
  order by profile.created_at desc;
end;
$$;

create or replace function public.admin_set_user_active(p_user_id uuid, p_is_active boolean)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_role public.app_role;
  target_active boolean;
begin
  if not public.is_admin() then
    raise exception 'Only an active administrator can change account status';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'You cannot deactivate your own account';
  end if;

  select role, is_active
  into target_role, target_active
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'User account not found';
  end if;

  if target_active = p_is_active then
    return;
  end if;

  if target_role = 'admin' and not p_is_active and not exists (
    select 1
    from public.profiles
    where role = 'admin'
      and is_active
      and id <> p_user_id
  ) then
    raise exception 'The last active administrator cannot be deactivated';
  end if;

  update public.profiles
  set is_active = p_is_active,
      updated_at = now()
  where id = p_user_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(),
    case when p_is_active then 'user_activated' else 'user_deactivated' end,
    'profile',
    p_user_id,
    jsonb_build_object('previous_is_active', target_active, 'is_active', p_is_active)
  );
end;
$$;

revoke all on function public.admin_list_users() from public;
revoke all on function public.admin_set_user_active(uuid, boolean) from public;
grant execute on function public.admin_list_users() to authenticated;
grant execute on function public.admin_set_user_active(uuid, boolean) to authenticated;

notify pgrst, 'reload schema';
