alter table public.pet_videos
  alter column uploaded_by drop not null;

alter table public.pet_videos
  add column if not exists source_attribution text;

drop policy if exists "public verified videos" on public.pet_videos;
create policy "public reviewable pet videos"
on public.pet_videos for select
using (
  verification_status in ('pending', 'verified')
  and exists (
    select 1 from public.pets
    where pets.id = pet_videos.pet_id
      and pets.is_published
      and pets.status <> 'archived'
  )
);

insert into public.pets (
  id, name, species, breed, birth_date, gender, size, location, personality,
  health_condition, vaccination_status, deworming_status, sterilization_status,
  feeding_preferences, special_care, rescue_story, status, is_published
) values
  (
    '10000000-0000-4000-8000-000000000001', 'Milo', 'Dog', 'Terrier mix',
    '2023-04-12', 'Male', 'Medium', 'Greenfield Rescue',
    'Playful, people-friendly, and eager to learn.', 'Vaccinated',
    'Complete', 'Complete', 'Neutered', 'Two measured meals daily', 'None recorded',
    'Milo was found near a market and has flourished in foster care.', 'available', true
  ),
  (
    '10000000-0000-4000-8000-000000000002', 'Pepper', 'Dog', 'Mixed breed',
    '2024-08-03', 'Female', 'Medium', 'Northside Foster',
    'Curious, energetic, and friendly with other dogs.', 'Vaccinated',
    'Complete', 'Complete', 'Spayed', 'Puppy formula twice daily', 'Continued leash training',
    'Pepper and her siblings were raised by a volunteer foster family.', 'available', true
  ),
  (
    '10000000-0000-4000-8000-000000000003', 'Bruno', 'Dog', 'Labrador mix',
    '2021-02-18', 'Male', 'Large', 'Riverside Shelter',
    'Calm on walks, attentive, and motivated by toys.', 'Vaccinated',
    'Complete', 'Complete', 'Neutered', 'Large-breed adult food', 'Secure outdoor space',
    'Bruno was surrendered after his family relocated and is ready for a stable home.', 'available', true
  ),
  (
    '10000000-0000-4000-8000-000000000004', 'Luna', 'Cat', 'Domestic shorthair',
    '2022-06-25', 'Female', 'Small', 'Riverside Shelter',
    'Gentle, observant, and content around calm people.', 'Vaccinated',
    'Complete', 'Complete', 'Spayed', 'Wet and dry food combination', 'Quiet introduction period',
    'Luna arrived with her kittens, who have all found homes.', 'available', true
  ),
  (
    '10000000-0000-4000-8000-000000000005', 'Mochi', 'Cat', 'Tuxedo',
    '2023-09-08', 'Male', 'Small', 'Greenfield Rescue',
    'Social, playful, and comfortable with gentle handling.', 'Vaccinated',
    'Complete', 'Complete', 'Neutered', 'Indoor adult cat food', 'Indoor home only',
    'Mochi was rescued from a busy parking area and quickly learned to trust his foster family.', 'available', true
  ),
  (
    '10000000-0000-4000-8000-000000000006', 'Suki', 'Cat', 'Brown tabby',
    '2020-11-14', 'Female', 'Small', 'Northside Foster',
    'Independent, tidy, and affectionate once comfortable.', 'Vaccinated',
    'Complete', 'Complete', 'Spayed', 'Sensitive-stomach formula', 'Slow household transition',
    'Suki spent several months outdoors before a community volunteer brought her to safety.', 'available', true
  )
on conflict (id) do update set
  name = excluded.name,
  breed = excluded.breed,
  location = excluded.location,
  personality = excluded.personality,
  rescue_story = excluded.rescue_story,
  status = excluded.status,
  is_published = excluded.is_published,
  updated_at = now();

insert into public.pet_photos (id, pet_id, storage_path, alt_text, sort_order) values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'https://images.unsplash.com/photo-1654053286388-f0aeca664cd2?auto=format&fit=crop&w=900&q=82', 'Milo, a rescued terrier mix', 0),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'https://images.unsplash.com/photo-1658337922643-6e3d8751a8eb?auto=format&fit=crop&w=900&q=82', 'Pepper, a rescued mixed-breed dog', 0),
  ('20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000003', 'https://images.unsplash.com/photo-1724367281416-cf18867ad712?auto=format&fit=crop&w=900&q=82', 'Bruno, a rescued Labrador mix', 0),
  ('20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000004', 'https://images.unsplash.com/photo-1594387992816-65f5d74c1de0?auto=format&fit=crop&w=900&q=82', 'Luna, a rescued domestic shorthair', 0),
  ('20000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000005', 'https://images.unsplash.com/photo-1498100152307-ce63fd6c5424?auto=format&fit=crop&w=900&q=82', 'Mochi, a rescued tuxedo cat', 0),
  ('20000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000006', 'https://images.unsplash.com/photo-1611843275167-a9bba9aa65dd?auto=format&fit=crop&w=900&q=82', 'Suki, a rescued brown tabby', 0)
on conflict (id) do update set
  storage_path = excluded.storage_path,
  alt_text = excluded.alt_text;

insert into public.pet_videos (
  id, pet_id, storage_path, description, observed_trait, uploaded_by,
  verification_status, source_attribution
) values
  (
    '30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
    'https://upload.wikimedia.org/wikipedia/commons/0/0c/Pro_dog_walker_-_Tokyo_-_2024_Nov_1.webm',
    'Illustrative demo footage; replace with shelter-recorded evidence before verification.',
    'Walking calmly with people', null, 'pending',
    'Demo video: “Pro dog walker — Tokyo — 2024 Nov 1,” Wikimedia Commons.'
  ),
  (
    '30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002',
    'https://upload.wikimedia.org/wikipedia/commons/5/54/Goldendoodle_and_Black_Lab_puppies_playing_in_slow_motion.webm',
    'Illustrative demo footage; replace with shelter-recorded evidence before verification.',
    'Active play with another dog', null, 'pending',
    'Demo video: “Goldendoodle and Black Lab puppies playing in slow motion,” Wikimedia Commons.'
  ),
  (
    '30000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000003',
    'https://upload.wikimedia.org/wikipedia/commons/2/21/Puppy_playing.webm',
    'Illustrative demo footage; replace with shelter-recorded evidence before verification.',
    'Toy engagement and movement', null, 'pending',
    'Demo video: “Puppy playing,” Wikimedia Commons.'
  ),
  (
    '30000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000004',
    'https://upload.wikimedia.org/wikipedia/commons/8/84/Cat_body_language.webm',
    'Illustrative demo footage; replace with shelter-recorded evidence before verification.',
    'Calm body language', null, 'pending',
    'Demo video: “Cat body language,” Wikimedia Commons.'
  ),
  (
    '30000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000005',
    'https://upload.wikimedia.org/wikipedia/commons/f/f9/Cat_Plays.webm',
    'Illustrative demo footage; replace with shelter-recorded evidence before verification.',
    'Play and enrichment response', null, 'pending',
    'Demo video: “Cat Plays,” Wikimedia Commons.'
  ),
  (
    '30000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000006',
    'https://upload.wikimedia.org/wikipedia/commons/6/6d/Housecat_Grooming_Itself.webm',
    'Illustrative demo footage; replace with shelter-recorded evidence before verification.',
    'Relaxed self-grooming', null, 'pending',
    'Demo video: “Housecat Grooming Itself,” Wikimedia Commons.'
  )
on conflict (id) do update set
  storage_path = excluded.storage_path,
  description = excluded.description,
  observed_trait = excluded.observed_trait,
  verification_status = excluded.verification_status,
  source_attribution = excluded.source_attribution;
