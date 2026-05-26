import { createClient } from "@supabase/supabase-js";

// Read-only anon client for SSR of public marketing pages. RLS keeps this
// scoped to publicly readable rows (verified provider profiles, reviews).
// Anything that mutates must happen in the app surface, not here.
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!url || !anon) {
  throw new Error(
    "Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY. " +
      "Set them in marketing/.env.local."
  );
}

export const supabase = createClient(url, anon);
