<script>
	import { grillControlData, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $grillControlData?.current_mode || 'Unknown';
</script>

<!-- Stop Button -->
<button 
	type="button" 
	class="btn btn-outline-danger border border-danger nav-btn-height"
	id="stop_btn" 
	on:click={() => setMode('Stop')}
	aria-label="Stop Grill"
>
	<i class="fas fa-stop"></i>
</button>