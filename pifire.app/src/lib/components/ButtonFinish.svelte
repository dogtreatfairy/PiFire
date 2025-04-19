<script>
	import { statusStore, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $statusStore?.mode || 'Unknown'; // No need for `data.` prefix
</script>

<!-- Finish Mode Button -- Visible: Hold, Smoke, Recipe -->
<button 
	class="btn btn-danger nav-btn-square me-2"
	on:click={() => setMode('Finish')} 
	aria-label="Stop Mode">
	<i class="fas fa-stop"></i>
</button>