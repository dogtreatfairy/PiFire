import { writable } from 'svelte/store';
import { browser } from '$app/environment';

// Initialize from localStorage if in browser, otherwise default to dark mode
const storedTheme = browser ? localStorage.getItem('theme') : null;
const initialValue = storedTheme !== null ? storedTheme === 'dark' : true; // Default to dark mode

// Create the theme store
export const darkMode = writable(initialValue);

// Subscribe to changes and update localStorage, document, and body class
if (browser) {
  darkMode.subscribe(value => {
    // Save to localStorage
    localStorage.setItem('theme', value ? 'dark' : 'light');
    
    // Apply theme changes using Bootstrap 5.3's built-in theming system
    document.documentElement.setAttribute('data-bs-theme', value ? 'dark' : 'light');
    
    // Update body class for background
    document.body.classList.remove('bg-black', 'bg-light');
    document.body.classList.add(value ? 'bg-black' : 'bg-light');
  });
}

// Function to apply the theme
export function applyTheme(isDark) {
  if (!browser) return;
  document.documentElement.setAttribute('data-bs-theme', isDark ? 'dark' : 'light');
  document.body.classList.remove('bg-black', 'bg-light');
  document.body.classList.add(isDark ? 'bg-black' : 'bg-light');
}

// Function to toggle theme
export function toggleTheme() {
  darkMode.update(value => !value);
}