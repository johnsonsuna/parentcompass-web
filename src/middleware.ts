import { defineMiddleware } from 'astro:middleware';
import { createSupabaseServerClient } from './lib/supabase';

export const onRequest = defineMiddleware(async (context, next) => {
  const supabase = createSupabaseServerClient(context.cookies, context.request);

  let user = null;
  try {
    // getSession reads from cookies without a network round-trip to Supabase.
    // getUser() makes an API call that can silently fail on Vercel, returning
    // null even when a valid session is present in the request cookies.
    const { data: { session } } = await supabase.auth.getSession();
    user = session?.user ?? null;
  } catch {
    // no-op during static pre-render
  }

  context.locals.supabase = supabase;
  context.locals.user = user;

  // Protect /dashboard routes — redirect to login if not authenticated
  if (context.url.pathname.startsWith('/dashboard') && !user) {
    return context.redirect('/auth/login');
  }

  return next();
});
