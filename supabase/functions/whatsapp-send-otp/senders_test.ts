import { assertEquals, assertInstanceOf } from "jsr:@std/assert@1";
import { DevConsoleSender, MetaCloudSender, selectSender } from "./senders.ts";

Deno.test("selectSender defaults to DevConsoleSender", () => {
  assertInstanceOf(selectSender({}), DevConsoleSender);
});

Deno.test("selectSender returns DevConsoleSender when OTP_SENDER=dev", () => {
  assertInstanceOf(selectSender({ OTP_SENDER: "dev" }), DevConsoleSender);
});

Deno.test("selectSender returns MetaCloudSender when meta is fully configured", () => {
  const sender = selectSender({
    OTP_SENDER: "meta",
    META_WABA_PHONE_ID: "123",
    META_WABA_TOKEN: "tok",
    META_OTP_TEMPLATE: "otp_login",
  });
  assertInstanceOf(sender, MetaCloudSender);
});

Deno.test("selectSender falls back to dev when meta creds are missing", () => {
  assertInstanceOf(selectSender({ OTP_SENDER: "meta" }), DevConsoleSender);
});

Deno.test("DevConsoleSender.send resolves without throwing", async () => {
  await new DevConsoleSender().send("+27821234567", "123456");
  assertEquals(true, true);
});
