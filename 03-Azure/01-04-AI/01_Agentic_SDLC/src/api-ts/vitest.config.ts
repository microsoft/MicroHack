/// <reference types="vitest" />
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: false,
    environment: 'node',
    coverage: {
      // Include json-summary so CI can read api/coverage/coverage-summary.json
      reporter: ['text', 'json', 'json-summary', 'html'],
    },
    exclude: ['dist/**', 'node_modules/**', 'database/**']
  },
});
