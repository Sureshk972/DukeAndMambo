-- Services rate card. Seeded once; not user-editable. The spec at
-- docs/superpowers/specs/2026-05-14-duke-and-mambo-design.md §4 is
-- the source of truth for these values.
insert into services (code, display_name, duration_minutes, price_cents, active)
values
  ('walk_30',   '30-minute walk',   30, 2500, true),
  ('walk_60',   '60-minute walk',   60, 4000, true),
  ('dropin_30', '30-minute drop-in', 30, 2000, true)
on conflict (code) do nothing;
