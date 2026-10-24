import { createClient } from "jsr:@supabase/supabase-js@2";

import { corsHeaders } from "../_shared/cors.ts";

// Lets a super global admin change ANY user's sign-in credentials — password,
// email and/or WhatsApp number — and which of the two is their primary way in,
// across every company on the platform.
//
// Authored from the MineLink-M3 project on 2026-10-17 at Jean's explicit
// instruction, as a one-off exception to the M3 "never change the database from
// here" rule. v4 (2026-10-24, Jean's request in ADMIN-MOBILE-TODO.md 2.2) adds
// login methods: add / change / remove an email or a WhatsApp number, and set
// one of them primary. The shipping app does not call this function.
//
// Security boundary is HERE, not in the Dart UI: the caller's JWT is verified,
// then `public.is_platform_admin()` is evaluated AS THE CALLER. Only then does
// the service-role client touch `auth.users`. Every change is written to
// `public.audit_logs` — the password itself is never logged, only the fact
// that it changed.
//
// HOW AN ACCOUNT SIGNS IN (see migration 20261024110000_login_methods.sql)
//   * email + password            when auth.users.email is a real address;
//   * WhatsApp number + password  when auth.users.phone is set (phone password
//     grant), or a WhatsApp code; legacy accounts also through the placeholder
//     email `wa-<digits>@wa.mineralguide.com`.
// An account with no real email keeps a placeholder (auth needs an email).
// THE ONE RULE: a change that would leave no way to sign in is refused.

