<script lang="js">
  import { onMount, onDestroy } from 'svelte';
  import Topnav from '$lib/components/Topnav.svelte';
  import Timer from '$lib/components/Timer.svelte';
  import Controlbar from '$lib/components/Controlbar.svelte';
  import '../app.css';
  import { colorMode } from '@sveltestrap/sveltestrap';
  import { browser } from '$app/environment'; // Import the browser variable
  import { initializeSocket } from '$lib/stores/apiDataStore.js';

  // Ensure the theme is applied on initial load and initialize WebSocket connection
  onMount(() => {
    if (browser) {
      const theme = localStorage.getItem('theme') || 'auto';
      colorMode.set(theme); // Set the initial theme for Sveltestrap
    }

    // Connect WebSocket
    initializeSocket();
  });

  // Watch for changes to colorMode and persist them in localStorage
  $: if (browser) {
    localStorage.setItem('theme', $colorMode);
  }
</script>

<Topnav />
<Timer />

<div class="navbar-top-margin"></div> <!-- Ensure main content is below navbar. -->

<main class="container-fluid d-flex flex-column flex-grow-1">
  <slot />
</main>

<div class="navbar-bottom-margin">	</div>
<Controlbar />