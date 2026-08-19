# Supabase Edge Functions Guide

This guide explains how to create and deploy Supabase Edge Functions using the provided scripts.

## Prerequisites

- Supabase CLI (installed via Scoop)
- Supabase account (for deployment)

## Creating a New Edge Function

To create a new Edge Function, use the `supabase-functions-new.bat` script:

```bash
.\supabase-functions-new.bat function-name
```

This will create a new Edge Function with the specified name in the `supabase/functions/` directory.

## Deploying an Edge Function

To deploy an Edge Function to your Supabase project, use the `supabase-functions-deploy.bat` script:

```bash
.\supabase-functions-deploy.bat function-name
```

Before deploying, make sure you are logged in to the Supabase CLI:

```bash
supabase login
```

## Running Edge Functions Locally

To run Edge Functions locally, you need to have Docker Desktop installed and running. Once Docker is installed, you can use the following command:

```bash
.\supabase-cli.bat functions serve
```

## Function Structure

Each Edge Function has the following structure:

```
supabase/
  functions/
    function-name/
      index.ts      # The main function code
    _shared/
      cors.ts       # Shared CORS headers
```

## Example Function

Here's an example of a simple Edge Function:

```typescript
// Follow this setup guide to integrate the Deno runtime into your application:
// https://deno.com/manual/runtime/manual/npm_node

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from "../_shared/cors.ts"

console.log("Hello from Function!")

serve(async (req) => {
  // This is needed if you're planning to invoke your function from a browser.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { name } = await req.json()
    const data = {
      message: `Hello ${name}!`,
    }

    return new Response(
      JSON.stringify(data),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
```

## Calling Edge Functions from Your Flutter App

To call an Edge Function from your Flutter app, use the `supabase.functions.invoke` method:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<void> callFunction() async {
  try {
    final response = await supabase.functions.invoke(
      'function-name',
      body: {'name': 'World'},
    );
    
    print(response.data); // {"message": "Hello World!"}
  } catch (error) {
    print('Error calling function: $error');
  }
}
```

## Troubleshooting

If you encounter issues with the Supabase CLI, try the following:

1. Make sure you are logged in to the Supabase CLI:
   ```bash
   .\supabase-cli.bat login
   ```

2. Check if your Supabase project is linked:
   ```bash
   .\supabase-cli.bat link --project-ref your-project-ref
   ```

3. If you need to run functions locally, install Docker Desktop from [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)

For more information, see the [Supabase Edge Functions documentation](https://supabase.com/docs/guides/functions).
