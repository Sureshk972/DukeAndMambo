# Duke and Mambo — v1 Design Spec

**Date:** 2026-05-14
**Status:** Approved design — ready for implementation plan
**Owner:** Suresh (12 Sigma LLC)

---

## 1. Product Summary

Duke and Mambo is a two-sided marketplace connecting pet owners in Chicago with verified, background-checked pet-care service providers. v1 supports two services — **dog walking** and **drop-in visits** — both billed hourly at platform-set flat rates. Owners browse and book a specific provider (Rover-style), pay through the platform, and receive proof-of-walk in the form of a provider-uploaded photo plus Start/Finish timestamps. The platform takes 20% of each booking and is responsible for provider vetting, payment custody, and dispute resolution.

The brand is operated by **12 Sigma LLC** (parent company of Kiddaboo and other ventures).

---

## 2. Audiences

**Pet Owner**
- Has 1+ pets (dogs primarily; cats can be registered but no cat-specific service in v1).
- Wants reliable, vetted, predictable pet care without per-booking phone calls.
- Pays per service via card on file.

**Service Provider**
- Walks dogs / does drop-in visits as paid work.
- Required: passes background check, completes profile, sets weekly availability.
- Receives platform-set rate minus the 20% platform fee.

---

## 3. Geography

Chicago metro area only for v1. Providers serving zip codes outside the launch area cannot register. Owners outside the launch area see a "Not yet in your area — get notified" page.

---

## 4. Services

| Code        | Name                | Duration | Price (USD) |
|-------------|---------------------|----------|-------------|
| `walk_30`   | 30-minute walk      | 30 min   | $25         |
| `walk_60`   | 60-minute walk      | 60 min   | $40         |
| `dropin_30` | 30-minute drop-in   | 30 min   | $20         |

Rates are set by the platform and visible in the same dollar value to every owner and provider. Providers cannot edit rates.

---

## 5. Discovery & Booking Model

**v1 model: owner browses verified providers and books a specific one** (Rover-style).

- Owner enters service type + date/time + zip code.
- Result list: providers who serve the owner's zip and have availability matching the requested slot, sorted by rating then distance.
- Owner taps a provider, reads their profile (photos, bio, services, reviews, weekly availability), books a specific time slot.
- Provider receives a push notification and has **30 minutes to accept**. If they don't, the booking auto-cancels and the owner is prompted to pick another provider; their card is not charged.

Deferred to v2 (out of scope, but the architecture should not preclude these):
- Broadcast / first-claim "ticket" model (Wag-style).
- Favorite-provider first-dibs window before broadcasting.
- Recurring auto-bookings (e.g., every Mon/Wed/Fri).

---

## 6. Booking Lifecycle

States in order:

1. **`pending`** — Owner tapped Book; card authorized via Stripe (held, not captured); provider notified.
2. **`confirmed`** — Provider accepted within the 30-minute window; card capture happens; funds held by Stripe in platform's connected-account model.
3. **`in_progress`** — Provider tapped Start at the door. Server records timestamp + GPS coordinates (if granted by the device). Owner pushed: "Walk started at HH:MM".
4. **`completed`** — Provider tapped Finish. Server records timestamp + GPS. Owner pushed with summary card. 24-hour dispute window opens.
5. **`paid_out`** — Dispute window closed without dispute. Stripe transfers the provider's 80% to their connected account. Platform retains 20%.

Cancellation states (any of):
- `cancelled_by_owner` — refund computed per cancellation policy (see §8)
- `cancelled_by_provider` — full refund to owner; strike on provider account
- `auto_cancelled` — provider didn't accept within 30 minutes; full refund

Each booking row records all state transitions with timestamps for audit.

---

## 7. Proof of Walk (Path 4)

Replaces live GPS tracking — explicit decision rather than oversight.

**Required during each `in_progress` booking:**
1. Provider taps **Start** at the door → owner pushed.
2. Provider takes **at least one photo** during the walk via in-app **camera capture only** (HTML `<input type="file" capture="environment">` on the native shell, blocked from photo-library selection). Server validates EXIF timestamp is within the booking window and EXIF GPS is within 1 mile of the booking address.
3. Provider taps **Finish** → owner pushed with a summary card (Start time, Finish time, total duration, photo).

**AirTag recommendation:** Owner-facing onboarding includes a tip "Recommended: attach an AirTag (or Tile / Galaxy SmartTag) to your pet's collar. We don't track your pet's location ourselves — we focus on proof your walker showed up and the walk happened." This is **advice, not a platform feature**; the platform does not integrate with AirTag.

**Why no live tracking in v1:** Live GPS requires reliable background location, which on iOS demands native APIs and battery-impact disclosures. Path 4 (photo proof + AirTag) achieves the same trust outcome at a fraction of the build cost. Live tracking is explicitly deferred to v2 if usage data shows demand.

