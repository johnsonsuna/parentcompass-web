/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        forest: {
          50:  '#f0f7f4',
          100: '#d9ede6',
          200: '#b3dccf',
          300: '#7cbfab',
          400: '#4da389',
          600: '#2D6A4F',
          700: '#245A42',
          800: '#1A3A2A',
          900: '#0F2218',
        },
        sand: {
          50:  '#FDFAF5',
          100: '#F5ECD7',
          200: '#EDD9B8',
          300: '#E0C89A',
        },
        terra: {
          400: '#D4845A',
          500: '#C4603A',
          600: '#A84E2E',
        },
        stone: {
          400: '#A89A8A',
          500: '#8B7A6B',
          600: '#6B5F4E',
          700: '#4A3F32',
        },
      },
      fontFamily: {
        serif: ['Fraunces', 'Georgia', 'serif'],
        sans:  ['Plus Jakarta Sans', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
