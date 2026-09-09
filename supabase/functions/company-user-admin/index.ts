import { createClient } from "jsr:@supabase/supabase-js@2";

import { corsHeaders } from "../_shared/cors.ts";

type CreateEmployeePayload = {
  action: "create_employee";
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  whatsapp_number?: string;
  role: string;
};

type UploadCompanyLogoPayload = {
  action: "upload_company_logo";
  company_id: string;
  file_name: string;
  file_extension: string;
  file_bytes_base64: string;
};

type SupportedPayload = CreateEmployeePayload | UploadCompanyLogoPayload;

type ErrorWithMessage = {
  message?: string;
};

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

function getErrorMessage(error: unknown): string {
  if (error && typeof error === "object" && "message" in error) {
    return (error as ErrorWithMessage).message ?? "Unknown error";
  }

  if (typeof error === "string") {
    return error;
  }

  return "Unknown error";
}

/**
 * The Postgres SQLSTATE, when the failure came from the database.
 *
 * Without this the app can only see the error *text*. The seat gate
 * (`enforce_employee_seat_limit`, SQLSTATE `MLS01`) has to be told apart from
 * every other reason a create can fail, so the client can offer "request extra
 * seats" instead of a dead snackbar. Matching on the message would break the
 * moment the wording is edited.
 *
 * Additive: existing callers read `error` and are unaffected.
 */
function getErrorCode(error: unknown): string | null {
  if (error && typeof error === "object" && "code" in error) {
    const code = (error as { code?: unknown }).code;
    if (typeof code === "string" && code.length > 0) return code;
  }
  return null;
}

// Domain used for synthetic WhatsApp-identity emails. Must stay in sync with
// `kWhatsappAuthEmailDomain` in
// lib/features/auth/utils/whatsapp_identity.dart — the login form maps a typed
// WhatsApp number back to this same address.
const WHATSAPP_AUTH_EMAIL_DOMAIN = "wa.mineralguide.com";

function whatsappAuthEmail(whatsappNumber: string): string {
  const digits = whatsappNumber.replace(/\D/g, "");
  if (!digits) return "";
  return `wa-${digits}@${WHATSAPP_AUTH_EMAIL_DOMAIN}`;
}

/**
 * Formats a WhatsApp number as an E.164 phone string (`+<digits>`).
 *
 * E.164 forbids a leading zero, but local South African numbers are typed with
 * a leading trunk `0` (`0821234567`); the leading `0` is replaced with the `27`
 * country code. Must stay in sync with `whatsappToE164` in
 * lib/features/auth/utils/whatsapp_identity.dart so the stored phone matches
 * the one used at WhatsApp OTP login. Returns "" when there are no digits.
 */
function whatsappToE164(whatsappNumber: string): string {
  let digits = whatsappNumber.replace(/\D/g, "");
  if (!digits) return "";
  if (digits.startsWith("0")) {
    digits = `27${digits.slice(1)}`;
  }
  return `+${digits}`;
}

function validatePayload(payload: Partial<SupportedPayload>): string | null {
  if (payload.action === "create_employee") {
    const email = payload.email?.trim() ?? "";
    const password = payload.password ?? "";
    const firstName = payload.first_name?.trim() ?? "";
    const lastName = payload.last_name?.trim() ?? "";
    const whatsappNumber = payload.whatsapp_number?.trim() ?? "";
    const role = payload.role?.trim() ?? "";

    // Require at least one of email or WhatsApp number
    const hasEmail = email.includes("@");
    const hasWhatsapp = whatsappNumber.length > 0;
    if (!hasEmail && !hasWhatsapp) {
      return "Either a valid email address or WhatsApp number is required";
    }

    if (password.length < 6) {
      return "Password must be at least 6 characters long";
    }

    if (!firstName) {
      return "First name is required";
    }

    if (!lastName) {
      return "Last name is required";
    }

    if (!role) {
      return "Role is required";
    }

    return null;
  }

  if (payload.action === "upload_company_logo") {
    const companyId = payload.company_id?.trim() ?? "";
    const fileName = payload.file_name?.trim() ?? "";
    const fileBytesBase64 = payload.file_bytes_base64?.trim() ?? "";
    const fileExtension = payload.file_extension?.trim().toLowerCase() ?? "";

    if (!companyId) {
      return "Company ID is required";
    }

    if (!fileName) {
      return "File name is required";
    }

    if (!fileBytesBase64) {
      return "File data is required";
    }

    if (!["png", "jpg", "jpeg", "webp", "svg", "svgz"].includes(fileExtension)) {
      return "Unsupported image format";
    }

    return null;
  }

  return "Unsupported action";
}

