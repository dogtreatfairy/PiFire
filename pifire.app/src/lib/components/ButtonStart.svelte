<script>
	import { grillControlData, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $grillControlData?.current_mode || 'Unknown';
</script>

<!-- Start Button -->
<button 
	type="button" 
	class="btn btn-outline-success border border-success nav-btn-height"
	id="start_btn" 
	on:click={() => setMode('Start')}
	aria-label="Start Grill"
>
	<i class="fas fa-play"></i>
</button>