<script lang="ts">
  import { darkMode, toggleTheme } from '$lib/stores/themeStore';
  export let page;

  // Helper function to determine if a link is active
  const isActive = (path: string): boolean => page.url.pathname === path;
</script>

<nav class="navbar navbar-expand-md py-0 border-bottom border-2 border-secondary { $darkMode ? 'navbar-dark bg-dark' : 'navbar-light bg-light' }">
  <div class="container-fluid">
    <!-- Logo and Brand -->
    <div class="d-flex align-items-center order-md-first">
      <img 
        src="/img/launcher-icon-4x.png" 
        alt="PiFire Logo" 
        height="25" 
        class="me-2" 
      />
      <div class="navbar-brand fs-4">
        <b class="text-danger">Pi</b>Fire
	  </div>
    </div>

	<div class="d-flex align-items-center justify-content-end order-md-last">
		<!-- Hamburger Button for Collapsed Navbar -->
		<button 
		class="btn btn-outline-secondary nav-btn-square d-md-none" 
		type="button"
		data-bs-toggle="collapse" 
		data-bs-target="#navbarNav" 
		aria-controls="navbarNav" 
		aria-expanded="false" 
		aria-label="Toggle navigation"
		>
		<span class="fa-solid fa-bars fa-sm"></span>
		</button>

				<div class="ms-auto">
		  <button 
			class="btn btn-outline-secondary nav-btn-square" 
			type="button" 
			on:click={toggleTheme}
			aria-label="Toggle theme"
		  >
			{#if $darkMode}
			  <i class="fa-solid fa-moon"></i>
			{:else}
			  <i class="fa-solid fa-sun"></i>
			{/if}
		  </button>
		</div>
	</div>

	<!-- Navigation Links -->
    <div class="collapse navbar-collapse" id="navbarNav">
		<ul class="nav d-flex justify-content-center nav-btn-height">
		  {#each [
			{ path: '/', label: 'Dashboard', icon: 'fa-gauge-high' },
			{ path: '/history', label: 'History', icon: 'fa-clock' },
			{ path: '/recipe', label: 'Recipe', icon: 'fa-utensils' },
			{ path: '/settings', label: 'Settings', icon: 'fa-gear' }
		  ] as link}
			<li
			  class="nav-item"
			>
			  <a
				class="nav-link {isActive(link.path) ? ($darkMode ? 'text-warning fw-semibold border-bottom border-2 border-secondary' : 'text-dark fw-semibold bold border-bottom border-2 border-secondary') : ($darkMode ? 'text-secondary' : 'text-secondary')}"
				href={link.path}
				sveltekit:prefetch
				sveltekit:noscroll
			  >
				<i class={`fa-solid ${link.icon} me-1`}></i> {link.label}
			  </a>
			</li>
		  {/each}
		</ul>
	  </div>
  </div>
</nav>