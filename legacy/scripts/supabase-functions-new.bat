@echo off
echo Creating a new Supabase Edge Function...
if "%1"=="" (
    echo Error: Function name is required.
    echo Usage: supabase-functions-new.bat function-name
    exit /b 1
)

set FUNCTION_NAME=%1
set FUNCTION_DIR=supabase\functions\%FUNCTION_NAME%

if not exist supabase\functions mkdir supabase\functions
if exist %FUNCTION_DIR% (
    echo Error: Function %FUNCTION_NAME% already exists.
    exit /b 1
)

mkdir %FUNCTION_DIR%

echo // Follow this setup guide to integrate the Deno runtime into your application:> %FUNCTION_DIR%\index.ts
echo // https://deno.com/manual/runtime/manual/npm_node>> %FUNCTION_DIR%\index.ts
echo.>> %FUNCTION_DIR%\index.ts
echo import { serve } from "https://deno.land/std@0.168.0/http/server.ts">> %FUNCTION_DIR%\index.ts
echo import { corsHeaders } from "../_shared/cors.ts">> %FUNCTION_DIR%\index.ts
echo.>> %FUNCTION_DIR%\index.ts
echo console.log("Hello from %FUNCTION_NAME% Function!")>> %FUNCTION_DIR%\index.ts
echo.>> %FUNCTION_DIR%\index.ts
echo serve(async (req) =^> {>> %FUNCTION_DIR%\index.ts
echo   // This is needed if you're planning to invoke your function from a browser.>> %FUNCTION_DIR%\index.ts
echo   if (req.method === 'OPTIONS') {>> %FUNCTION_DIR%\index.ts
echo     return new Response('ok', { headers: corsHeaders })>> %FUNCTION_DIR%\index.ts
echo   }>> %FUNCTION_DIR%\index.ts
echo.>> %FUNCTION_DIR%\index.ts
echo   try {>> %FUNCTION_DIR%\index.ts
echo     const { name } = await req.json()>> %FUNCTION_DIR%\index.ts
echo     const data = {>> %FUNCTION_DIR%\index.ts
echo       message: `Hello ${name}!`,>> %FUNCTION_DIR%\index.ts
echo     }>> %FUNCTION_DIR%\index.ts
echo.>> %FUNCTION_DIR%\index.ts
echo     return new Response(>> %FUNCTION_DIR%\index.ts
echo       JSON.stringify(data),>> %FUNCTION_DIR%\index.ts
echo       { headers: { ...corsHeaders, "Content-Type": "application/json" } },>> %FUNCTION_DIR%\index.ts
echo     )>> %FUNCTION_DIR%\index.ts
echo   } catch (error) {>> %FUNCTION_DIR%\index.ts
echo     return new Response(JSON.stringify({ error: error.message }), {>> %FUNCTION_DIR%\index.ts
echo       status: 400,>> %FUNCTION_DIR%\index.ts
echo       headers: { ...corsHeaders, "Content-Type": "application/json" },>> %FUNCTION_DIR%\index.ts
echo     })>> %FUNCTION_DIR%\index.ts
echo   }>> %FUNCTION_DIR%\index.ts
echo })>> %FUNCTION_DIR%\index.ts

if not exist supabase\functions\_shared mkdir supabase\functions\_shared

if not exist supabase\functions\_shared\cors.ts (
    echo // Follow this setup guide to integrate the Deno runtime into your application:> supabase\functions\_shared\cors.ts
    echo // https://deno.com/manual/runtime/manual/npm_node>> supabase\functions\_shared\cors.ts
    echo.>> supabase\functions\_shared\cors.ts
    echo export const corsHeaders = {>> supabase\functions\_shared\cors.ts
    echo   'Access-Control-Allow-Origin': '*',>> supabase\functions\_shared\cors.ts
    echo   'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',>> supabase\functions\_shared\cors.ts
    echo }>> supabase\functions\_shared\cors.ts
)

echo Supabase Edge Function %FUNCTION_NAME% created successfully!
echo Function directory: %FUNCTION_DIR%
echo To deploy this function, use: supabase functions deploy %FUNCTION_NAME%
