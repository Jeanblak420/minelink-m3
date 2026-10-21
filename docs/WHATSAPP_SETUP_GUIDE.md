# WhatsApp Business Platform Setup Guide for MineLink-M3

This guide walks through setting up the Meta WhatsApp Business Platform (Cloud API) to deliver OTP codes for MineLink-M3 authentication.

## Overview

MineLink-M3 uses WhatsApp OTP as an **additional** login method alongside the primary email/password authentication. The flow:

1. User enters WhatsApp number on login screen
2. Supabase generates OTP and triggers Edge Function via SMS hook
3. Edge Function calls Meta WhatsApp Cloud API (NO SMS involved)
4. WhatsApp sends OTP to user's phone
5. User enters OTP in app
6. Supabase verifies OTP and establishes session

## Architecture

This implementation uses Supabase's phone auth system but replaces SMS delivery with WhatsApp Cloud API:

- **Flutter app**: Uses standard Supabase phone auth (`signInWithOtp`, `verifyOTP`)
- **Supabase**: Generates OTP codes and triggers the SMS hook
- **Edge Function**: Intercepts SMS hook and calls Meta WhatsApp Cloud API instead
- **Meta WhatsApp**: Delivers OTP via WhatsApp (no SMS provider involved)

## Prerequisites

- Meta Developer account (you already have this)
- Supabase project (MineLink-M3 uses `yftazblpmicqtamyiwyb`)
- Valid business phone number for WhatsApp Business

## Step 1: Create Meta/Facebook App

1. Go to [Meta for Developers](https://developers.facebook.com/)
2. Click "Create App" 
3. Select "Business" type
4. Choose "WhatsApp" as the product
5. Fill in app details:
   - App name: "MineLink Authentication"
   - Contact email: your business email
6. Complete app setup

## Step 2: Add WhatsApp to Your App

1. In your app dashboard, click "Add Product"
2. Select "WhatsApp"
3. Configure WhatsApp Cloud API settings

## Step 3: Create WhatsApp Business Account (WABA)

1. In WhatsApp product settings, click "Get Started"
2. Create or link a WhatsApp Business Account
3. Verify your business information
4. Add and verify your business phone number

## Step 4: Configure API Credentials

1. In WhatsApp Cloud API settings, find:
   - **Access Token**: Generate a temporary access token (System User)
   - **Phone Number ID**: Your verified WhatsApp business number ID

2. Store these securely (see §6 below)

## Step 5: Create OTP Message Template

WhatsApp requires approved message templates for initiating conversations:

1. Go to WhatsApp > Message Templates
2. Click "Create Message Template"
3. Template configuration:
   - **Name**: `otp_verification`
   - **Category**: `Authentication`
   - **Language**: `en` (English)
   - **Content**: 
     ```
     Your {{1}} verification code is {{2}}. This code expires in 5 minutes.
     ```
   - **Variables**: 
     - `{{1}}`: App name (e.g., "MineLink")
     - `{{2}}`: OTP code

4. Submit for approval (Meta reviews this - typically 1-2 business days)

## Step 6: Configure Supabase Edge Function

The existing Edge Function `whatsapp-send-otp` is already configured to use Meta Cloud API. Set these environment variables in Supabase dashboard:

```bash
META_WABA_PHONE_ID=your_phone_number_id_here
META_WABA_TOKEN=your_access_token_here
META_OTP_TEMPLATE=otp_verification
```

The Edge Function is located at `supabase/functions/whatsapp-send-otp/` and works as a Supabase SMS hook that delivers via WhatsApp instead of SMS.

## Step 7: Configure Supabase SMS Hook

1. Go to Supabase Dashboard > Authentication > Providers > Phone
2. Enable the Phone provider
3. Configure the SMS hook URL to point to your Edge Function:
   - URL: `https://your-project.supabase.co/functions/v1/whatsapp-send-otp`
   - Secret: Set a secret and add it as `SEND_SMS_HOOK_SECRET` in Edge Function env vars

## Step 8: Test the Integration

Once setup is complete:

1. Test OTP sending from login screen
2. Verify WhatsApp message delivery
3. Test full flow in MineLink-M3 app
4. Verify OTP codes work for login

## Security Notes

- **Never expose WhatsApp credentials in Flutter app** - they stay in Edge Function
- Edge Function uses Supabase service role (never in client code)
- Rotate access tokens periodically
- Implement rate limiting if needed
- Monitor WhatsApp API usage and costs

## Meta WhatsApp Cloud API Pricing

- Free tier: 1,000 conversations per month
- Paid tier: Varies by conversation type
- OTP messages are typically "service" conversations
- Monitor usage to avoid unexpected charges

## Troubleshooting

**Template not approved**: Ensure template follows Meta's messaging policies. OTP templates are usually fast-tracked.

**Edge Function not receiving SMS hook**: Check SMS hook URL is correctly configured in Supabase Auth settings.

**Rate limiting**: Monitor Edge Function logs for API rate limits from Meta.

**Phone number verification**: Ensure your business number can receive SMS/calls for verification.

## Development Mode

During development, the Edge Function will log OTP codes to the console if Meta credentials are not configured. This allows testing without WhatsApp setup.

## Next Steps

After completing this setup, the WhatsApp login option will be fully functional in MineLink-M3 as an additional authentication method alongside email/password.