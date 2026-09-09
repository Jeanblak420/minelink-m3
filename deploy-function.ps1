$ErrorActionPreference = 'Stop'
$token = 'sbp_fc071fca812fc7a562e676bb4324fd62cf1804bb'
$project = 'yftazblpmicqtamyiwyb'
$meta = '{"entrypoint_path":"functions/company-user-admin/index.ts","verify_jwt":false}'

Write-Output "Deploying company-user-admin to $project ..."
$response = curl.exe -s -X PUT "https://api.supabase.com/v1/projects/$project/functions/company-user-admin" `
  -H "Authorization: Bearer $token" `
  -F "metadata=$meta;type=application/json" `
  -F "files=@supabase/functions/company-user-admin/index.ts;filename=functions/company-user-admin/index.ts;type=application/octet-stream" `
  -F "files=@supabase/functions/_shared/cors.ts;filename=functions/_shared/cors.ts;type=application/octet-stream"

Write-Output $response
