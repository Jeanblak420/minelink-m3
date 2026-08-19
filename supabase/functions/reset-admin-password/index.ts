import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// DECOMMISSIONED 2026-07-26.
// The previous live version was a PUBLIC (verify_jwt=false) admin backdoor that
// created an admin auth user from a hardcoded email + plaintext password on any
// invocation. It has been replaced with this no-op that performs no action and
// returns 410 Gone. Do not restore admin-provisioning here; use the Supabase
// dashboard or a properly authenticated admin flow instead.
Deno.serve(() =>
  new Response(
    JSON.stringify({
      disabled: true,
      message: "This function has been decommissioned for security reasons.",
    }),
    { status: 410, headers: { "Content-Type": "application/json" } },
  )
);
