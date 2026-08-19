# CORS Troubleshooting Guide

## Understanding the Issue

You may have encountered a warning about using the `--disable-web-security` flag:

```
You are using an unsupported command-line flag: --disable-web-security. Stability and security will suffer.
```

This flag disables important security features in Chrome and should be avoided.

## Proper Solution for CORS Issues

### 1. Configure Supabase CORS Settings

1. Log in to your Supabase dashboard
2. Go to Project Settings > API
3. Under "API Settings", find the CORS section
4. Add `http://localhost:63965` to the list of allowed origins
5. If you deploy your app, also add your production domain

### 2. Use the Safe Run Scripts

Instead of manually adding unsafe flags, use the provided safe scripts:
- `run_web_safe.bat` (Windows Command Prompt)
- `run_web_safe.ps1` (Windows PowerShell)

### 3. Clear Browser Cache and Cookies

Sometimes CORS issues persist due to cached data:
1. Open Chrome DevTools (F12)
2. Right-click on the refresh button and select "Empty Cache and Hard Reload"
3. Try clearing cookies for localhost

### 4. Check Network Requests

If you're still having issues:
1. Open Chrome DevTools (F12)
2. Go to the Network tab
3. Look for requests with CORS errors (they'll be red)
4. Check the error message for specific details

### 5. Temporary Development Workaround

If you absolutely need a temporary workaround during development:
- Use a CORS proxy service
- Use browser extensions like "CORS Unblock" (for development only)
- Consider using Flutter's built-in proxy support

**Never use `--disable-web-security` in production or shared environments.**
