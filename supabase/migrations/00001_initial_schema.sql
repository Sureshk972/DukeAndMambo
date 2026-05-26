-- Duke and Mambo — v1 initial schema.
-- Source of truth: docs/superpowers/specs/2026-05-14-duke-and-mambo-design.md §12.
-- This is the skeleton — tables and key constraints only. RLS policies,
-- indexes, and any business-logic functions are added in subsequent
-- migrations as the surfaces that depend on them get built.

-- Enums --------------------------------------------------------------

create type account_type as enum ('owner', 'provider');
create type pet_species as enum ('dog', 'cat');
create type verification_status as enum ('pending', 'verified', 'rejected');
create type booking_status as enum (
  'pending',
  'confirmed',
  'in_progress',
  'completed',
  'paid_out',
  'cancelled_by_owner',
  'cancelled_by_provider',
  'auto_cancelled'
);
create type background_check_status as enum (
  'pending', 'clear', 'consider', 'rejected'
);

-- profiles -----------------------------------------------------------

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  phone text,
  full_name text,
  photo_url text,
  account_type account_type not null,
  zip_code text,
  -- Owner-only
  default_address text,
  -- Provider-only
  bio text,
  service_zip_codes text[] default '{}',
  verification_status verification_status default 'pending',
  years_experience integer,
  accepts_dogs_size text[] default '{}',
  accepts_cats boolean default false,
  stripe_account_id text,
  stripe_charges_enabled boolean default false,
  stripe_payouts_enabled boolean default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- pets ---------------------------------------------------------------

create table pets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  name text not null,
  species pet_species not null,
  breed text,
  weight_lbs numeric(6, 2),
  age_years numeric(4, 1),
  behavioral_notes text,
  vet_name text,
  vet_phone text,
  photo_url text,
  created_at timestamptz not null default now()
);

-- provider_availability ---------------------------------------------

create table provider_availability (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references profiles(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null check (end_time > start_time)
);

-- services (platform-managed rate card) ------------------------------

create table services (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  display_name text not null,
  duration_minutes integer not null,
  price_cents integer not null,
  active boolean not null default true
);

-- bookings -----------------------------------------------------------

create table bookings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete restrict,
  provider_id uuid not null references profiles(id) on delete restrict,
  pet_ids uuid[] not null,
  service_id uuid not null references services(id) on delete restrict,
  scheduled_at timestamptz not null,
  duration_minutes integer not null,
  address text not null,
  instructions text,
  status booking_status not null default 'pending',
  total_cents integer not null,
  platform_fee_cents integer not null,
  provider_payout_cents integer not null,
  stripe_payment_intent_id text,
  stripe_transfer_id text,
  stripe_refund_id text,
  started_at timestamptz,
  started_at_lat numeric(9, 6),
  started_at_lng numeric(9, 6),
  finished_at timestamptz,
  finished_at_lat numeric(9, 6),
  finished_at_lng numeric(9, 6),
  cancelled_at timestamptz,
  cancellation_reason text,
  cancellation_refund_cents integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- booking_photos (proof-of-walk) ------------------------------------

create table booking_photos (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete cascade,
  storage_path text not null,
  exif_taken_at timestamptz,
  exif_lat numeric(9, 6),
  exif_lng numeric(9, 6),
  validation_passed boolean not null default false,
  uploaded_at timestamptz not null default now()
);

-- messages -----------------------------------------------------------

create table messages (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

-- reviews ------------------------------------------------------------

create table reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete cascade,
  reviewer_id uuid not null references profiles(id) on delete cascade,
  reviewee_id uuid not null references profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  body text,
  created_at timestamptz not null default now(),
  unique (booking_id, reviewer_id)
);

-- background_checks --------------------------------------------------

create table background_checks (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references profiles(id) on delete cascade,
  vendor text not null default 'checkr',
  vendor_check_id text,
  status background_check_status not null default 'pending',
  result_summary jsonb,
  requested_at timestamptz not null default now(),
  completed_at timestamptz
);

-- Indexes ------------------------------------------------------------

create index bookings_provider_scheduled_idx on bookings (provider_id, scheduled_at);
create index bookings_owner_scheduled_idx    on bookings (owner_id, scheduled_at);
create index bookings_status_scheduled_idx   on bookings (status, scheduled_at);
create index provider_availability_idx       on provider_availability (provider_id, day_of_week);
create index profiles_service_zips_idx       on profiles using gin (service_zip_codes);
