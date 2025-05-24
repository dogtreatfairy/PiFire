<script>
    import { controlData, postData } from '$lib/stores/socketioStore';
    import { onDestroy } from 'svelte';

    // Backend fan state
    $: fanOn = $controlData?.outpins?.fan || false;

    // Local button state
    let localFanOn = fanOn;
    let commandPending = false; // Tracks if a command is in progress
    let revertTimeout = null;   // Timeout ID for reverting state

    // Function to sync local state with backend
    function syncLocalState() {
        if (!commandPending) {
            localFanOn = fanOn;
        }
    }

    // Call syncLocalState when fanOn changes
    $: fanOn, syncLocalState();

    // Function to check if we can clear the pending command
    function checkCommandSuccess() {
        if (commandPending && fanOn === localFanOn) {
            clearTimeout(revertTimeout);
            commandPending = false;
        }
    }

    // Call checkCommandSuccess when fanOn changes
    $: fanOn, checkCommandSuccess();

    // Toggle fan function
    async function toggleFan() {
        localFanOn = !localFanOn; // Show commanded state immediately
        commandPending = true;            // Mark command as pending

        try {
            // Send toggle command to backend
            await postData('manual', { action: 'fan', value: 'toggle' });

            // Check if command succeeded
            const currentBackendState = $controlData?.outpins?.fan || false;
            if (currentBackendState !== localFanOn) {
                // Set timeout to revert if states don’t match
                revertTimeout = setTimeout(() => {
                    const latestBackendState = $controlData?.outpins?.fan || false;
                    localFanOn = latestBackendState;
                    commandPending = false;
                }, 5000);
            } else {
                commandPending = false; // Command succeeded, clear flag
            }
        } catch (error) {
            console.error('Failed to toggle fan:', error);
            localFanOn = fanOn; // Revert on error
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
    class="btn nav-btn-height {localFanOn ? 'btn-warning' : 'btn-outline-secondary'}"
    aria-label="{localFanOn ? 'Turn fan off' : 'Turn fan on'}"
    on:click={toggleFan}
>
    <i class="fas fa-fan"></i>
</button>