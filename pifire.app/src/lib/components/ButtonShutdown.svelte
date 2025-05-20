<script>
	import { controlData, setMode } from '$lib/stores/socketioStore';
	import { colorMode } from '@sveltestrap/sveltestrap';
	let hovered = false;
</script>

<!-- Finish Button -->
<!-- svelte-ignore a11y_mouse_events_have_key_events -->
<button 
	type="button" 
	class="btn nav-btn-height { $colorMode === 'dark' ? 'btn-outline-danger border-secondary' : 'btn-danger' }"
	id="finish_btn" 
	on:click={() => setMode('Shutdown')}
	on:mouseover={() => hovered = true}
	on:mouseout={() => hovered = false}
	aria-label="Shutdown Mode"
>
	<i class="fas fa-flag-checkered"></i>
</button>

