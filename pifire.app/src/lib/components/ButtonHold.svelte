<script>
	import { grillControlData, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $grillControlData?.current_mode || 'Unknown';
</script>

<!-- Hold Button -->
<button 
	type="button" 
	class="btn btn-outline-warning border border-warning nav-btn-height"
	id="hold_btn" 
	on:click={() => setMode('Hold')}
	aria-label="Hold Mode"
>
	<i class="fas fa-pause"></i>
</button>