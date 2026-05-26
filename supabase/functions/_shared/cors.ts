// Shared CORS headers + preflight handler for every edge function.
// Tighten the origin once we know the production hostnames; for now
// '*' keeps local dev simple.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function handleOptions(): Response {
  return new Response("ok", { headers: corsHeaders });
}

export function notImplemented(name: string): Response {
  return new Response(
    JSON.stringify({
      error: "not_implemented",
      function: name,
      message: `${name} is a scaffold — implement before deploying to prod.`,
    }),
    {
      status: 501,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}
