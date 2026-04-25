import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['src/**/__tests__/**/*.test.ts'],
    environment: 'node',
    coverage: {
      provider: 'v8',
      include: ['src/lib/**/*.ts'],
      exclude: ['src/lib/__tests__/**'],
      thresholds: {
        lines: 80,
        functions: 55,
        branches: 70,
        statements: 80,
      },
      reporter: ['text', 'lcov'],
    },
  },
});
