/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'primary': '#76B852',
        'dark': '#0A0A0A',
        'light': '#F5F5F5',
        'accent': '#8BC34A',
        'gray': {
          100: '#f5f5f5',
          200: '#e5e5e5',
          300: '#d4d4d4',
          400: '#a3a3a3',
          500: '#737373',
          600: '#525252',
          700: '#404040',
          800: '#262626',
          900: '#171717',
        },
      },
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
      },
      width: {
        '7/8': '87.5%'
      }
    },
  },
  plugins: [],
  darkMode: 'class', // Enables dark mode variants with the 'dark' class
}