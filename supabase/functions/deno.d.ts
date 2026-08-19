// Type definitions for Deno APIs
// This file is used to provide type information for Deno-specific APIs

declare namespace Deno {
  export interface Env {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    toObject(): { [key: string]: string };
  }

  export const env: Env;
}

declare module "https://deno.land/std@0.168.0/http/server.ts" {
  export interface ServeInit {
    port?: number;
    hostname?: string;
    handler: (request: Request) => Response | Promise<Response>;
    onError?: (error: unknown) => Response | Promise<Response>;
    signal?: AbortSignal;
    onListen?: (params: { hostname: string; port: number }) => void;
  }

  export function serve(handler: (request: Request) => Response | Promise<Response>, options?: Omit<ServeInit, "handler">): void;
  export function serve(options: ServeInit): void;
}

declare module "https://esm.sh/@supabase/supabase-js@2" {
  export interface SupabaseClientOptions {
    auth?: {
      autoRefreshToken?: boolean;
      persistSession?: boolean;
      detectSessionInUrl?: boolean;
    };
    global?: {
      headers?: Record<string, string>;
      fetch?: typeof fetch;
    };
    realtime?: {
      channels?: any[];
      endpoint?: string;
      eventsPerSecond?: number;
    };
  }

  export class SupabaseClient {
    constructor(supabaseUrl: string, supabaseKey: string, options?: SupabaseClientOptions);
    from(table: string): any;
    auth: any;
    storage: any;
    rpc(fn: string, params?: object): any;
    functions: {
      invoke(name: string, options?: { body?: any }): Promise<{ data: any; error: any }>;
    };
  }

  export function createClient(supabaseUrl: string, supabaseKey: string, options?: SupabaseClientOptions): SupabaseClient;
}
