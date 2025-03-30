<script lang="ts">
  import { onMount } from 'svelte';
  import Topnav from './Topnav.svelte';
  import '../app.css';
  import { applyTheme, darkMode } from '$lib/stores/themeStore';
  import { page } from '$app/state';

  // Apply the theme on initial load
  onMount(() => {
    applyTheme($darkMode); // Apply the current theme immediately
  });
</script>

<Topnav {page} />

<main class="container mt-4">
  <slot />
</main>