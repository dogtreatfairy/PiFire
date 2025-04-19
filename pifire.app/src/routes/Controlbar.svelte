<script>
    import { onMount } from 'svelte';
    import { pfAddress, statusStore, getStatus } from '$lib/stores/apiDataStore';
    import { get } from 'svelte/store';
	import { colorMode } from '@sveltestrap/sveltestrap';

    // Reactive statement to get the current mode from the status store
    $: currentMode = $statusStore?.mode || 'Unknown'; // No need for `data.` prefix

    // Generic function to fetch data from the API
    export async function setMode(mode) {
        const postdata = {
            updated: true,
            mode: mode,
        };

        try {
            const address = get(pfAddress);
            const response = await fetch(`${address}/api/control`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(postdata),
            });

            if (!response.ok) {
                throw new Error(`Failed to set mode to: ${mode}. HTTP status: ${response.status}`);
            }

            const data = await response.json();
            console.log(`API Post Call: Mode set to ${data.control}`);
        } catch (error) {
            console.error(`Error setting mode to ${mode}:`, error.message);
        }
    }

    onMount(() => {
        const interval = setInterval(async () => {
            await getStatus(); // Fetch status and update the store
        }, 1000);

        return () => clearInterval(interval); // Cleanup on destroy
    });
</script>

<footer class="navbar fixed-bottom border-top text-center border-2 border-secondary { $colorMode === 'dark' ? 'bg-dark' : 'bg-light' }">
    <div class="container d-flex justify-content-center">
        <button 
			class="btn btn-outline-success nav-btn-square me-2" 
			class:d-none={currentMode !== 'Stop'}
			on:click={() => setMode('Manual')}
			aria-label="Manual Mode">
            <i class="fa-solid fa-play"></i>
        </button>
		<button 
			class="btn btn-outline-danger nav-btn-square me-2"
			class:d-none={currentMode === 'Stop' || currentMode === 'Finish'}
			on:click={() => setMode('Stop')} 
			aria-label="Stop Mode">
            <i class="fa-solid fa-stop"></i>
        </button>
    </div>
</footer>