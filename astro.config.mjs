import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';
import sitemap from '@astrojs/sitemap';
import react from '@astrojs/react';
import vercel from '@astrojs/vercel';

export default defineConfig({
  site: 'https://parentcompass.ai',
  adapter: vercel(),
  integrations: [tailwind(), sitemap(), react()],
  security: {
    checkOrigin: false,
  },
});
