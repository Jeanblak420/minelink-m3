// Pluggable OTP delivery. DevConsoleSender logs the code (visible in function
// logs) for development; MetaCloudSender delivers via the Meta WhatsApp Cloud
// API once business credentials are configured.

export interface OtpSender {
  send(phone: string, otp: string): Promise<void>;
}

export class DevConsoleSender implements OtpSender {
  send(phone: string, otp: string): Promise<void> {
    console.log(`[DEV OTP] ${phone} -> ${otp}`);
    return Promise.resolve();
  }
}

export class MetaCloudSender implements OtpSender {
  constructor(
    private readonly phoneId: string,
    private readonly token: string,
    private readonly template: string,
  ) {}

  async send(phone: string, otp: string): Promise<void> {
    // Meta requires E.164 without the leading '+'.
    const to = phone.replace(/^\+/, "");
    const res = await fetch(
      `https://graph.facebook.com/v21.0/${this.phoneId}/messages`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${this.token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to,
          type: "template",
          template: {
            name: this.template,
            language: { code: "en" },
            components: [
              { type: "body", parameters: [{ type: "text", text: otp }] },
              {
                type: "button",
                sub_type: "url",
                index: "0",
                parameters: [{ type: "text", text: otp }],
              },
            ],
          },
        }),
      },
    );
    if (!res.ok) {
      throw new Error(`Meta send failed: ${res.status} ${await res.text()}`);
    }
  }
}

export function selectSender(env: Record<string, string | undefined>): OtpSender {
  const phoneId = env.META_WABA_PHONE_ID;
  const token = env.META_WABA_TOKEN;
  const template = env.META_OTP_TEMPLATE;
  if (env.OTP_SENDER === "meta" && phoneId && token && template) {
    return new MetaCloudSender(phoneId, token, template);
  }
  return new DevConsoleSender();
}
