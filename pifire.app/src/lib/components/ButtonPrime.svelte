<script>
	import { statusStore, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $statusStore?.mode || 'Unknown'; // No need for `data.` prefix
</script>

<!-- Prime Button Group -- Visible: Stop, Manual -->
<div class="btn-group dropup shadow" role="group" aria-label="Prime Options">
	<button 
		type="button" 
		class="btn btn-outline-secondary border border-secondary dropdown-toggle me-2 nav-btn-height"
		id="prime_btn" 
		data-bs-toggle="dropdown" 
		aria-expanded="false"
		aria-label="Prime Options"
	>
		<i class="fas fa-angle-double-right"></i>
	</button>
	<div class="dropdown-menu">
		<!-- Dropdown menu links -->
		<button 
			class="dropdown-item" 
			type="button" 
			on:click={() => setMode('Prime', 10, 'Stop')}
		>
			Prime 10g
		</button>
		<button 
			class="dropdown-item" 
			type="button" 
			on:click={() => setMode('Prime', 25, 'Stop')}
		>
			Prime 25g
		</button>
		<button 
			class="dropdown-item" 
			type="button" 
			on:click={() => setMode('Prime', 50, 'Stop')}
		>
			Prime 50g
		</button>
		<button 
			class="dropdown-item" 
			type="button" 
			on:click={() => setMode('Prime', 10, 'Startup')}
		>
			Prime 10g & Startup
		</button>
		<button 
			class="dropdown-item" 
			type="button" 
			on:click={() => setMode('Prime', 25, 'Startup')}
		>
			Prime 25g & Startup
		</button>
		<button 
			class="dropdown-item" 
			type="button" 
			on:click={() => setMode('Prime', 50, 'Startup')}
		>
			Prime 50g & Startup
		</button>
	</div>
</div>