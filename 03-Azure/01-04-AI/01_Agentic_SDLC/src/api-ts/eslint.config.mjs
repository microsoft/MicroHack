import js from '@eslint/js'
import globals from 'globals'
import tseslint from 'typescript-eslint'
import { defineConfig } from "eslint/config";


export default defineConfig(
  // Global ignores
  { 
    ignores: ['dist/**', 'node_modules/**', 'coverage/**'] 
  },
  // Base config for all TypeScript files
  {
    extends: [
      js.configs.recommended, 
      ...tseslint.configs.recommended,
      ...tseslint.configs.strict
    ],
    files: ['**/*.{ts,js}'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: {
        ...globals.node,
        ...globals.es2022
      }
    },
    rules: {
      // Custom rules for Express/Node.js API
      'no-unused-vars': 'off', // Handled by TypeScript ESLint
      '@typescript-eslint/no-unused-vars': ['warn', { 
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_' 
      }],
      '@typescript-eslint/explicit-function-return-type': 'off',
      '@typescript-eslint/no-explicit-any': 'warn',
      'prefer-const': 'error',
      'prefer-template': 'error',
      'no-var': 'error'
    }
  },
  // Specific config for test files
  {
    files: ['**/*.test.{ts,js}', '**/*.spec.{ts,js}'],
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.jest
      }
    },
    rules: {
      // Allow console in tests
      'no-console': 'off',
      // Allow any in tests for mocking
      '@typescript-eslint/no-explicit-any': 'off'
    }
  }
)
