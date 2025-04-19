<script>
	import { statusStore, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $statusStore?.mode || 'Unknown'; // No need for `data.` prefix
</script>

<!-- Smoke Mode Button -- Visible: Hold, Smoke, Recipe, Startup, Manual, Reignite -->
<button 
	class="btn btn-outline-warning border-secondary nav-btn-square me-2"
	on:click={() => setMode('Smoke')} 
	aria-label="Smoke Mode">
	<i class="fas fa-cloud"></i>
</button>