# Duke and Mambo

A two-sided pet-care marketplace connecting pet owners in Chicago with verified, background-checked walkers. Brand operated by 12 Sigma LLC.

## Repository layout

This is a monorepo with two surfaces and a shared Supabase backend.

```
marketing/   Next.js 14 + Tailwind — SEO-ranked public site (dukeandmambo.com)
app/         React + Vite + Tailwind + Capacitor — native iOS/Android + web fallback (app.dukeandmambo.com)
supabase/    Postgres schema, RLS policies, edge functions, seed data
docs/        Design specs and other narrative documentation
```

The design spec for v1 lives at `docs/superpowers/specs/2026-05-14-duke-and-mambo-design.md`. Read that before touching code — it answers most of the "why" questions this README intentionally skips.

## Running locally

Each surface installs and runs independently.

**Marketing site**
```sh
cd marketing
npm install
npm run dev          # http://localhost:3000
```

**App (web build, for development)**
```sh
cd app
npm install
npm run dev          # http://localhost:5173
```

**App (native iOS / Android)**
```sh
cd app
npm run build
npx cap sync
npx cap open ios     # opens Xcode
npx cap open android # opens Android Studio
```

**Supabase**
```sh
cd supabase
supabase start                              # local Postgres + studio
supabase db reset                           # apply migrations + seed
supabase functions serve <function-name>    # run an edge function locally
```

## Environment variables

Each surface reads its own `.env` file. Templates and required keys will be
documented per surface as they're built out. At minimum each surface needs
`SUPABASE_URL` and `SUPABASE_ANON_KEY`.

## Deployments

- **Marketing site:** Netlify, custom domain `dukeandmambo.com`
- **App web build:** Netlify, custom domain `app.dukeandmambo.com`
- **Native iOS:** App Store via Xcode
- **Native Android:** Play Store via Android Studio
- **Supabase functions:** `supabase functions deploy <name> --project-ref <ref>`

## License

Proprietary — © 12 Sigma LLC.
