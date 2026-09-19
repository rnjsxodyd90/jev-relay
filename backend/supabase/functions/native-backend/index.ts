import {HARD_LIMITS, ServiceError, createNativeBackendHandler, normalizeLimits} from '../_shared/handler.mjs';
import {createProviders} from '../_shared/providers.mjs';
import {createSupabaseAdapters} from '../_shared/supabase.mjs';

const env = (name: string) => Deno.env.get(name) ?? '';
const supabaseUrl = env('SUPABASE_URL');
const serviceRoleKey = env('SUPABASE_SERVICE_ROLE_KEY');
const anonKey = env('SUPABASE_ANON_KEY');
const publishableKey = env('SUPABASE_PUBLISHABLE_KEY') || env('APP_PUBLISHABLE_KEY');
const quotaPepper = env('QUOTA_PEPPER');
const jevKey = env('TYPESAFE_API_KEY');
const qwenKey = env('NEBIUS_API_KEY');

let limits = HARD_LIMITS;
let limitsReady = true;
try {
  limits = normalizeLimits({
    userDaily: env('USER_DAILY_REQUEST_LIMIT'),
    globalDaily: env('GLOBAL_DAILY_REQUEST_LIMIT'),
    globalMonthly: env('GLOBAL_MONTHLY_REQUEST_LIMIT'),
  });
} catch {
  limitsReady = false;
}

const readiness = {
  auth: Boolean(supabaseUrl && serviceRoleKey && anonKey),
  quota: Boolean(supabaseUrl && serviceRoleKey && quotaPepper.length >= 32 && limitsReady),
  jev: Boolean(jevKey),
  qwen: Boolean(qwenKey),
  deletion: Boolean(supabaseUrl && serviceRoleKey),
};

let auth: {getUser(token: string): Promise<{id: string}>} = {
  async getUser() { throw new ServiceError(); },
};
let quota: {reserve(input: unknown): Promise<void>} = {
  async reserve() { throw new ServiceError(); },
};
let accounts: {deleteUser(userId: string): Promise<void>} = {
  async deleteUser() { throw new ServiceError(); },
};
if (readiness.auth && readiness.deletion) {
  try {
    ({auth, quota, accounts} = createSupabaseAdapters({
      supabaseUrl,
      serviceRoleKey,
      anonKey,
      publishableKey,
      quotaPepper,
    }));
  } catch {
    readiness.auth = false;
    readiness.quota = false;
    readiness.deletion = false;
  }
}

const providers = createProviders({jevKey, qwenKey});
const handler = createNativeBackendHandler({auth, quota, accounts, providers, limits, readiness});

Deno.serve(handler);
