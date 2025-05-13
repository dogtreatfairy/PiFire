<script>
	import { controlData, setMode } from '$lib/stores/socketioStore';
	$: currentMode = $controlData?.status_data?.mode  || 'Unknown';
</script>

<!-- Start Button -->
<button 
	type="button" 
	class="btn border border-secondary {currentMode === 'Stop' ? 'btn-success' : 'btn-outline-success'}"
	id="start_btn" 
	on:click={() => setMode('Startup')}
	aria-label="Start Grill"
>
	<i class="fas fa-play"></i>
</button>