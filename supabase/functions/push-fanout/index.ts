// push-fanout: fans a single `public.notifications` row out to that user's
// live FCM device tokens.
//
// Invoked (fire-and-forget, via pg_net) by the `notifications_push_fanout`
// trigger in supabase/migrations/20260819090000_device_tokens.sql, whenever
// a key is configured for it -- see CONTROLLER RULING 12 in that file for
// why the trigger can legitimately never call this at all yet.
//
// verify_jwt is false for this function: it is called by pg_net with a
// service-role bearer token (once one is configured), not by a signed-in
// user, so the platform's JWT gate is the wrong tool here. Instead, BEFORE
// any database or FCM work runs, `Deno.serve` below compares the incoming
// `Authorization` header against `SUPABASE_SERVICE_ROLE_KEY` with
// `timingSafeEqualStrings()` and returns a bare 401 on any mismatch --
// including when the header is absent. Before this check was added, this
// comment claimed that authentication without the code actually doing it:
// with `verify_jwt=false` and no incoming check, the endpoint was open to
// the internet, harmless only because FCM_SERVICE_ACCOUNT was unset. The
// moment that secret is set, an unauthenticated caller could spam pushes
// for any guessed/enumerated notification_id and burn FCM quota -- hence
// checking auth first and returning nothing that would tell an
// unauthenticated caller whether the id it sent was ever valid.

import { createClient } from "jsr:@supabase/supabase-js@2";

import { corsHeaders } from "../_shared/cors.ts";

type ErrorWithMessage = {
  message?: string;
};

const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}

function getErrorMessage(error: unknown): string {
  if (error && typeof error === "object" && "message" in error) {
    return (error as ErrorWithMessage).message ?? "Unknown error";
  }

  if (typeof error === "string") {
    return error;
  }

  return "Unknown error";
}

const supabaseUrl =
  Deno.env.get("SUPABASE_URL") ?? Deno.env.get("APP_SUPABASE_URL") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

/**
 * Constant-time-ish string comparison for the incoming Authorization check.
 *
 * Deno's std lib has no built-in `timingSafeEqual` for strings (only for
 * `Uint8Array`/`ArrayBuffer` via `std/crypto`), and pulling in another
 * import for one comparison is more surface than this needs. This does the
 * same thing by hand: XOR every byte position without short-circuiting, so
 * a mismatch at byte 0 and a mismatch at byte 40 take the same number of
 * iterations. It only equalises the *length* of work, not scheduler jitter
 * or network timing, so it is "-ish" -- but the value being compared is a
 * long, high-entropy service-role key, not a short PIN, so early-exit
 * character-by-character leakage is the realistic risk this closes, and a
 * naive `===` is exactly that leak.
 */
function timingSafeEqualStrings(a: string, b: string): boolean {
  const aBytes = new TextEncoder().encode(a);
  const bBytes = new TextEncoder().encode(b);
  const len = Math.max(aBytes.length, bBytes.length);
  let diff = aBytes.length === bBytes.length ? 0 : 1;
  for (let i = 0; i < len; i++) {
    diff |= (aBytes[i] ?? 0) ^ (bBytes[i] ?? 0);
  }
  return diff === 0;
}

// -----------------------------------------------------------------------
// FCM HTTP v1 only. The legacy `server key` / `Authorization: key=...` API
// is retired by Google and must not be used -- HTTP v1 is the only
// supported surface, and it requires an OAuth2 access token minted from a
// service-account JSON, not a static key.
// -----------------------------------------------------------------------

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const normalized = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll(/\s/g, "");
  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

/**
 * Mints a short-lived OAuth2 access token via the JWT-grant flow, scoped to
 * `firebase.messaging` only -- not a broad Google API credential.
 */
