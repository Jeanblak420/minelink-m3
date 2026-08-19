import { createClient } from "jsr:@supabase/supabase-js@2";

import { corsHeaders } from "../_shared/cors.ts";

// Resolves a shortened map link to its coordinates, server-side.
//
// The web build cannot do this itself. maps.app.goo.gl serves no CORS headers,
// so a request from the browser fails outright — measured in Chrome at the
// app's own origin, "TypeError: Failed to fetch" for both a plain fetch and
// one with redirect:"manual". Native builds have no such restriction, but the
// client calls this on every platform so there is one behaviour to reason
// about rather than two.
//
// Long /maps/place/ URLs never reach here: they already carry !3d/!4d and are
// parsed on the device with no network at all.

const supabaseUrl =
  Deno.env.get("SUPABASE_URL") ?? Deno.env.get("APP_SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

/// Hosts this function will fetch. Without an allowlist the function is an
/// SSRF primitive: anyone with a session could point it at an internal address
/// and use the redirect chain to probe what it can reach.
const allowedHosts = new Set([
  "maps.app.goo.gl",
  "goo.gl",
  "maps.google.com",
  "www.google.com",
  "google.com",
  "g.co",
  "www.openstreetmap.org",
  "openstreetmap.org",
  "osm.org",
]);

function hostAllowed(u: URL): boolean {
  if (u.protocol !== "https:" && u.protocol !== "http:") return false;
  const host = u.hostname.toLowerCase();
  if (allowedHosts.has(host)) return true;
  // google.co.za, google.com.au, … — country domains of the same service.
  return /^(www\.)?google\.[a-z.]{2,6}$/.test(host);
}

type Point = { lat: number; lng: number };

function validated(latS: string, lngS: string): Point | null {
  const lat = Number(latS);
  const lng = Number(lngS);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return { lat, lng };
}

/// Same precedence as the Dart side (maps_short_link.dart), deliberately:
/// !3d/!4d is the PLACE pin, ?q= is an explicit query point, and @lat,lng is
/// only the viewport centre — wherever the map happened to be scrolled when
/// the link was made. Taking @ over !3d can be tens of metres out.
function pointFromUrl(url: string): Point | null {
  const pin = /!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/.exec(url);
  if (pin) {
    const p = validated(pin[1], pin[2]);
    if (p) return p;
  }
  const q = /[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/.exec(url);
  if (q) {
    const p = validated(q[1], q[2]);
    if (p) return p;
  }
  const at = /@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/.exec(url);
  if (at) return validated(at[1], at[2]);
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }
  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  // A signed-in user, not merely a valid anon key. The anon key is embedded in
  // every shipped web bundle, so accepting it would leave an open URL-follower
  // on the internet.
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header" }, 401);
  }
  const caller = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const token = authHeader.replace("Bearer ", "").trim();
  const { data: authData, error: authErr } = await caller.auth.getUser(token);
  if (authErr || !authData.user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let link = "";
  try {
    const body = (await req.json()) as { link?: string };
    link = (body.link ?? "").trim();
  } catch (_e) {
    return jsonResponse({ error: "Body must be JSON" }, 400);
  }
  if (!link) return jsonResponse({ error: "A link is required" }, 400);

  let current: URL;
  try {
    current = new URL(link);
  } catch (_e) {
    return jsonResponse({ error: "That is not a URL" }, 400);
  }
  if (!hostAllowed(current)) {
    return jsonResponse({ error: "Only Google Maps and OpenStreetMap links "
      + "can be resolved" }, 400);
  }

  // The link may already carry its point (a long URL pasted through here).
  const immediate = pointFromUrl(current.toString());
  if (immediate) return jsonResponse({ ...immediate, hops: 0 });

  try {
    for (let hop = 0; hop < 5; hop++) {
      const res = await fetch(current.toString(), {
        redirect: "manual",
        headers: {
          // Google hands a bare client a consent interstitial; a browser-shaped
          // request gets the real redirect.
          "User-Agent":
            "Mozilla/5.0 (compatible; MineLink/1.0; +https://minelink.co.za)",
          "Accept-Language": "en",
        },
        signal: AbortSignal.timeout(10_000),
      });

      const location = res.headers.get("location");
      if (!location) {
        // Some hops answer 200 with the coordinates in the body's canonical
        // link rather than a header.
        const body = await res.text();
        const fromBody = pointFromUrl(body.slice(0, 200_000));
        if (fromBody) return jsonResponse({ ...fromBody, hops: hop + 1 });
        break;
      }

      const next = new URL(location, current);
      if (!hostAllowed(next)) {
        return jsonResponse({ error: "That link redirects somewhere "
          + "unexpected" }, 400);
      }
      const p = pointFromUrl(next.toString());
      if (p) return jsonResponse({ ...p, hops: hop + 1 });
      current = next;
    }
  } catch (e) {
    const message = e instanceof Error ? e.message : "Could not follow the link";
    return jsonResponse({ error: message }, 502);
  }

  return jsonResponse({ error: "That link did not carry a location" }, 404);
});
