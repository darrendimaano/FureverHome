alter table public.pets
  add column address text,
  add column latitude double precision,
  add column longitude double precision,
  add constraint pets_coordinates_valid check (
    (latitude is null and longitude is null)
    or (
      latitude between -90 and 90
      and longitude between -180 and 180
    )
  );