async function getFcmAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const encodedHeader = base64UrlEncode(encoder.encode(JSON.stringify(header)));
  const encodedClaimSet = base64UrlEncode(
    encoder.encode(JSON.stringify(claimSet)),
  );
  const signingInput = `${encodedHeader}.${encodedClaimSet}`;

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(signingInput),
  );

  const assertion = `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!tokenResponse.ok) {
    const text = await tokenResponse.text();
    throw new Error(`FCM OAuth2 token request failed: ${tokenResponse.status} ${text}`);
  }

  const tokenJson = await tokenResponse.json() as { access_token?: string };
  if (!tokenJson.access_token) {
    throw new Error("FCM OAuth2 token response had no access_token");
  }
  return tokenJson.access_token;
}

type FcmSendResult = {
  token: string;
  ok: boolean;
  errorCode?: string;
};

async function sendToToken(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<FcmSendResult> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
        },
      }),
    },
  );

  if (response.ok) {
    return { token, ok: true };
  }

  let errorCode: string | undefined;
  try {
    const errorJson = await response.json();
    // FCM v1 error shape: error.details[].errorCode (or .status as a fallback)
    const details = errorJson?.error?.details;
    if (Array.isArray(details)) {
      const withCode = details.find((d: Record<string, unknown>) =>
        typeof d?.errorCode === "string"
      );
      errorCode = withCode?.errorCode as string | undefined;
    }
    errorCode ??= errorJson?.error?.status as string | undefined;
  } catch {
    // Body wasn't JSON -- leave errorCode undefined, still not ok.
  }

  return { token, ok: false, errorCode };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Reject before ANY database or FCM work, so an unauthenticated caller
  // cannot use this endpoint as a notification-existence oracle (a valid
  // notification_id must not behave any differently from an invalid one
  // for a caller that never gets past this point). The 401 body says
  // nothing beyond "Unauthorized" -- no echo of the id, no distinction
  // between "missing header" and "wrong key".
  const incomingAuth = req.headers.get("Authorization") ?? "";
  const expectedAuth = `Bearer ${supabaseServiceRoleKey}`;
  if (
    !supabaseServiceRoleKey ||
    !timingSafeEqualStrings(incomingAuth, expectedAuth)
  ) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  // No Firebase project exists yet -- this is the normal state until Jean
  // creates one and sets this secret. A trigger that raised or warned on
  // every notification insert while this is unset would be noise that
  // trains people to ignore warnings; this endpoint mirrors that by
  // returning success rather than an error.
  const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!serviceAccountRaw) {
    return jsonResponse({ ok: true, skipped: "no FCM credentials" });
  }

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    return jsonResponse(
      { error: "Supabase function environment variables are not configured" },
      500,
    );
  }

  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(serviceAccountRaw) as ServiceAccount;
    if (
      !serviceAccount.project_id || !serviceAccount.client_email ||
      !serviceAccount.private_key
    ) {
      throw new Error("FCM_SERVICE_ACCOUNT is missing required fields");
    }
  } catch (error) {
    return jsonResponse(
      { error: `FCM_SERVICE_ACCOUNT is not valid: ${getErrorMessage(error)}` },
      500,
    );
  }

  const serviceRoleClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });

  try {
    const payload = await req.json() as { notification_id?: string };
    const notificationId = payload.notification_id?.trim();
    if (!notificationId) {
      return jsonResponse({ error: "notification_id is required" }, 400);
    }

    const { data: notification, error: notificationError } =
      await serviceRoleClient
        .from("notifications")
        .select("id, user_id, title, message, metadata")
        .eq("id", notificationId)
        .maybeSingle();

    if (notificationError) {
      throw notificationError;
    }

    if (!notification) {
      // Nothing to send -- the row may have been for a probe/test id, or
      // deleted between insert and fan-out. Not an error for this endpoint.
      return jsonResponse({ ok: true, skipped: "notification not found" });
    }

    const { data: tokens, error: tokensError } = await serviceRoleClient
      .from("device_tokens")
      .select("id, token")
      .eq("user_id", notification.user_id)
      .is("disabled_at", null);

    if (tokensError) {
      throw tokensError;
    }

    if (!tokens || tokens.length === 0) {
      return jsonResponse({ ok: true, skipped: "no live device tokens" });
    }

    const accessToken = await getFcmAccessToken(serviceAccount);

    const metadata = (notification.metadata ?? {}) as Record<string, unknown>;
    // Reuses the existing metadata.nav_tab convention that in-app
    // notifications already use, so the same deep-link data drives both.
    const data: Record<string, string> = {
      notification_id: notification.id,
    };
    if (typeof metadata.route === "string") data.route = metadata.route;
    if (typeof metadata.nav_tab === "string") data.nav_tab = metadata.nav_tab;

    const results = await Promise.all(
      tokens.map((t: { id: string; token: string }) =>
        sendToToken(
          accessToken,
          serviceAccount.project_id,
          t.token,
          notification.title ?? "",
          notification.message ?? "",
          data,
        ).then((result) => ({ ...result, id: t.id }))
      ),
    );

    // A token FCM reports as UNREGISTERED or INVALID_ARGUMENT is never
    // coming back to life -- the app was uninstalled, or the token rotated.
    // An unpruned list degrades quietly until sends fail in bulk, so disable
    // it now rather than leaving it to be discovered later.
    const toDisable = results
      .filter((r) =>
        !r.ok && (r.errorCode === "UNREGISTERED" || r.errorCode === "INVALID_ARGUMENT")
      )
      .map((r) => r.id);

    if (toDisable.length > 0) {
      const { error: disableError } = await serviceRoleClient
        .from("device_tokens")
        .update({ disabled_at: new Date().toISOString() })
        .in("id", toDisable);

      if (disableError) {
        console.error("Failed to disable dead device tokens:", disableError.message);
      }
    }

    return jsonResponse({
      ok: true,
      sent: results.filter((r) => r.ok).length,
      failed: results.filter((r) => !r.ok).length,
      disabled: toDisable.length,
    });
  } catch (error) {
    return jsonResponse({ error: getErrorMessage(error) }, 500);
  }
});
