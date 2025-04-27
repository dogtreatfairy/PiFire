<script>
	import { grillControlData, setMode } from '$lib/stores/apiDataStore.js';
</script>

<!-- Start Button -->
<button 
	type="button" 
	class="btn btn-outline-success border border-secondary"
	id="start_btn" 
	on:click={() => setMode('Startup')}
	aria-label="Start Grill"
>
	<i class="fas fa-play"></i>
</button>