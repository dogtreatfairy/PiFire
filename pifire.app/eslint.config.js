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
            'no-undef': 'off',
            'jsx-a11y/no-noninteractive-element-interactions': 'off',
            'jsx-a11y/click-events-have-key-events': 'off',
            'jsx-a11y/no-static-element-interactions': 'off',
            'jsx-a11y/anchor-is-valid': 'off',
            'svelte-a11y/no-onchange': 'off',
            'svelte-a11y/alt-text': 'off',
            'svelte-a11y/aria-roles': 'off',
            'svelte-a11y/aria-props': 'off',
            'svelte-a11y/aria-proptypes': 'off',
            'svelte-a11y/lang': 'off',
            'svelte-a11y/media-has-caption': 'off',
            'svelte-a11y/mouse-events-have-key-events': 'off',
            'svelte-a11y/no-autofocus': 'off',
            'svelte-a11y/no-distracting-elements': 'off',
            'svelte-a11y/no-interactive-element-to-noninteractive-role': 'off',
            'svelte-a11y/no-noninteractive-element-to-interactive-role': 'off',
            'svelte-a11y/no-redundant-roles': 'off',
            'svelte-a11y/role-has-required-aria-props': 'off',
            'svelte-a11y/role-supports-aria-props': 'off',
            'svelte-a11y/tabindex-no-positive': 'off'
        },
        overrides: [
            {
                files: ['**/*.svelte'],
                rules: {
                    'jsx-a11y/no-noninteractive-element-interactions': 'off',
                    'jsx-a11y/click-events-have-key-events': 'off',
                    'jsx-a11y/no-static-element-interactions': 'off',
                    'jsx-a11y/anchor-is-valid': 'off',
                    'svelte-a11y/no-onchange': 'off',
                    'svelte-a11y/alt-text': 'off',
                    'svelte-a11y/aria-roles': 'off',
                    'svelte-a11y/aria-props': 'off',
                    'svelte-a11y/aria-proptypes': 'off',
                    'svelte-a11y/lang': 'off',
                    'svelte-a11y/media-has-caption': 'off',
                    'svelte-a11y/mouse-events-have-key-events': 'off',
                    'svelte-a11y/no-autofocus': 'off',
                    'svelte-a11y/no-distracting-elements': 'off',
                    'svelte-a11y/no-interactive-element-to-noninteractive-role': 'off',
                    'svelte-a11y/no-noninteractive-element-to-interactive-role': 'off',
                    'svelte-a11y/no-redundant-roles': 'off',
                    'svelte-a11y/role-has-required-aria-props': 'off',
                    'svelte-a11y/role-supports-aria-props': 'off',
                    'svelte-a11y/tabindex-no-positive': 'off'
                }
            }
        ]
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