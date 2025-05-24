<script>
    import { controlData, postData } from '$lib/stores/socketioStore';
    import { onDestroy } from 'svelte';

    // Backend auger state
    $: augerOn = $controlData?.outpins?.auger || false;

    // Local button state
    let localAugerOn = augerOn;
    let commandPending = false; // Tracks if a command is in progress
    let revertTimeout = null;   // Timeout ID for reverting state

    // Function to sync local state with backend
    function syncLocalState() {
        if (!commandPending) {
            localAugerOn = augerOn;
        }
    }

    // Call syncLocalState when augerOn changes
    $: augerOn, syncLocalState();

    // Function to check if we can clear the pending command
    function checkCommandSuccess() {
        if (commandPending && augerOn === localAugerOn) {
            clearTimeout(revertTimeout);
            commandPending = false;
        }
    }

    // Call checkCommandSuccess when augerOn changes
    $: augerOn, checkCommandSuccess();

    // Toggle auger function
    async function toggleAuger() {
        localAugerOn = !localAugerOn; // Show commanded state immediately
        commandPending = true;            // Mark command as pending

        try {
            // Send toggle command to backend
            await postData('manual', { action: 'auger', value: 'toggle' });

            // Check if command succeeded
            const currentBackendState = $controlData?.outpins?.auger || false;
            if (currentBackendState !== localAugerOn) {
                // Set timeout to revert if states don’t match
                revertTimeout = setTimeout(() => {
                    const latestBackendState = $controlData?.outpins?.auger || false;
                    localAugerOn = latestBackendState;
                    commandPending = false;
                }, 5000);
            } else {
                commandPending = false; // Command succeeded, clear flag
            }
        } catch (error) {
            console.error('Failed to toggle auger:', error);
            localAugerOn = augerOn; // Revert on error
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
    class="btn nav-btn-height {localAugerOn ? 'btn-warning' : 'btn-outline-secondary'}"
    aria-label="{localAugerOn ? 'Turn auger off' : 'Turn auger on'}"
    on:click={toggleAuger}
>
    <i class="fas fa-angle-double-right"></i>
</button>