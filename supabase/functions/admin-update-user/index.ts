import { createClient } from "jsr:@supabase/supabase-js@2";

import { corsHeaders } from "../_shared/cors.ts";

// Lets a super global admin change ANY user's sign-in credentials — password,
// email and/or phone — across every company on the platform.
//
// Authored from the MineLink-M3 project on 2026-10-17 at Jean's explicit
// instruction, as a one-off exception to the M3 "never change the database from
// here" rule. It is additive: it creates no table, alters no function, and the
// shipping app does not call it.
//
// Security boundary is HERE, not in the Dart UI: the caller's JWT is verified,
// then `public.is_platform_admin()` is evaluated AS THE CALLER. Only then does
// the service-role client touch `auth.users`. Every change is written to
// `public.audit_logs` — the password itself is never logged, only the fact
// that it changed.

type UpdateUserPayload = {
  target_user_id?: string;
  password?: string;
  email?: string;
  phone?: string;
};

const supabaseUrl =
  Deno.env.get("SUPABASE_URL") ?? Deno.env.get("APP_SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function getErrorMessage(error: unknown): string {
  if (error && typeof error === "object" && "message" in error) {
    return (error as { message?: string }).message ?? "Unknown error";
  }
  if (typeof error === "string") return error;
  return "Unknown error";
}

// Must stay in sync with company-user-admin/index.ts and
// lib/features/auth/utils/whatsapp_identity.dart.
const WHATSAPP_AUTH_EMAIL_DOMAIN = "wa.mineralguide.com";

function whatsappAuthEmail(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  return digits ? `wa-${digits}@${WHATSAPP_AUTH_EMAIL_DOMAIN}` : "";
}

