import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import react from '@astrojs/react';
import vercel from '@astrojs/vercel';

export default defineConfig({
  site: 'https://parentcompass.ai',
  adapter: vercel({ maxDuration: 60 }),
  integrations: [sitemap(), react()],
  // Astro's origin check blocks forms on Vercel/Cloudflare where Host headers
  // differ from the browser Origin. We replace it with per-form CSRF tokens
  // (httpOnly cookie + hidden input + server-side compare) on all POST routes.
  security: { checkOrigin: false },
});
