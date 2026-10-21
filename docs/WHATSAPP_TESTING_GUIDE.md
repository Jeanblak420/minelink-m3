# WhatsApp OTP Testing Guide for MineLink-M3

This guide explains how to test the WhatsApp OTP authentication flow once the Meta WhatsApp Business Platform setup is complete.

## Testing Prerequisites

Before testing, ensure you have:

1. ✅ Meta Developer account with WhatsApp Business Platform configured
2. ✅ WhatsApp Business Account (WABA) created and verified
3. ✅ Business phone number verified and added to WABA
4. ✅ WhatsApp Cloud API credentials configured in Supabase Edge Function
5. ✅ OTP message template approved by Meta
6. ✅ Supabase Edge Function deployed with environment variables set
7. ✅ Supabase Phone provider enabled with SMS hook configured

## Testing Flow

### 1. Development Mode Testing (Without Meta Setup)

The Edge Function includes a development mode that logs OTP codes to the console when Meta credentials are not configured. This allows testing the UI flow without WhatsApp setup.

**To test in dev mode:**
1. Ensure Meta credentials are NOT set in Edge Function environment variables
2. Run the Flutter app
3. Enter a WhatsApp number on login screen
4. Click "Or sign in with WhatsApp code"
5. Check Supabase Edge Function logs for the OTP code
6. Enter the code in the app
7. Verify login succeeds

**Viewing Edge Function logs:**
```bash
# Via Supabase CLI
supabase functions logs whatsapp-send-otp

# Or in Supabase Dashboard > Edge Functions > whatsapp-send-otp > Logs
```

### 2. Production Testing (With Meta Setup)

Once Meta credentials are configured, test the full WhatsApp flow:

**Step 1: Test OTP Delivery**
1. Run the Flutter app
2. Enter your verified WhatsApp business number (or test number)
3. Click "Or sign in with WhatsApp code"
4. Check your WhatsApp app for the OTP message
5. Verify the message format: "Your MineLink verification code is 123456. This code expires in 5 minutes."

**Step 2: Test OTP Verification**
1. Enter the received 6-digit code
2. Click "Verify & sign in"
3. Verify successful login and redirect to appropriate dashboard

**Step 3: Test Error Cases**
- **Invalid number**: Enter a non-phone format and verify error message
- **Expired code**: Wait 5+ minutes, then try to verify the code
- **Wrong code**: Enter an incorrect 6-digit code
- **Resend functionality**: Test the resend timer and button

**Step 4: Test Account Types**
- Test with admin-created WhatsApp users (synthetic email accounts)
- Test with regular email/password users trying WhatsApp login
- Verify proper routing after successful authentication

## Expected Behavior

### Successful Flow
1. User enters WhatsApp number → Number format validation
2. User requests code → Edge Function called via Supabase SMS hook
3. Meta WhatsApp API sends message → User receives WhatsApp message
4. User enters code → Code verified with Supabase
5. Session established → User redirected to appropriate dashboard

### Error Handling
- **Invalid phone format**: "Enter your WhatsApp number first so we know where to send the code"
- **Meta API failure**: "We could not send a code to that number. Please try again."
- **Invalid/expired code**: "Invalid or expired code. Please try again."
- **Network timeout**: "Signing in is taking longer than expected. Check your connection and try again."

## Monitoring and Debugging

### Edge Function Logs
Monitor the Edge Function logs for:
- Meta API call success/failure
- OTP generation and delivery
- Error messages from Meta API
- SMS hook trigger events

### Supabase Auth Logs
Check Supabase Dashboard > Authentication > Logs for:
- Phone auth request events
- OTP verification attempts
- Session creation events

### Meta WhatsApp Dashboard
Monitor Meta for Developers > WhatsApp > API requests for:
- Message delivery status
- Rate limiting
- Template usage statistics
- Error responses

## Common Issues and Solutions

### Issue: OTP not received on WhatsApp
**Possible causes:**
- Meta credentials not configured correctly
- Template not approved
- Phone number not verified
- Rate limiting from Meta

**Solutions:**
- Check Edge Function environment variables
- Verify template status in Meta dashboard
- Ensure phone number is verified in WABA
- Check Meta API rate limits

### Issue: "Invalid or expired code" error
**Possible causes:**
- Code entered incorrectly
- Code expired (5-minute timeout)
- Wrong phone number used

**Solutions:**
- Re-enter code carefully
- Request new code if expired
- Verify phone number format

### Issue: Edge Function not triggered
**Possible causes:**
- SMS hook not configured in Supabase
- Edge Function not deployed
- Network connectivity issues

**Solutions:**
- Verify SMS hook URL in Supabase Auth settings
- Check Edge Function deployment status
- Test network connectivity

## Performance Testing

Test the flow under various conditions:
- Slow network connections
- High latency scenarios
- Concurrent login attempts
- Rate limiting behavior

## Security Testing

Verify security measures:
- OTP codes are not logged in production
- Rate limiting prevents abuse
- Expired codes cannot be reused
- Session properly established after verification

## User Acceptance Testing

Test with real users:
- Clear UI instructions
- Intuitive workflow
- Helpful error messages
- Appropriate timeout handling
- Mobile responsiveness

## Success Criteria

The WhatsApp OTP flow is considered working when:
- ✅ OTP codes are sent via WhatsApp (not SMS)
- ✅ Codes are verified correctly
- ✅ Sessions are established properly
- ✅ Error handling is user-friendly
- ✅ The flow works as an additional login option
- ✅ Email/password remains the primary login method
- ✅ No SMS messages are sent during the process