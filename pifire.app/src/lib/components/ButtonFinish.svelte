<script>
	import { grillControlData, setMode } from '$lib/stores/apiDataStore.js';
	import { colorMode } from '@sveltestrap/sveltestrap';
	let hovered = false;
</script>

<!-- Finish Button -->
<!-- svelte-ignore a11y_mouse_events_have_key_events -->
<button 
	type="button" 
	class="btn nav-btn-height { $colorMode === 'dark' ? 'btn-outline-danger' : 'btn-danger' }"
	id="finish_btn" 
	on:click={() => setMode('Finish')}
	on:mouseover={() => hovered = true}
	on:mouseout={() => hovered = false}
	aria-label="Finish Mode"
>
	<i class="fas fa-flag-checkered"></i>
</button>