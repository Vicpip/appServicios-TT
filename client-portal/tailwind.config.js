/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // ── Exact admin-web tokens ──────────────────────────────────────────
        primary: {
          DEFAULT: '#1A4FD6',
          dark:    '#0D2E8A',
          light:   '#3B6FE8',
        },
        navy: {
          DEFAULT: '#0F1B3D',
          light:   '#1A2D5A',
        },
        surface: '#F8FAFF',
        border:  '#E2E8F0',
        // ── Semantic aliases used across client portal pages ────────────────
        brand: {
          success: '#16A34A',
          warning: '#D97706',
          danger:  '#DC2626',
        },
      },
      fontFamily: {
        sans:    ['DM Sans', 'sans-serif'],
        heading: ['Inter', 'sans-serif'],
        display: ['Syne', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
