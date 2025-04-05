import prettier from 'eslint-config-prettier';
import js from '@eslint/js';
import { includeIgnoreFile } from '@eslint/compat';
import svelte from 'eslint-plugin-svelte';
import globals from 'globals';
import { fileURLToPath } from 'node:url';

const gitignorePath = fileURLToPath(new URL('./.gitignore', import.meta.url));

export default js.config(
    includeIgnoreFile(gitignorePath),
    js.configs.recommended,
    ...svelte.configs.recommended,
    prettier,
    ...svelte.configs.prettier,
    {
        languageOptions: {
            globals: { ...globals.browser, ...globals.node }
        },
        rules: {
            'no-undef': 'off'
        }
    },
    {
        files: ['**/*.svelte', '**/*.js'],
        ignores: ['eslint.config.js', 'svelte.config.js'],
        languageOptions: {
            parserOptions: {
                ecmaVersion: 2021,
                sourceType: 'module'
            }
        }
    }
);