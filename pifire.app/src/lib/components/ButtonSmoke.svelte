<script>
    import { controlData, setMode, postData, setPMode } from '$lib/stores/socketioStore';
    import { onDestroy } from 'svelte';

    $: currentMode = $controlData?.mode || 'Unknown';
    $: currentDisplayPMode = $controlData?.p_mode || 0;

    let localPMode = currentDisplayPMode;
    let targetPMode = null;
    let pModeRevertTimeout = null;

    async function activateSmokeMode() {
        try {
            await setMode('Smoke');
        } catch (error) {
            console.error('Failed to activate Smoke mode:', error.message || error);
        }
    }

    async function setNewPMode(newPModeValue) {
        if (pModeRevertTimeout) {
            clearTimeout(pModeRevertTimeout);
        }
        targetPMode = newPModeValue;
        localPMode = targetPMode;
        try {
            await setPMode(newPModeValue);
            pModeRevertTimeout = setTimeout(() => {
                if ($controlData?.p_mode !== targetPMode) {
                    localPMode = $controlData?.p_mode || 0;
                }
                targetPMode = null;
            }, 5000);
        } catch (error) {
            console.error(`Error setting P-Mode to P-${newPModeValue}:`, error.message || error);
            localPMode = $controlData?.p_mode || 0;
            targetPMode = null;
        }
    }

    // Sync localPMode with backend when no command is pending
    $: if (targetPMode === null) {
        localPMode = currentDisplayPMode;
    }

    // Clear timeout if backend confirms the change
    $: if (targetPMode !== null && currentDisplayPMode === targetPMode) {
        clearTimeout(pModeRevertTimeout);
        targetPMode = null;
    }

    onDestroy(() => {
        if (pModeRevertTimeout) {
            clearTimeout(pModeRevertTimeout);
        }
    });
</script>

{#if currentMode === 'Smoke'}
    <div class="btn-group dropup shadow" role="group" aria-label="Smoke P-Mode Options">
        <button
            type="button"
            class="btn dropdown-toggle nav-btn-height btn-warning"
            id="smoke_btn_active"
            data-bs-toggle="dropdown"
            aria-expanded="false"
            aria-label="Change P-Mode Setting (Currently P-{localPMode})"
        >
            <i class="fas fa-cloud"></i>
            <span class="badge rounded bg-dark text-warning me-2 ms-1"> P-{localPMode}</span>
        </button>
        <div class="dropdown-menu">
            {#each Array.from({ length: 10 }, (_, i) => i) as pModeNum (pModeNum)}
                <button
                    class="dropdown-item"
                    type="button"
                    on:click={() => setNewPMode(pModeNum)}
                    disabled={pModeNum === localPMode}
                >
                    P-{pModeNum}
                </button>
            {/each}
        </div>
    </div>
{:else}
    <button
        type="button"
        class="btn nav-btn-height btn-outline-secondary shadow" id="smoke_btn_inactive"
        on:click={activateSmokeMode}
        aria-label="Activate Smoke Mode"
    >
        <i class="fas fa-cloud"></i>
    </button>
{/if}