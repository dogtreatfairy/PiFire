<script>
    import { controlData, postData } from '$lib/stores/socketioStore';
    $: fanOn = $controlData?.status?.outpins?.fan || false;

    async function toggleFan() {
        try {
			await postData('manual', { action: 'fan', value: 'toggle'});
		} catch (error) {
			console.error('Failed to toggle fan:', error);
		}
	}
</script>

<button
    type="button"
    class="btn nav-btn-height {fanOn ? 'btn-warning' : 'btn-outline-secondary'}"
    aria-label="{fanOn ? 'Turn fan off' : 'Turn fan on'}"
    on:click={toggleFan}
>
    <i class="fas fa-fan"></i>
</button>