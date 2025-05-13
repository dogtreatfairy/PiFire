<script>
	import { grillControlData, setMode } from '$lib/stores/apiDataStore.js';
</script>

<!-- Manual Button -->
<button 
	type="button" 
	class="btn btn-outline-secondary nav-btn-height"
	id="manual_btn" 
	on:click={() => setMode('Manual')}
	aria-label="Manual Mode"
>
	<i class="fas fa-tools"></i>
</button>