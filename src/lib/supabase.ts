import { createServerClient, createBrowserClient } from '@supabase/ssr';
import type { AstroCookies } from 'astro';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

export function createSupabaseServerClient(cookies: AstroCookies, request: Request) {
  return createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      // AstroCookies has no getAll() — parse the Cookie header directly.
      // This is safe: httpOnly cookies are accessible server-side regardless.
      getAll: () => {
        const header = request.headers.get('cookie') ?? '';
        if (!header) return [];
        return header.split(';').reduce<{ name: string; value: string }[]>((acc, part) => {
          const eqIdx = part.indexOf('=');
          if (eqIdx === -1) return acc;
          const name = part.slice(0, eqIdx).trim();
          const value = part.slice(eqIdx + 1).trim();
          if (name) acc.push({ name, value });
          return acc;
        }, []);
      },
      setAll: (cookiesToSet) => {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookies.set(name, value, options)
          );
        } catch {
          // no-op during static pre-render
        }
      },
    },
  });
}

export function createSupabaseBrowserClient() {
  return createBrowserClient(supabaseUrl, supabaseAnonKey);
}
