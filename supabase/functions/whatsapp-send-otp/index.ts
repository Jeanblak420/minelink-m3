import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import { selectSender } from "./senders.ts";

const hookSecret = (Deno.env.get("SEND_SMS_HOOK_SECRET") ?? "").replace(
  "v1,whsec_",
  "",
);

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: { http_code: 405, message: "Method not allowed" } }), { status: 405 });
  }

  const payload = await req.text();
  let user: { phone?: string };
  let sms: { otp?: string };
  try {
    const wh = new Webhook(hookSecret);
    const verified = wh.verify(payload, Object.fromEntries(req.headers)) as {
      user: { phone?: string };
      sms: { otp?: string };
    };
    user = verified.user;
    sms = verified.sms;
  } catch (_e) {
    return new Response(
      JSON.stringify({ error: { http_code: 401, message: "Invalid signature" } }),
      { status: 401 },
    );
  }

  const phone = user?.phone ?? "";
  const otp = sms?.otp ?? "";
  if (!phone || !otp) {
    return new Response(
      JSON.stringify({ error: { http_code: 400, message: "Missing phone or otp" } }),
      { status: 400 },
    );
  }

  try {
    await selectSender(Deno.env.toObject()).send(phone, otp);
  } catch (e) {
    const message = e instanceof Error ? e.message : "Delivery failed";
    return new Response(
      JSON.stringify({ error: { http_code: 500, message } }),
      { status: 500 },
    );
  }

  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