function base64ToBytes(value: string): Uint8Array {
  const normalized = value.replaceAll(/\s/g, "");
  const binary = atob(normalized);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

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
    global: {
      headers: {
        Authorization: authHeader,
      },
    },
  });

  const serviceRoleClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });

  let createdUserId: string | null = null;

  try {
    const token = authHeader.replace("Bearer ", "").trim();
    const { data: authData, error: authError } = await callerClient.auth
      .getUser(token);

    if (authError || !authData.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const payload = await req.json() as Partial<SupportedPayload>;
    const validationError = validatePayload(payload);
    if (validationError != null) {
      return jsonResponse({ error: validationError }, 400);
    }

    if (payload.action === "upload_company_logo") {
      const companyId = payload.company_id!.trim();
      const fileName = payload.file_name!.trim();
      const fileExtension = payload.file_extension!.trim().toLowerCase();
      const fileBytes = base64ToBytes(payload.file_bytes_base64!);

      if (fileBytes.byteLength === 0) {
        return jsonResponse({ error: "Uploaded file was empty" }, 400);
      }

      if (fileBytes.byteLength > 10 * 1024 * 1024) {
        return jsonResponse(
          { error: "Company logo must be 10MB or smaller" },
          400,
        );
      }

      const { data: companyData, error: companyError } = await callerClient
        .from("companies")
        .select("id")
        .eq("id", companyId)
        .eq("user_id", authData.user.id)
        .maybeSingle();

      if (companyError) {
        throw companyError;
      }

      if (!companyData) {
        return jsonResponse(
          { error: "You can only upload a logo for your own company" },
          403,
        );
      }

      const contentType = (() => {
        switch (fileExtension) {
          case "png":
            return "image/png";
          case "jpg":
          case "jpeg":
            return "image/jpeg";
          case "webp":
            return "image/webp";
          case "svg":
          case "svgz":
            return "image/svg+xml";
          default:
            return "image/png";
        }
      })();

      const objectPath = `company_logos/${companyId}/logo.${fileExtension}`;

      const { error: uploadError } = await serviceRoleClient.storage
        .from("company_assets")
        .upload(objectPath, fileBytes, {
          cacheControl: "3600",
          upsert: true,
          contentType,
        });

      if (uploadError) {
        throw uploadError;
      }

      const { error: profileError } = await callerClient.rpc(
        "update_my_company_profile",
        {
          logo_url_input: objectPath,
        },
      );

      if (profileError) {
        throw profileError;
      }

      const logoUrl = serviceRoleClient.storage
        .from("company_assets")
        .getPublicUrl(objectPath);

      return jsonResponse({
        success: true,
        file_name: fileName,
        logo_path: objectPath,
        logo_url: logoUrl,
      });
    }

    // Type assertion: at this point we've validated it's a create_employee action
    const createPayload = payload as CreateEmployeePayload;
    // `email` is optional at runtime (WhatsApp-only creates omit the key);
    // the CreateEmployeePayload type says `string`, but absent keys are
    // `undefined` — coalesce before trim.
    const email = (createPayload.email ?? "").trim().toLowerCase();
    const password = createPayload.password;
    const firstName = createPayload.first_name.trim();
    const lastName = createPayload.last_name.trim();
    const whatsappNumber = createPayload.whatsapp_number?.trim() ?? "";
    const role = createPayload.role.trim();
    const displayName = `${firstName} ${lastName}`.trim();

    // Build auth user params - only set phone if WhatsApp number provided.
    // Supabase requires an email per auth user, so a WhatsApp-only create
    // derives the same deterministic synthetic email the login form uses.
    // GoTrue requires strict E.164 (`+[1-9]\d{1,14}`); a locally-typed
    // `0821234567` must become `+27821234567` or user creation fails with
    // "Invalid phone number format (E.164 required)".
    const hasWhatsapp = whatsappNumber.length > 0;
    const effectiveEmail = email || (hasWhatsapp ? whatsappAuthEmail(whatsappNumber) : "");
    const phoneE164 = hasWhatsapp ? whatsappToE164(whatsappNumber) : undefined;

    const { data: createdUserData, error: createUserError } =
      await serviceRoleClient.auth.admin.createUser({
        email: effectiveEmail,
        password,
        phone: phoneE164,
        email_confirm: true,
        phone_confirm: hasWhatsapp,
        user_metadata: {
          user_type: "employee",
          display_name: displayName,
        },
      });

    if (createUserError || !createdUserData.user) {
      return jsonResponse(
        { error: getErrorMessage(createUserError) },
        400,
      );
    }

    createdUserId = createdUserData.user.id;

    const { data: employeeData, error: employeeError } = await callerClient.rpc(
      "create_company_managed_employee",
      {
        target_user_id: createdUserId,
        first_name_input: firstName,
        last_name_input: lastName,
        // `employees.whatsapp_number` is nullable; email-only employees store
        // NULL (the RPC's `trim(NULL)` stays NULL, and the column has no
        // unique index so duplicates are fine).
        whatsapp_number_input: hasWhatsapp ? whatsappNumber : null,
        target_role: role,
      },
    );

    if (employeeError) {
      throw employeeError;
    }

    return jsonResponse({
      success: true,
      employee: employeeData,
      email,
      user_id: createdUserId,
    });
  } catch (error) {
    if (createdUserId != null) {
      const { error: cleanupError } = await serviceRoleClient.auth.admin
        .deleteUser(createdUserId);

      if (cleanupError) {
        console.error(
          "Failed to clean up auth user after company employee creation error:",
          cleanupError.message,
        );
      }
    }

    return jsonResponse(
      { error: getErrorMessage(error), code: getErrorCode(error) },
      400,
    );
  }
});
