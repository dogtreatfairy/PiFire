<script>
    import { controlData, setMode } from '$lib/stores/socketioStore';
    import { colorMode } from '@sveltestrap/sveltestrap';
    $: currentMode = $controlData?.mode || 'Unknown'; 

    async function stopGrillWithRetry() {
        await setMode('Stop');
        setTimeout(() => {
            if ($controlData?.mode !== 'Stop') {
                setMode('Stop');
            }
        }, 1000); // Retry after 1 second if still not in Stop mode
    }
</script>

<button 
    type="button" 
    class="btn nav-btn-height {$colorMode === 'dark' ? 'btn-outline-danger border-secondary' : 'btn-danger'}"
    id="stop_btn" 
    on:click={stopGrillWithRetry}
    aria-label="Stop Grill"
>
    <i class="fas fa-stop"></i>
</button>