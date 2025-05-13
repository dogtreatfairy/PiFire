<script>
	import { controlData, setMode } from '$lib/stores/socketioStore';
	$: currentMode = $controlData?.status_data?.mode  || 'Unknown';
</script>

<!-- Prime Button Group -- Visible: Stop, Manual -->
<div class="btn-group dropup shadow" role="group" aria-label="Prime Options">
	<button 
		type="button" 
		class="btn dropdown-toggle nav-btn-height {currentMode === 'Prime' ? 'btn-info' : 'btn-outline-secondary'}"
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