---

## 8. Cancellation Policy

| Cancelled by | Time before scheduled walk | Refund to owner | Paid to provider |
|--------------|----------------------------|-----------------|------------------|
| Owner        | > 24 hours                 | 100%            | $0               |
| Owner        | 4–24 hours                 | 50%             | 50% (lost-opportunity payment) |
| Owner        | < 4 hours                  | 0%              | 100% (minus platform fee) |
| Provider     | Any time                   | 100%            | $0 + strike on provider account |
| Auto (provider didn't accept) | n/a       | 100%            | $0               |

Manual override by support is allowed for documented emergencies (handled out-of-band; spec does not prescribe a UI for this in v1).

---

## 9. Payments (Stripe Connect)

- Provider onboarding includes Stripe Connect Express account creation. Provider cannot accept bookings until the connected account is `charges_enabled` and `payouts_enabled`.
- Owner pays the full amount to the platform's Stripe account on `confirmed`.
- On `completed` + 24h dispute window expired, an Edge Function transfers (`stripe.transfers.create`) the provider's 80% to their connected account and retains 20% as platform fee.
- Refunds (per §8) issued via `stripe.refunds.create`.
- Webhook (`stripe-webhook` Edge Function) syncs payment intent / transfer / refund state into the `bookings` table.

---

## 10. Vetting (Background Checks)

- Required for every provider before they can accept bookings.
- Provider submits identity + DOB + SSN through a Checkr-hosted form; platform pays Checkr (~$25 per check).
- `background_checks` table records `vendor_check_id` and `status`.
- Webhook from Checkr updates `verification_status` on the provider's profile.
- Provider account stays `pending` (cannot accept bookings, not visible to owners) until status is `verified`.
- Rejected providers see a generic message; appeal goes to support.

---

## 11. Reviews

- Both sides can leave a 1–5 star review with optional comment, after `completed`.
- 14-day window after walk completion.
- Mutual blind reveal: neither side sees the other's review until both have submitted (or the 14-day window expires).
- Average rating shown on provider profiles, computed lazily (no triggers — view or materialized view).

---

## 12. Data Model (Supabase Postgres)

**`profiles`** — extends `auth.users`
- `id` (uuid, FK to auth.users), `email`, `phone`, `full_name`, `photo_url`, `account_type` (`owner` | `provider`), `zip_code`, `created_at`
- For owners only: `default_address` (text, optional)
- For providers only: `bio`, `service_zip_codes` (text[], the zip codes the provider serves), `verification_status` (`pending` | `verified` | `rejected`), `years_experience`, `accepts_dogs_size` (text[], any of `small`,`medium`,`large`), `accepts_cats` (bool), `stripe_account_id`, `stripe_charges_enabled` (bool), `stripe_payouts_enabled` (bool)

**`pets`**
- `id`, `owner_id` (FK profiles), `name`, `species` (`dog` | `cat`), `breed`, `weight_lbs`, `age_years`, `behavioral_notes`, `vet_name`, `vet_phone`, `photo_url`

**`provider_availability`**
- `id`, `provider_id` (FK profiles), `day_of_week` (0–6, Sun–Sat), `start_time` (time), `end_time` (time)
- Multiple rows per provider (e.g., Mon–Fri 9–17, Sat 10–14)

**`services`** — rate card, platform-managed (seeded; not user-editable)
- `id`, `code`, `display_name`, `duration_minutes`, `price_cents`, `active`

**`bookings`**
- `id`, `owner_id`, `provider_id`, `pet_ids` (uuid[]), `service_id`
- `scheduled_at` (timestamptz), `duration_minutes`, `address` (text, where the walk happens)
- `instructions` (text, owner notes to provider)
- `status` (enum, see §6)
- `total_cents`, `platform_fee_cents`, `provider_payout_cents`
- `stripe_payment_intent_id`, `stripe_transfer_id`, `stripe_refund_id`
- `started_at`, `started_at_lat`, `started_at_lng`
- `finished_at`, `finished_at_lat`, `finished_at_lng`
- `cancelled_at`, `cancellation_reason`, `cancellation_refund_cents`
- `created_at`, `updated_at`

**`booking_photos`** — proof-of-walk uploads
- `id`, `booking_id` (FK bookings), `storage_path`, `exif_taken_at`, `exif_lat`, `exif_lng`, `validation_passed` (bool), `uploaded_at`

**`messages`** — booking-scoped chat between owner and provider
- `id`, `booking_id` (FK bookings), `sender_id` (FK profiles), `body`, `created_at`

**`reviews`**
- `id`, `booking_id` (FK bookings), `reviewer_id`, `reviewee_id`, `rating` (1–5), `body`, `created_at`
- Unique constraint on `(booking_id, reviewer_id)` — one review per role per booking

**`background_checks`**
- `id`, `provider_id` (FK profiles), `vendor` (text, e.g. `checkr`), `vendor_check_id`, `status` (`pending` | `clear` | `consider` | `rejected`), `result_summary` (jsonb), `requested_at`, `completed_at`

**Indexes**
- `bookings(provider_id, scheduled_at)`
- `bookings(owner_id, scheduled_at)`
- `bookings(status, scheduled_at)` for cron-driven payout job
- `provider_availability(provider_id, day_of_week)`
- GIN index on `profiles(service_zip_codes)` for zip-based search

**Row Level Security**
- `profiles`: provider rows are publicly readable when `verification_status = 'verified'`; owners can read/update their own row only; providers can read/update their own row only.
- `bookings`: only the owner and the provider on the booking can read or update (with appropriate field-level constraints — provider can only set `started_at` / `finished_at`, owner can only set `cancelled_*` if it's their cancellation).
- `messages`: only booking participants.
- `pets`: only the pet's owner; providers can read pet rows linked to bookings they're assigned to.
- `reviews`: public read for verified providers' reviews; write restricted to participants of the booking.
- `background_checks`: provider can read their own row; nobody can write directly (Edge Function only).

---

## 13. Tech Architecture

**Two surfaces, one backend.**

### Surface 1 — Marketing / SEO Site
- **Stack:** Next.js 14 (App Router) + Tailwind
- **Hosting:** Netlify
- **Pages:** `/` (home), `/how-it-works`, `/for-walkers`, `/browse/[zip]` (server-rendered list of providers in a zip), `/walker/[handle]` (server-rendered provider profile, the SEO ranking target), `/about`, `/terms`, `/privacy`, `/contact`
- **Read-only.** No login, no booking flow, no messaging. Pages link out to the app for actions (Open in app / Get the app on iOS / Get the app on Android).
- **Data:** read-only Supabase queries with anon key + RLS; no mutations.

### Surface 2 — The App
- **Stack:** React 18 + Vite + Tailwind + Capacitor (for iOS + Android wrap)
- **Targets:** iOS App Store, Google Play Store, web build (web is desktop fallback only — primary surface is native)
- **Auth:** Supabase Auth (email + phone, same pattern as Kiddaboo)
- **Realtime:** Supabase Realtime channels for booking status updates and messages
- **Storage:** Supabase Storage for profile photos, pet photos, walk-proof photos
- **Push notifications:** APNs (iOS) and FCM (Android) via Capacitor's Push Notifications plugin; Edge Functions send pushes via `expo-server-sdk`-style relay or direct APNs/FCM HTTP/2 calls
- **Camera:** Capacitor Camera plugin for proof-of-walk photo capture (camera-only, library blocked)
- **Geolocation:** Capacitor Geolocation plugin for Start/Finish coordinate capture
- **Local storage:** Capacitor Preferences plugin for session token caching

### Shared Backend — Supabase
- **Postgres** with RLS (see §12)
- **Auth** for both surfaces
- **Storage** for all user-uploaded media
- **Realtime** for app-side push/realtime channels
- **Edge Functions** (Deno-based, deployed via supabase CLI):
  - `create-booking` — creates `pending` row, authorizes Stripe payment intent
  - `accept-booking` — provider confirms, captures payment, transitions to `confirmed`
  - `start-booking` — records start time + coords, transitions to `in_progress`
  - `upload-walk-photo` — validates EXIF (timestamp window, GPS proximity), writes `booking_photos` row, pushes owner
  - `finish-booking` — records finish time + coords, transitions to `completed`, schedules payout
  - `cancel-booking` — computes refund per §8, processes Stripe refund, transitions to appropriate cancelled state
  - `release-payouts` — cron (hourly), finds `completed` bookings past 24h dispute window, runs Stripe transfers, transitions to `paid_out`
  - `auto-cancel-unaccepted-bookings` — cron (every 5 minutes), finds `pending` bookings past 30-minute provider response window, cancels and refunds
  - `stripe-webhook` — handles `payment_intent.succeeded`, `charge.refunded`, `transfer.created`, `payout.failed`, etc.
  - `request-background-check` — calls Checkr API, creates `background_checks` row
  - `checkr-webhook` — receives Checkr completion events, updates `verification_status`
  - `submit-review` — writes review, triggers mutual-reveal logic

### Third-Party Services
- **Stripe Connect Express** — payments + payouts
- **Checkr** — provider background checks
- **Twilio** (via Supabase phone auth) — SMS for phone verification
- **Postmark or Resend** — transactional email (booking confirmations, receipts, payout statements). ImprovMX handles inbound `support@dukeandmambo.com`.
- **No mapping provider** in v1 (zip-based search only; can add Mapbox/Google Maps in v2 for map-based discovery)

### Hosting & DNS
- **Marketing site (Next.js):** Netlify, custom domain `dukeandmambo.com`
- **App (web build):** Netlify, custom domain `app.dukeandmambo.com`
- **Native apps:** App Store + Play Store
- **Email:** ImprovMX → forwards `support@dukeandmambo.com`, `hello@dukeandmambo.com` to operator inbox

### CI / Deploy
- **Marketing site:** push to main → Netlify auto-build
- **App web build:** push to main → Netlify auto-build (used for desktop fallback only)
- **Native iOS:** manual EAS-style build + TestFlight + App Store submission per release
- **Native Android:** manual build + Play Console internal track + Production rollout per release

---

## 14. Notifications

| Event                                | To       | Channel | Notes                              |
|--------------------------------------|----------|---------|------------------------------------|
| New booking request                  | Provider | Push    | "[Owner] booked a 30-min walk for tomorrow at 2pm" |
| Provider accepted                    | Owner    | Push    | "Maria confirmed Buddy's walk"     |
| Provider didn't accept (auto-cancel) | Owner    | Push    | "No response — pick another walker" |
| Walk started                         | Owner    | Push    | "Walk started at 2:01pm"           |
| Walk photo uploaded                  | Owner    | Push    | "Maria sent a photo of Buddy"      |
| Walk completed                       | Owner    | Push    | "Walk completed — leave a review"  |
| Cancellation                         | Both     | Push + email | Includes refund amount         |
| Payout released                      | Provider | Email   | Statement of earnings              |
| Background check complete            | Provider | Push + email | "You're verified — start accepting bookings" |
| Review received                      | Both     | Push    | After mutual reveal                |

---

## 15. Out of Scope (v1)

Explicitly deferred to v2 or later, included here so they don't accidentally creep into v1:

- Live GPS tracking
- Boarding (overnight stays at provider's home)
- House sitting (provider stays at owner's home)
- Daycare
- Cat-specific services (cat profiles allowed, but no cat-only service category)
- Broadcast / first-claim "ticket" booking flow
- Favorite-provider first-dibs window
- Recurring auto-bookings
- Multi-pet discounts
- Tips
- Provider-to-provider referrals
- Loyalty / repeat-customer rewards
- Multi-city expansion (Chicago only in v1)
- Spanish or other languages (English only)
- Map view of providers (list only)
- Insurance (relies on providers' personal insurance)
- In-app dispute resolution UI (handled out-of-band by support)
- Web booking flow (web is read-only marketing + a "Get the App" landing — no booking on the web)

---

## 16. Timeline & Sequencing

Estimated v1 launch: **~5 months** from start of implementation. Rough phases:

1. **Weeks 1–2** — Repo bootstrapping, Supabase schema + RLS, Stripe Connect sandbox setup, Checkr sandbox setup, Capacitor scaffolding for iOS + Android
2. **Weeks 3–6** — Core auth + profile + pet management; provider onboarding flow with Stripe Connect + Checkr integration
3. **Weeks 7–10** — Search + booking creation + Stripe payment authorization; provider accept flow; messaging
4. **Weeks 11–12** — Walk lifecycle (start / photo upload / finish); proof-of-walk EXIF validation; cancellation flow; reviews
5. **Weeks 13–14** — Marketing site (Next.js); SEO-ranked provider profile pages
6. **Weeks 15–16** — Capacitor native polish; push notifications via APNs/FCM; deep links; splash + icons; App Store + Play Store assets
7. **Weeks 17–18** — App Store + Play Store submissions; address rejections; private beta on TestFlight + Play internal track
8. **Weeks 19–20** — Public launch in Chicago; recruit initial providers manually; concierge first 50 bookings

---

## 17. Open Questions

None — all v1 decisions resolved during brainstorming.

---

## 18. Decision Log (for posterity)

- **Marketplace vs directory:** Full marketplace (in-app booking + payments).
- **Discovery model:** Owner-picks (Rover-style); broadcast/ticket flow deferred to v2.
- **Pricing:** Platform-set flat rates; providers cannot edit.
- **Tracking:** Path 4 — photo proof + AirTag recommendation; no live GPS in v1.
- **PWA vs native:** Native from day 1 (operator's bias against PWA + concern that PWA feel pressures pricing downward).
- **Tech architecture:** Two surfaces — Next.js marketing site (SEO) + React/Vite/Capacitor native app (booking flow).
- **Geography:** Chicago only.
- **Services in v1:** Walking + drop-in visits only.
- **Cancellation:** 24h free / 4–24h 50% / <4h 0% — standard Rover-style policy.
- **Vetting:** Required background checks via Checkr before provider can accept bookings.
- **Platform take:** 20%.
