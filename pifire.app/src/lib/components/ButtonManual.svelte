<script>
	import { statusStore, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $statusStore?.mode || 'Unknown'; // No need for `data.` prefix
</script>

<!-- Manual Mode Button -- Visible: Hold, Smoke, Recipe, Stop, Manual, Error, Reignite-->
<button 
	class="btn btn-outline-secondary nav-btn-square"
	on:click={() => setMode('Manual')} 
	aria-label="Manual Mode">
	<i class="fas fa-glasses"></i>
</button>