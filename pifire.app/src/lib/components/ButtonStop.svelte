<script>
	import { grillControlData, setMode } from '$lib/stores/apiDataStore.js';
	$: currentMode = $grillControlData?.status_data?.mode  || 'Unknown';
</script>

<!-- Stop Button -->
<button 
	type="button" 
	class="btn nav-btn-height {currentMode === 'Finish' ? 'btn-danger' : 'btn-outline-danger'}"
	id="stop_btn" 
	on:click={() => setMode('Stop')}
	aria-label="Stop Grill"
>
	<i class="fas fa-stop"></i>
</button>