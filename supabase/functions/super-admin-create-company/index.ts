import { createClient } from "jsr:@supabase/supabase-js@2";

import { corsHeaders } from "../_shared/cors.ts";

const supabaseUrl =
  Deno.env.get("SUPABASE_URL") ?? Deno.env.get("APP_SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

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

type Body = {
  company_name?: string;
  whatsapp_number?: string;
  org_type?: string;
  ceo_first_name?: string;
  ceo_last_name?: string;
  owner_email?: string;
  temporary_password?: string | null;
};

const allowedOrgTypes = new Set(["mineSupplier", "buyer", "transporter"]);

function randomPassword(length = 14): string {
  const chars =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let s = "";
  for (let i = 0; i < length; i++) {
    s += chars[bytes[i]! % chars.length];
  }
  return s;
}

function validate(body: Body): string | null {
  const name = body.company_name?.trim() ?? "";
  const wa = body.whatsapp_number?.trim() ?? "";
  const org = body.org_type?.trim() ?? "";
  const email = body.owner_email?.trim().toLowerCase() ?? "";
  if (!name) return "Company name is required";
  if (!wa) return "WhatsApp number is required";
  if (!allowedOrgTypes.has(org)) return "Invalid organization type";
  if (!email || !email.includes("@")) return "A valid owner email is required";
  const pwd = body.temporary_password?.trim();
  if (pwd !== undefined && pwd !== null && pwd !== "" && pwd.length < 8) {
    return "Temporary password must be at least 8 characters when provided";
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }
  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header" }, 401);
  }

  const caller = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });

  let createdUserId: string | null = null;

  try {
    const token = authHeader.replace("Bearer ", "").trim();
    const { data: authData, error: authErr } = await caller.auth.getUser(token);
    if (authErr || !authData.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const actorId = authData.user.id;
    const body = (await req.json()) as Body;
    const verr = validate(body);
    if (verr) return jsonResponse({ error: verr }, 400);

    const { data: actorProfile, error: apErr } = await caller
      .from("profiles")
      .select("platform_role, email")
      .eq("id", actorId)
      .maybeSingle();
    if (apErr) throw apErr;

    const role = actorProfile?.platform_role as string | undefined;
    if (
      role !== "superGlobalSerialAdminMain" &&
      role !== "superGlobalSerialAdminMainChild"
    ) {
      return jsonResponse({ error: "Platform admin access required" }, 403);
    }

    if (role === "superGlobalSerialAdminMainChild") {
      const { data: settings, error: sErr } = await caller
        .from("platform_admin_settings")
        .select(
          "child_super_admin_user_id, child_can_register_companies",
        )
        .eq("id", "main")
        .maybeSingle();
      if (sErr) throw sErr;
      if (
        settings?.child_super_admin_user_id !== actorId ||
        !settings?.child_can_register_companies
      ) {
        return jsonResponse(
          { error: "Child admin is not permitted to register companies" },
          403,
        );
      }
    }

    const companyName = body.company_name!.trim();
    const whatsapp = body.whatsapp_number!.trim();
    const orgType = body.org_type!.trim();
    const ceoFirst = (body.ceo_first_name ?? "").trim();
    const ceoLast = (body.ceo_last_name ?? "").trim();
    const ownerEmail = body.owner_email!.trim().toLowerCase();
    const tempPassword =
      (body.temporary_password?.trim() && body.temporary_password.trim().length > 0)
        ? body.temporary_password.trim()
        : randomPassword(14);

    const { data: created, error: cuErr } = await admin.auth.admin.createUser({
      email: ownerEmail,
      password: tempPassword,
      email_confirm: true,
      user_metadata: {
        user_type: "company",
        display_name: companyName,
      },
    });

    if (cuErr || !created.user) {
      return jsonResponse(
        { error: cuErr?.message ?? "Failed to create auth user" },
        400,
      );
    }

    createdUserId = created.user.id;

    const { error: profErr } = await admin.from("profiles").update({
      user_type: "company",
      display_name: companyName,
      must_change_password: true,
    }).eq("id", createdUserId);

    if (profErr) throw profErr;

    const { data: companyRow, error: insErr } = await admin
      .from("companies")
      .insert({
        user_id: createdUserId,
        company_name: companyName,
        whatsapp_number: whatsapp,
        org_type: orgType,
        ceo_first_name: ceoFirst || null,
        ceo_last_name: ceoLast || null,
      })
      .select("id, company_name, org_type")
      .single();

    if (insErr || !companyRow) {
      throw insErr ?? new Error("Company insert failed");
    }

    const actorEmail = (actorProfile?.email as string | undefined) ?? "";
    const actorPlatformRole = role ?? "normalUser";

    const { error: logErr } = await admin.from("audit_logs").insert({
      actor_user_id: actorId,
      actor_email: actorEmail,
      actor_platform_role: actorPlatformRole,
      action_type: "COMPANY_REGISTERED_BY_PLATFORM",
      target_type: "company",
      target_id: companyRow.id,
      target_name: companyName,
      organization_id: companyRow.id,
      organization_name: companyName,
      organization_type: orgType,
      description:
        "Company registered by platform admin for owner " + ownerEmail,
    });
    if (logErr) {
      console.error("audit_logs insert:", logErr.message);
    }

    return jsonResponse({
      success: true,
      company_id: companyRow.id,
      company_name: companyRow.company_name,
      org_type: companyRow.org_type,
      owner_email: ownerEmail,
      temporary_password: tempPassword,
    });
  } catch (e) {
    if (createdUserId) {
      await admin.auth.admin.deleteUser(createdUserId);
    }
    const msg = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: msg }, 400);
  }
});