/** `0821234567` → `+27821234567`; same rule as company-user-admin. */
function toE164(phone: string): string {
  let digits = phone.replace(/\D/g, "");
  if (!digits) return "";
  if (digits.startsWith("0")) digits = `27${digits.slice(1)}`;
  return `+${digits}`;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }
  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return jsonResponse(
      { error: "Supabase function environment variables are not configured" },
      500,
    );
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header" }, 401);
  }

  const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });

  try {
    const token = authHeader.replace("Bearer ", "").trim();
    const { data: authData, error: authError } = await callerClient.auth
      .getUser(token);
    if (authError || !authData.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }
    const caller = authData.user;

    // Evaluated as the caller — the same predicate every super-admin RLS
    // policy uses.
    const { data: isAdmin, error: adminError } = await callerClient.rpc(
      "is_platform_admin",
    );
    if (adminError) throw adminError;
    if (isAdmin !== true) {
      return jsonResponse(
        { error: "Only a super global admin can change another user's login details" },
        403,
      );
    }

    const payload = await req.json() as UpdateUserPayload;
    const targetId = payload.target_user_id?.trim() ?? "";
    if (!UUID_RE.test(targetId)) {
      return jsonResponse({ error: "A valid target_user_id is required" }, 400);
    }

    const password = payload.password ?? "";
    const email = payload.email?.trim().toLowerCase() ?? "";
    const phoneRaw = payload.phone?.trim() ?? "";

    if (!password && !email && !phoneRaw) {
      return jsonResponse({ error: "Nothing to change" }, 400);
    }
    if (password && password.length < 6) {
      return jsonResponse(
        { error: "Password must be at least 6 characters long" },
        400,
      );
    }
    if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return jsonResponse({ error: "That email address is not valid" }, 400);
    }
    const phone = phoneRaw ? toE164(phoneRaw) : "";
    if (phoneRaw && phone.replace(/\D/g, "").length < 9) {
      return jsonResponse({ error: "That phone number is not valid" }, 400);
    }

    const { data: targetData, error: targetError } = await admin.auth.admin
      .getUserById(targetId);
    if (targetError || !targetData.user) {
      return jsonResponse({ error: "User not found" }, 404);
    }
    const target = targetData.user;
    const oldEmail = target.email ?? "";
    const oldPhone = target.phone ? `+${target.phone.replace(/^\+/, "")}` : "";

    const attrs: Record<string, unknown> = {};
    const changed: string[] = [];

    if (password) {
      attrs.password = password;
      changed.push("password");
    }

    // Compared in E.164, so `0821234567` and `+27821234567` are the same number.
    const phoneChanged = phone !== "" && phone !== oldPhone;

    let newEmail = email;
    // A WhatsApp-only account signs in with a synthetic email derived from
    // its number. Moving the number without moving that email would lock the
    // user out of WhatsApp login, so follow it unless an email was given.
    //
    // Derived from the number AS TYPED (`phoneRaw`), not its E.164 form:
    // creation (company-user-admin) and the login form both take the typed
    // digits, so `0821234567` must map to `wa-0821234567@…`. Using the E.164
    // digits produced `wa-27821234567@…`, which nothing would ever look up.
    //
    // Only when the number really changed. Re-typing the SAME number in another
    // shape (`+27…` for `0…`) used to rewrite the login email anyway — found
    // 2026-10-19 when exactly that locked a test user out of number sign-in.
    if (
      !newEmail && phoneChanged &&
      oldEmail.endsWith(`@${WHATSAPP_AUTH_EMAIL_DOMAIN}`)
    ) {
      newEmail = whatsappAuthEmail(phoneRaw);
    }
    if (newEmail && newEmail !== oldEmail.toLowerCase()) {
      attrs.email = newEmail;
      attrs.email_confirm = true;
      changed.push("email");
    }

    if (phoneChanged) {
      attrs.phone = phone;
      attrs.phone_confirm = true;
      changed.push("phone");
    }

    if (changed.length === 0) {
      return jsonResponse({ success: true, changed: [] });
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(
      targetId,
      attrs,
    );
    if (updateError) {
      return jsonResponse({ error: getErrorMessage(updateError) }, 400);
    }

    // profiles.email follows auth.users via handle_auth_user_updated. The
    // number shown on the employee card lives on employees, so keep it in step.
    if (changed.includes("phone")) {
      const { error: empError } = await admin
        .from("employees")
        .update({ whatsapp_number: phoneRaw })
        .eq("user_id", targetId);
      if (empError) console.warn("employees phone sync failed", empError);
    }

    // Audit — best effort, but loud in the logs if it fails.
    const { data: callerProfile } = await admin
      .from("profiles")
      .select("platform_role, display_name")
      .eq("id", caller.id)
      .maybeSingle();
    const { data: targetProfile } = await admin
      .from("profiles")
      .select("display_name")
      .eq("id", targetId)
      .maybeSingle();
    const { data: targetEmployee } = await admin
      .from("employees")
      .select("company_id")
      .eq("user_id", targetId)
      .limit(1)
      .maybeSingle();

    const before: Record<string, unknown> = {};
    const after: Record<string, unknown> = { changed };
    if (changed.includes("email")) {
      before.email = oldEmail;
      after.email = attrs.email;
    }
    if (changed.includes("phone")) {
      before.phone = oldPhone;
      after.phone = phone;
    }

    const { error: auditError } = await admin.from("audit_logs").insert({
      actor_user_id: caller.id,
      actor_email: caller.email ?? "",
      actor_platform_role: callerProfile?.platform_role ?? "unknown",
      action_type: "USER_CREDENTIALS_UPDATED",
      target_type: "user",
      target_id: targetId,
      target_name: targetProfile?.display_name ?? oldEmail,
      organization_id: targetEmployee?.company_id ?? null,
      description: `Super admin changed ${changed.join(", ")} for ${
        targetProfile?.display_name ?? oldEmail
      }`,
      before_data: Object.keys(before).length ? before : null,
      after_data: after,
    });
    if (auditError) console.error("audit insert failed", auditError);

    return jsonResponse({
      success: true,
      changed,
      email: (attrs.email as string | undefined) ?? oldEmail,
      phone: (attrs.phone as string | undefined) ?? oldPhone,
    });
  } catch (error) {
    console.error("admin-update-user failed", error);
    return jsonResponse({ error: getErrorMessage(error) }, 500);
  }
});
