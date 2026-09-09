$ErrorActionPreference = 'Continue'
$base = 'https://yftazblpmicqtamyiwyb.supabase.co'
$key  = 'sb_publishable__v4NAadmMazm3CLy9RGeeQ_cuzyVhy4'
$tmp  = $env:TEMP
$stamp = Get-Date -Format 'yyyyMMddHHmmss'

function Invoke-Create($label, $payload) {
  $path = "$tmp\payload_$($label -replace '[^a-z]', '').json"
  Set-Content -Path $path -Value ($payload | ConvertTo-Json -Compress) -Encoding ASCII
  Write-Output "---- $label ----"
  curl.exe -s -o "$tmp\resp.json" -w "HTTP %{http_code}`n" -X POST "$base/functions/v1/company-user-admin" `
    -H "Authorization: Bearer $script:tok" -H "apikey: $key" -H "Content-Type: application/json" `
    --data-binary "@$path"
  Get-Content "$tmp\resp.json" -Raw
  Write-Output ""
}

# 1) Sign in as the transporter owner exactly like the app does
Set-Content -Path "$tmp\auth.json" -Value '{"email":"roadhaul.owner@mineralguide.com","password":"MineralGuide123!"}' -Encoding ASCII
$authRaw = curl.exe -s -X POST "$base/auth/v1/token?grant_type=password" -H "apikey: $key" -H "Content-Type: application/json" --data-binary "@$tmp\auth.json"
$auth = $authRaw | ConvertFrom-Json
if (-not $auth.access_token) {
  Write-Output "AUTH FAILED: $authRaw"
  exit 1
}
$tok = $auth.access_token
Write-Output "AUTH OK (user $($auth.user.id))"

# 2) CASE A: email only (no whatsapp key at all) - app sends effectiveEmail, no whatsapp
Invoke-Create 'emailonly' @{
  action = 'create_employee'
  email = "driver.a.$stamp@example.com"
  password = 'TestPass123!'
  first_name = 'Email'
  last_name = 'Only'
  role = 'driver'
}

# 3) CASE B: whatsapp only, NO email key - edge function derives synthetic email;
#    0-prefixed local number must become E.164 +27...
$waB = '082' + $stamp.Substring(7)
Invoke-Create 'waonly' @{
  action = 'create_employee'
  password = 'TestPass123!'
  first_name = 'Whatsapp'
  last_name = 'Only'
  whatsapp_number = $waB
  role = 'driver'
}
Write-Output "(whatsapp used: $waB -> expect phone +27$($waB.Substring(1)), email wa-$($waB)@wa.mineralguide.com)"

# 4) CASE C: both email and whatsapp
$waC = '083' + $stamp.Substring(7)
Invoke-Create 'both' @{
  action = 'create_employee'
  email = "driver.c.$stamp@example.com"
  password = 'TestPass123!'
  first_name = 'Both'
  last_name = 'Fields'
  whatsapp_number = $waC
  role = 'driver'
}

