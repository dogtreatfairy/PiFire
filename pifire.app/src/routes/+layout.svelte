<script lang="js">
  import { onMount } from 'svelte';
  import Topnav from '$lib/components/Topnav.svelte';
  import Timer from '$lib/components/Timer.svelte';
  import Controlbar from '$lib/components/Controlbar.svelte';
  import '../app.css';
  import { colorMode } from '@sveltestrap/sveltestrap';
  import { browser } from '$app/environment'; // Import the browser variable

  // Ensure the theme is applied on initial load
  onMount(() => {
    if (browser) {
      const theme = localStorage.getItem('theme') || 'auto';
      colorMode.set(theme); // Set the initial theme for Sveltestrap
    }
  });

  // Watch for changes to colorMode and persist them in localStorage
  $: if (browser) {
    localStorage.setItem('theme', $colorMode);
  }
</script>

<Topnav />
<Timer />
<Controlbar />

<main class="container-fluid d-flex flex-column flex-grow-1">
  <slot />
</main>