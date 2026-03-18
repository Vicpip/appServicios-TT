import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#1A4FD6',
          dark: '#0D2E8A',
          light: '#3B6FE8',
        },
        navy: {
          DEFAULT: '#0F1B3D',
          light: '#1A2D5A',
        },
        surface: '#F8FAFF',
        border: '#E2E8F0',
      },
      fontFamily: {
        sans: ['DM Sans', 'sans-serif'],
        heading: ['Inter', 'sans-serif'],
        display: ['Syne', 'sans-serif'],
      },
    },
  },
  plugins: [],
}

export default config
