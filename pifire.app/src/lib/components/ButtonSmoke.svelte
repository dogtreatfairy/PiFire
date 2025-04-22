<script>
	import { grillControlData, setMode } from '$lib/stores/apiDataStore.js';

	$: currentMode = $grillControlData?.current_mode || 'Unknown';
</script>

<!-- Smoke Button -->
<button 
	type="button" 
	class="btn btn-outline-primary border border-primary nav-btn-height"
	id="smoke_btn" 
	on:click={() => setMode('Smoke')}
	aria-label="Smoke Mode"
>
	<i class="fas fa-smog"></i>
</button>