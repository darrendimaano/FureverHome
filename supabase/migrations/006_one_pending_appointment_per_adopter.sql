create unique index appointments_one_pending_per_applicant
  on public.appointments (applicant_id)
  where status = 'pending_confirmation';