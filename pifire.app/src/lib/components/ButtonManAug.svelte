<script>
    import { controlData, postData } from '$lib/stores/socketioStore';
    $: augerOn = $controlData?.status?.outpins?.auger || false;

    async function toggleAuger() {
        try {
            await postData('manual', { action: 'auger', value: 'toggle' });
		} catch (error) {
            console.error('Failed to toggle auger:', error);
        }
    }
</script>

<button
    type="button"
    class="btn nav-btn-height {augerOn ? 'btn-warning' : 'btn-outline-secondary'}"
    aria-label="{augerOn ? 'Turn auger off' : 'Turn auger on'}"
    on:click={toggleAuger}
>
    <i class="fas fa-angle-double-right"></i>
</button>
