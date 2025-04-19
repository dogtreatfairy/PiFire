<script>
	import { statusStore, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $statusStore?.mode || 'Unknown'; // No need for `data.` prefix
</script>

<!-- Stop Mode Button -- Visible: Hold, Smoke, Recipe, Finish, Error, Startup, Reignite, Manual, Monitor -->
<button 
	class="btn btn-danger nav-btn-square me-2"
	on:click={() => setMode('Stop')} 
	aria-label="Stop Mode">
	<i class="fas fa-stop"></i>
</button>