<script>
	import { grillControlData, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $grillControlData?.current_mode || 'Unknown';
</script>

<!-- Finish Button -->
<button 
	type="button" 
	class="btn btn-outline-info border border-info nav-btn-height"
	id="finish_btn" 
	on:click={() => setMode('Finish')}
	aria-label="Finish Mode"
>
	<i class="fas fa-flag-checkered"></i>
</button>