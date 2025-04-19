<script>
	import { statusStore, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $statusStore?.mode || 'Unknown'; // No need for `data.` prefix
</script>

<!-- Hold Mode Button -- Visible: Hold, Smoke, Recipe, Startup, Manual, Reignite -->
<button 
class="btn btn-outline-success border-secondary nav-btn-square me-2"
on:click={() => setMode('Hold')} 
aria-label="Hold Mode">
<i class="fas fa-crosshairs"></i>
</button>