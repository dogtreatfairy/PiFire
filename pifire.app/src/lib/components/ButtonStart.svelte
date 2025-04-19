<script>
	import { statusStore, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $statusStore?.mode || 'Unknown'; // No need for `data.` prefix
</script>
<!-- Startup Button -- Visible: Stop, Prime, Monitor, Manual -->
<button 
	class="btn btn-success nav-btn-square me-2" 
	on:click={() => setMode('Startup')}
	aria-label="Startup Grill">
	<i class="fas fa-play"></i>
</button>