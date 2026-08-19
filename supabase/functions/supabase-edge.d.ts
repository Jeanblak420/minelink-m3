// Type definitions for Supabase Edge Functions

// Deno namespace
declare namespace Deno {
  export interface Env {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    toObject(): { [key: string]: string };
  }

  export const env: Env;
}

// HTTP server module
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

// Supabase client module
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

  export interface PostgrestFilterBuilder<T> {
    eq(column: string, value: any): PostgrestFilterBuilder<T>;
    neq(column: string, value: any): PostgrestFilterBuilder<T>;
    gt(column: string, value: any): PostgrestFilterBuilder<T>;
    gte(column: string, value: any): PostgrestFilterBuilder<T>;
    lt(column: string, value: any): PostgrestFilterBuilder<T>;
    lte(column: string, value: any): PostgrestFilterBuilder<T>;
    like(column: string, pattern: string): PostgrestFilterBuilder<T>;
    ilike(column: string, pattern: string): PostgrestFilterBuilder<T>;
    is(column: string, value: any): PostgrestFilterBuilder<T>;
    in(column: string, values: any[]): PostgrestFilterBuilder<T>;
    contains(column: string, value: any): PostgrestFilterBuilder<T>;
    containedBy(column: string, value: any): PostgrestFilterBuilder<T>;
    rangeLt(column: string, range: any): PostgrestFilterBuilder<T>;
    rangeGt(column: string, range: any): PostgrestFilterBuilder<T>;
    rangeGte(column: string, range: any): PostgrestFilterBuilder<T>;
    rangeLte(column: string, range: any): PostgrestFilterBuilder<T>;
    rangeAdjacent(column: string, range: any): PostgrestFilterBuilder<T>;
    overlaps(column: string, value: any): PostgrestFilterBuilder<T>;
    textSearch(column: string, query: string, options?: { config?: string }): PostgrestFilterBuilder<T>;
    filter(column: string, operator: string, value: any): PostgrestFilterBuilder<T>;
    not(column: string, operator: string, value: any): PostgrestFilterBuilder<T>;
    or(filters: string, options?: { foreignTable?: string }): PostgrestFilterBuilder<T>;
    select(columns?: string): PostgrestFilterBuilder<T>;
    order(column: string, options?: { ascending?: boolean; nullsFirst?: boolean; foreignTable?: string }): PostgrestFilterBuilder<T>;
    limit(count: number, options?: { foreignTable?: string }): PostgrestFilterBuilder<T>;
    offset(count: number, options?: { foreignTable?: string }): PostgrestFilterBuilder<T>;
    single(): Promise<{ data: T | null; error: Error | null }>;
    maybeSingle(): Promise<{ data: T | null; error: Error | null }>;
  }

  export interface PostgrestQueryBuilder<T> {
    select(columns?: string): PostgrestFilterBuilder<T>;
    insert(values: Partial<T> | Partial<T>[], options?: { returning?: 'minimal' | 'representation' }): Promise<{ data: T[]; error: Error | null }>;
    upsert(values: Partial<T> | Partial<T>[], options?: { onConflict?: string; returning?: 'minimal' | 'representation' }): Promise<{ data: T[]; error: Error | null }>;
    update(values: Partial<T>, options?: { returning?: 'minimal' | 'representation' }): PostgrestFilterBuilder<T>;
    delete(options?: { returning?: 'minimal' | 'representation' }): PostgrestFilterBuilder<T>;
  }

  export class SupabaseClient {
    constructor(supabaseUrl: string, supabaseKey: string, options?: SupabaseClientOptions);
    from<T = any>(table: string): PostgrestQueryBuilder<T>;
    auth: {
      signUp(credentials: { email: string; password: string }): Promise<{ data: any; error: Error | null }>;
      signIn(credentials: { email: string; password: string }): Promise<{ data: any; error: Error | null }>;
      signOut(): Promise<{ error: Error | null }>;
      session(): any;
    };
    storage: {
      from(bucket: string): {
        upload(path: string, file: File | Blob | ArrayBuffer, options?: any): Promise<{ data: any; error: Error | null }>;
        download(path: string): Promise<{ data: Blob; error: Error | null }>;
        getPublicUrl(path: string): { publicURL: string };
        remove(paths: string[]): Promise<{ data: any; error: Error | null }>;
        list(prefix?: string, options?: { limit?: number; offset?: number; sortBy?: { column?: string; order?: string } }): Promise<{ data: any; error: Error | null }>;
      };
    };
    rpc<T = any>(fn: string, params?: object): Promise<{ data: T; error: Error | null }>;
    functions: {
      invoke(name: string, options?: { body?: any }): Promise<{ data: any; error: Error | null }>;
    };
  }

  export function createClient(supabaseUrl: string, supabaseKey: string, options?: SupabaseClientOptions): SupabaseClient;
}
