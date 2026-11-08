create or replace function public.prevent_unauthorized_profile_privilege_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role
    or new.is_active is distinct from old.is_active then
    -- SQL Editor and trusted server operations have no end-user JWT.
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
