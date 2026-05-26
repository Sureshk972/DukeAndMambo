// submit-review
//
// Contract: Writes review row. Runs mutual-reveal logic so neither side sees the other until both submitted or 14 days pass.
//
// This is a scaffold. It returns HTTP 501 so it can be deployed without
// pretending to work. Replace the body with the real implementation
// before flipping any caller from a feature flag / dev-only path to prod.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { handleOptions, notImplemented } from "../_shared/cors.ts";

serve((req) => {
  if (req.method === "OPTIONS") return handleOptions();
  return notImplemented("submit-review");
});
