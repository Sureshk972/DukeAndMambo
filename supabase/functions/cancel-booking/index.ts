// cancel-booking
//
// Contract: Owner or provider cancels. Computes refund per cancellation policy and processes Stripe refund.
//
// This is a scaffold. It returns HTTP 501 so it can be deployed without
// pretending to work. Replace the body with the real implementation
// before flipping any caller from a feature flag / dev-only path to prod.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { handleOptions, notImplemented } from "../_shared/cors.ts";

serve((req) => {
  if (req.method === "OPTIONS") return handleOptions();
  return notImplemented("cancel-booking");
});
