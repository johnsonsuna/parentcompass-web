import { defineMiddleware } from 'astro:middleware';
import { createSupabaseServerClient } from './lib/supabase';

export const onRequest = defineMiddleware(async (context, next) => {
  const supabase = createSupabaseServerClient(context.cookies);

  let user = null;
  try {
    const { data } = await supabase.auth.getUser();
    user = data.user;
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
