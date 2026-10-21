# WhatsApp API Credentials Configuration Guide

This guide explains how to securely configure and manage Meta WhatsApp Business Platform credentials for MineLink-M3.

## Required Credentials

You need to obtain and configure the following credentials from Meta:

### 1. WhatsApp Business Phone Number ID
- **What it is**: The unique identifier for your verified WhatsApp business number
- **Where to find**: Meta for Developers > Your App > WhatsApp > Phone Numbers
- **Format**: Numeric string (e.g., "123456789012345")
- **Purpose**: Identifies which WhatsApp number sends messages

### 2. WhatsApp Access Token
- **What it is**: Authorization token for API access
- **Where to find**: Meta for Developers > Your App > WhatsApp > Setup > API Setup
- **Format**: Long alphanumeric string (e.g., "EAAFlZ...")
- **Purpose**: Authenticates API requests to Meta
- **Security**: Treat as sensitive - never commit to git

### 3. OTP Template Name
- **What it is**: The name of your approved message template
- **Where to find**: Meta for Developers > Your App > WhatsApp > Message Templates
- **Format**: String name (e.g., "otp_verification")
- **Purpose**: Specifies which template to use for OTP messages

## Supabase Edge Function Configuration

Configure these environment variables in Supabase Dashboard:

### Setting Environment Variables

1. Go to Supabase Dashboard > Edge Functions
2. Select `whatsapp-send-otp` function
3. Click "Settings" > "Environment Variables"
4. Add the following variables:

```bash
META_WABA_PHONE_ID=your_phone_number_id_here
META_WABA_TOKEN=your_access_token_here
META_OTP_TEMPLATE=otp_verification
```

### Variable Details

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `META_WABA_PHONE_ID` | Yes | Your WhatsApp Business Phone Number ID | `123456789012345` |
| `META_WABA_TOKEN` | Yes | Your WhatsApp Access Token | `EAAFlZB...` |
| `META_OTP_TEMPLATE` | Yes | Name of approved OTP template | `otp_verification` |

## Security Best Practices

### 1. Never Commit Credentials to Git
- Credentials should never be in `.env` files in the repository
- Use Supabase Dashboard environment variables only
- Never include credentials in Flutter code

### 2. Use Service Role Keys Appropriately
- Edge Functions use Supabase service role key automatically
- Never use service role key in Flutter client code
- Service role key provides full database access

### 3. Rotate Access Tokens Regularly
- Meta access tokens can expire or be revoked
- Set up a schedule to refresh tokens
- Update Edge Function environment variables when rotating

### 4. Monitor Usage and Costs
- WhatsApp API has usage limits and costs
- Monitor message delivery in Meta dashboard
- Set up alerts for unusual activity

### 5. Implement Rate Limiting
- Protect against abuse by implementing rate limits
- Monitor Edge Function logs for suspicious patterns
- Consider implementing per-IP or per-user limits

## Supabase SMS Hook Configuration

Configure the SMS hook to route OTP requests to the Edge Function:

1. Go to Supabase Dashboard > Authentication > Providers
2. Enable the Phone provider
3. Configure SMS Hook:
   - **URL**: `https://your-project.supabase.co/functions/v1/whatsapp-send-otp`
   - **Secret**: Generate a secure secret
4. Add the secret as `SEND_SMS_HOOK_SECRET` to Edge Function environment variables

## Obtaining Meta Credentials

### Step 1: Create Meta App
1. Go to [Meta for Developers](https://developers.facebook.com/)
2. Create a new app (Business type)
3. Add WhatsApp product

### Step 2: Get Phone Number ID
1. In WhatsApp settings, add your business phone number
2. Complete verification process
3. Copy the Phone Number ID from the dashboard

### Step 3: Generate Access Token
1. Go to WhatsApp > API Setup
2. Create a System User with appropriate permissions
3. Generate an access token
4. Copy the token (you won't see it again)

### Step 4: Create OTP Template
1. Go to WhatsApp > Message Templates
2. Create template with name `otp_verification`
3. Use the content:
   ```
   Your {{1}} verification code is {{2}}. This code expires in 5 minutes.
   ```
4. Submit for approval

## Environment-Specific Configuration

### Development
- For development, you can leave credentials unset
- Edge Function will log OTP codes to console instead
- This allows UI testing without Meta setup

### Production
- All credentials must be configured
- Use long-lived access tokens
- Enable monitoring and alerts
- Test failover scenarios

## Troubleshooting Configuration

### Issue: Edge Function not sending messages
**Check:**
- All three environment variables are set
- Phone Number ID is correct
- Access token is valid and not expired
- Template name matches exactly

### Issue: Template not found error
**Check:**
- Template name in environment variable matches Meta dashboard
- Template is approved (not in "submitted" status)
- Template language is set to English

### Issue: Authentication errors
**Check:**
- Access token has required permissions
- Token hasn't expired
- System user has WhatsApp messaging permissions

## Monitoring and Maintenance

### Regular Tasks
- **Weekly**: Check Meta dashboard for API usage
- **Monthly**: Review access token expiration
- **Quarterly**: Rotate access tokens
- **As needed**: Update template if Meta policies change

### Alerts to Set Up
- Failed API calls (Meta dashboard)
- High message volume (Supabase logs)
- Access token expiration (Meta dashboard)
- Edge Function errors (Supabase logs)

## Backup and Recovery

### Credential Backup
- Store credentials securely (password manager, secure vault)
- Document the process for obtaining new credentials
- Keep template content backed up

### Disaster Recovery
- Have process ready for credential rotation
- Know how to quickly disable WhatsApp login if needed
- Maintain fallback to email/password only

## Compliance and Legal

### Data Privacy
- WhatsApp messages may contain personal data
- Ensure compliance with data protection laws
- Meta may have additional compliance requirements

### Business Verification
- Meta may require business verification
- Have business documents ready
- Understand Meta's business policies

## Support Resources

- **Meta Documentation**: [WhatsApp Business Platform docs](https://developers.facebook.com/docs/whatsapp/)
- **Supabase Documentation**: [Edge Functions](https://supabase.com/docs/guides/functions)
- **Meta Support**: Contact through Meta for Developers dashboard
- **Supabase Support**: Contact through Supabase dashboard

## Quick Reference

### Environment Variables Checklist
- [ ] `META_WABA_PHONE_ID` configured
- [ ] `META_WABA_TOKEN` configured  
- [ ] `META_OTP_TEMPLATE` configured
- [ ] `SEND_SMS_HOOK_SECRET` configured (if using SMS hook)

### Meta Setup Checklist
- [ ] Meta Developer account created
- [ ] WhatsApp Business Account created
- [ ] Business phone number verified
- [ ] Access token generated
- [ ] OTP template created and approved
- [ ] SMS hook configured in Supabase

### Testing Checklist
- [ ] Development mode tested (console logging)
- [ ] Production mode tested (actual WhatsApp messages)
- [ ] Error cases tested
- [ ] Different account types tested
- [ ] Mobile responsiveness verified