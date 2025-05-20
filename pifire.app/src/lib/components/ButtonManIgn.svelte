<script>
    import { controlData, postData } from '$lib/stores/socketioStore';
    $: igniterOn = $controlData?.status?.outpins?.igniter || false;

    async function toggleIgniter() {
        try {
			await postData('manual', { action: 'igniter', value: 'toggle'});
		} catch (error) {
			console.error('Failed to toggle igniter:', error);
		}
	}
</script>

<button
    type="button"
    class="btn nav-btn-height {igniterOn ? 'btn-warning' : 'btn-outline-secondary'}"
    aria-label="{igniterOn ? 'Turn igniter off' : 'Turn igniter on'}"
    on:click={toggleIgniter}
>
    <i class="fas fa-fire"></i>
</button>