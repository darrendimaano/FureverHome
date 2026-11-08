create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'full_name', ''), 'New Adopter'),
    'adopter'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();

create or replace function public.prevent_unauthorized_profile_privilege_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role
    or new.is_active is distinct from old.is_active then
    if auth.uid() is null then
      return new;
    end if;
    if not public.is_admin() then
      raise exception 'Only an administrator can change roles or account activation';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_profile_privileges on public.profiles;

create trigger protect_profile_privileges
before update on public.profiles
for each row
execute procedure public.prevent_unauthorized_profile_privilege_change();
