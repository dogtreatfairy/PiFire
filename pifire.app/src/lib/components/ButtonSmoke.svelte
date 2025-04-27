<script>
	import { grillControlData, setMode } from '$lib/stores/apiDataStore.js';
	$: currentMode = $grillControlData?.current_mode || 'Unknown';
</script>

<!-- Smoke Button -->
<button 
	type="button" 
	class="btn border border-secondary nav-btn-height {currentMode === 'Smoke' ? 'btn-warning' : 'btn-outline-secondary'} "
	id="smoke_btn" 
	on:click={() => setMode('Smoke')}
	aria-label="Smoke Mode"
>
	<i class="fas fa-cloud"></i>
</button>