type UpdateUserPayload = {
  target_user_id?: string;
  password?: string;
  email?: string;
  phone?: string;
  remove_email?: boolean;
  remove_phone?: boolean;
  primary?: "email" | "whatsapp";
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

/** GoTrue's words for the two collisions an admin can actually cause. */
function friendlyAuthError(error: unknown): string {
  const msg = getErrorMessage(error);
  if (/email.*(already|registered|exists)/i.test(msg)) {
    return "Another account already uses that email address.";
  }
  if (/phone.*(already|registered|exists)/i.test(msg)) {
    return "Another account already uses that WhatsApp number.";
  }
  return msg;
}

// Must stay in sync with company-user-admin/index.ts and
// lib/features/auth/utils/whatsapp_identity.dart.
const WHATSAPP_AUTH_EMAIL_DOMAIN = "wa.mineralguide.com";

function isPlaceholderEmail(email: string): boolean {
  return email.toLowerCase().endsWith(`@${WHATSAPP_AUTH_EMAIL_DOMAIN}`);
}

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

/** `+27821234567` → `0821234567`, the shape people type and creation uses. */
function toLocal(e164: string): string {
  const digits = e164.replace(/\D/g, "");
  return digits.startsWith("27") ? `0${digits.slice(2)}` : digits;
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
    const removeEmail = payload.remove_email === true;
    const removePhone = payload.remove_phone === true;
    const primaryAsked = payload.primary ?? null;

    if (
      !password && !email && !phoneRaw && !removeEmail && !removePhone &&
      !primaryAsked
    ) {
      return jsonResponse({ error: "Nothing to change" }, 400);
    }
    if (primaryAsked && primaryAsked !== "email" && primaryAsked !== "whatsapp") {
      return jsonResponse({ error: "Primary must be email or whatsapp" }, 400);
    }
    if (email && removeEmail) {
      return jsonResponse({ error: "Set an email or remove it, not both" }, 400);
    }
    if (phoneRaw && removePhone) {
      return jsonResponse(
        { error: "Set a WhatsApp number or remove it, not both" },
        400,
      );
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
    if (email && isPlaceholderEmail(email)) {
      return jsonResponse(
        { error: "That is an internal WhatsApp login address, not an email" },
        400,
      );
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
    const oldEmail = (target.email ?? "").toLowerCase();
    const oldPlaceholder = isPlaceholderEmail(oldEmail);
    const oldRealEmail = oldPlaceholder ? "" : oldEmail;
    const oldPhone = target.phone ? `+${target.phone.replace(/^\+/, "")}` : "";

    // ---- the state the account will be in -------------------------------
    const finalRealEmail = removeEmail ? "" : (email || oldRealEmail);
    let finalPhone = removePhone ? "" : (phone || oldPhone);
    // A legacy WhatsApp account whose number lives only in its placeholder
    // email: give it the number as a phone before the placeholder can go, so
    // number sign-in survives an email being added.
    if (!finalPhone && !removePhone && oldPlaceholder && finalRealEmail) {
      const digits = oldEmail.replace(/^wa-/, "").split("@")[0];
      finalPhone = toE164(digits);
    }

    if (!finalRealEmail && !finalPhone) {
      return jsonResponse({
        error: "A user needs at least one way to sign in. Keep an email " +
          "address or a WhatsApp number.",
      }, 400);
    }

    // auth.users.email: the real address, or a placeholder from the number.
    let finalAuthEmail = finalRealEmail;
    if (!finalAuthEmail) {
      // Keep the existing placeholder unless the number really moved, so a
      // re-typed number in another shape cannot rewrite the login (2026-10-19).
      finalAuthEmail = oldPlaceholder && finalPhone === oldPhone
        ? oldEmail
        : whatsappAuthEmail(phoneRaw || toLocal(finalPhone));
    }

    // Primary: what was asked, else what was chosen before, else inferred.
    const { data: targetProfile } = await admin
      .from("profiles")
      .select("display_name, login_primary")
      .eq("id", targetId)
      .maybeSingle();
    const oldPrimary = (targetProfile?.login_primary as string | null) ?? null;
    const available = (m: string) =>
      m === "email" ? finalRealEmail !== "" : finalPhone !== "";
    if (primaryAsked && !available(primaryAsked)) {
      return jsonResponse({
        error: primaryAsked === "email"
          ? "Email can't be the primary sign-in: this user has no email address."
          : "WhatsApp can't be the primary sign-in: this user has no WhatsApp number.",
      }, 400);
    }
    let finalPrimary = primaryAsked ?? oldPrimary;
    if (!finalPrimary || !available(finalPrimary)) {
      finalPrimary = finalRealEmail ? "email" : "whatsapp";
    }
    // If both exist and nothing was ever chosen, keep reading it the way the
    // account was set up (placeholder → WhatsApp first).
    if (!primaryAsked && !oldPrimary && finalRealEmail && finalPhone) {
      finalPrimary = oldPlaceholder ? "whatsapp" : "email";
    }

    // ---- what changes ------------------------------------------------------
    const attrs: Record<string, unknown> = {};
    const changed: string[] = [];

    if (password) {
      attrs.password = password;
      changed.push("password");
    }
    if (finalAuthEmail !== oldEmail) {
      attrs.email = finalAuthEmail;
      attrs.email_confirm = true;
      changed.push(
        removeEmail ? "removed email" : (finalRealEmail ? "email" : "login address"),
      );
    }
    // GoTrue's admin API IGNORES `phone: ""` (measured 2026-10-24: 200, phone
    // still set, number sign-in still working), so a removal is done by
    // `admin_clear_user_phone` AFTER the email update below — that function
    // refuses to run unless the account already has a real email.
    const clearPhone = finalPhone === "" && oldPhone !== "";
    if (finalPhone !== oldPhone) {
      if (finalPhone) {
        attrs.phone = finalPhone;
        attrs.phone_confirm = true;
      }
      changed.push(finalPhone ? "WhatsApp number" : "removed WhatsApp number");
    }
    // The primary is STORED whenever it was asked for or the methods moved,
    // so the stored value and admin_login_methods' reading of a NULL can never
    // disagree. (They did once, in this function's own end-to-end test: a
    // WhatsApp account given an email answered "primary: whatsapp" here and
    // "email" from the lookup, because the inferred value was never saved.)
    const methodsChanged = attrs.email !== undefined ||
      attrs.phone !== undefined || clearPhone;
    const persistPrimary = finalPrimary !== oldPrimary &&
      (primaryAsked !== null || methodsChanged);
    // Only worth a line in the audit when someone chose it, or it moved from
    // a value someone had chosen.
    const primaryChanged = persistPrimary &&
      (primaryAsked !== null || oldPrimary !== null);

    if (changed.length === 0 && !persistPrimary) {
      return jsonResponse({
        success: true,
        changed: [],
        email: finalRealEmail || null,
        phone: finalPhone || null,
        primary: finalPrimary,
      });
    }

    if (Object.keys(attrs).length > 0) {
      const { error: updateError } = await admin.auth.admin.updateUserById(
        targetId,
        attrs,
      );
      if (updateError) {
        return jsonResponse({ error: friendlyAuthError(updateError) }, 400);
      }
    }

    if (clearPhone) {
      const { error: clearError } = await admin.rpc("admin_clear_user_phone", {
        p_user_id: targetId,
      });
      if (clearError) {
        return jsonResponse({
          error: `The WhatsApp number could not be removed: ${
            getErrorMessage(clearError)
          }`,
        }, 400);
      }
    }

    if (persistPrimary) {
      const { error: primaryError } = await admin
        .from("profiles")
        .update({ login_primary: finalPrimary })
        .eq("id", targetId);
      if (primaryError) {
        return jsonResponse({
          error: `Saved, but the primary sign-in could not be set: ${
            getErrorMessage(primaryError)
          }`,
        }, 500);
      }
      if (primaryChanged) changed.push(`primary: ${finalPrimary}`);
    }

    // profiles.email follows auth.users via handle_auth_user_updated. The
    // number shown on the employee card lives on employees, so keep it in step
    // when a number is set (removing WhatsApp sign-in leaves the contact number
    // on the card alone — it is still how to reach them).
    if (finalPhone && finalPhone !== oldPhone) {
      const { error: empError } = await admin
        .from("employees")
        .update({ whatsapp_number: phoneRaw || toLocal(finalPhone) })
        .eq("user_id", targetId);
      if (empError) console.warn("employees phone sync failed", empError);
    }

    // Audit — best effort, but loud in the logs if it fails.
    const { data: callerProfile } = await admin
      .from("profiles")
      .select("platform_role, display_name")
      .eq("id", caller.id)
      .maybeSingle();
    const { data: targetEmployee } = await admin
      .from("employees")
      .select("company_id")
      .eq("user_id", targetId)
      .limit(1)
      .maybeSingle();

    const name = targetProfile?.display_name ?? oldEmail;
    const before: Record<string, unknown> = {};
    const after: Record<string, unknown> = { changed };
    if (attrs.email !== undefined) {
      before.email = oldEmail;
      after.email = attrs.email;
    }
    if (attrs.phone !== undefined) {
      before.phone = oldPhone || null;
      after.phone = finalPhone || null;
    }
    if (primaryChanged) {
      before.primary = oldPrimary;
      after.primary = finalPrimary;
    }

    const { error: auditError } = await admin.from("audit_logs").insert({
      actor_user_id: caller.id,
      actor_email: caller.email ?? "",
      actor_platform_role: callerProfile?.platform_role ?? "unknown",
      action_type: "USER_CREDENTIALS_UPDATED",
      target_type: "user",
      target_id: targetId,
      target_name: name,
      organization_id: targetEmployee?.company_id ?? null,
      description: `Super admin updated the login for ${name}: ${changed.join("; ")}`,
      before_data: Object.keys(before).length ? before : null,
      after_data: after,
    });
    if (auditError) console.error("audit insert failed", auditError);

    return jsonResponse({
      success: true,
      changed,
      email: finalRealEmail || null,
      phone: finalPhone || null,
      primary: finalPrimary,
    });
  } catch (error) {
    console.error("admin-update-user failed", error);
    return jsonResponse({ error: getErrorMessage(error) }, 500);
  }
});
