<script>
	import { controlData, setMode } from '$lib/stores/socketioStore';
	import { colorMode } from '@sveltestrap/sveltestrap';
	$: currentMode = $controlData?.status_data?.mode  || 'Unknown';
</script>

<!-- Stop Button -->
<button 
	type="button" 
	class="btn nav-btn-height {$colorMode === 'dark' ? 'btn-outline-danger border-secondary' : 'btn-danger'}"
	id="stop_btn" 
	on:click={() => setMode('Stop')}
	aria-label="Stop Grill"
>
	<i class="fas fa-stop"></i>
</button>