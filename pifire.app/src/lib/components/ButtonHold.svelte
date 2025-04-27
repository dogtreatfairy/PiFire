<script>
	import { grillControlData, settingsData, setMode } from '$lib/stores/apiDataStore.js';
	$: currentMode = $grillControlData?.current_mode || 'Unknown';
	$: primarySetPoint = $grillControlData?.probe_info?.PSP || 0;
	$: units = $settingsData?.globals?.units || 'F';
</script>

<!-- Hold Button -->
<button 
	type="button" 
	class="btn border border-secondary nav-btn-height {currentMode === 'Hold' ? 'btn-success' : 'btn-outline-secondary'}"
	id="hold_btn" 
	on:click={() => setMode('Hold')}
	aria-label="Hold Mode"
>
	<i class="fas fa-crosshairs"></i>
	<span class="ms-2 fw-semibold p-1" style="margin-bottom: 2px;" class:d-none={currentMode !== 'Hold'}>{primarySetPoint} &deg{units}</span>
</button>