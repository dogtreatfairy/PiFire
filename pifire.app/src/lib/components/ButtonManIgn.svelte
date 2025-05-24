<script>
    import { controlData, postData } from '$lib/stores/socketioStore';
    import { onDestroy } from 'svelte';

    // Backend igniter state
    $: igniterOn = $controlData?.outpins?.igniter || false;

    // Local button state
    let localIgniterOn = igniterOn;
    let commandPending = false; // Tracks if a command is in progress
    let revertTimeout = null;   // Timeout ID for reverting state

    // Function to sync local state with backend
    function syncLocalState() {
        if (!commandPending) {
            localIgniterOn = igniterOn;
        }
    }

    // Call syncLocalState when igniterOn changes
    $: igniterOn, syncLocalState();

    // Function to check if we can clear the pending command
    function checkCommandSuccess() {
        if (commandPending && igniterOn === localIgniterOn) {
            clearTimeout(revertTimeout);
            commandPending = false;
        }
    }

    // Call checkCommandSuccess when igniterOn changes
    $: igniterOn, checkCommandSuccess();

    // Toggle igniter function
    async function toggleIgniter() {
        localIgniterOn = !localIgniterOn; // Show commanded state immediately
        commandPending = true;            // Mark command as pending

        try {
            // Send toggle command to backend
            await postData('manual', { action: 'igniter', value: 'toggle' });

            // Check if command succeeded
            const currentBackendState = $controlData?.outpins?.igniter || false;
            if (currentBackendState !== localIgniterOn) {
                // Set timeout to revert if states don’t match
                revertTimeout = setTimeout(() => {
                    const latestBackendState = $controlData?.outpins?.igniter || false;
                    localIgniterOn = latestBackendState;
                    commandPending = false;
                }, 5000);
            } else {
                commandPending = false; // Command succeeded, clear flag
            }
        } catch (error) {
            console.error('Failed to toggle igniter:', error);
            localIgniterOn = igniterOn; // Revert on error
            commandPending = false;
        }
    }

    // Cleanup timeout on component destruction
    onDestroy(() => {
        if (revertTimeout) {
            clearTimeout(revertTimeout);
        }
    });
</script>

<button
    type="button"
    class="btn nav-btn-height {localIgniterOn ? 'btn-warning' : 'btn-outline-secondary'}"
    aria-label="{localIgniterOn ? 'Turn igniter off' : 'Turn igniter on'}"
    on:click={toggleIgniter}
>
    <i class="fas fa-fire"></i>
</button>