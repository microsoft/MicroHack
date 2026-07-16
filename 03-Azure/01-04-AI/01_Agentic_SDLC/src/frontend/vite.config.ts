import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5137,
    host: '0.0.0.0',
    strictPort: true,
  },
  define: {
    'process.env.CODESPACE_NAME': JSON.stringify(process.env.CODESPACE_NAME),
  },
});
