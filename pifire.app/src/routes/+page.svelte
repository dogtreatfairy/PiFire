<script>
    // Import the dndzone action
    import { dndzone } from 'svelte-dnd-action';
    import { flip } from 'svelte/animate';
    import { derived } from 'svelte/store';
    import { Spinner } from '@sveltestrap/sveltestrap';
    // *** UPDATED: Import from the consolidated apiDataStore ***
    import {
        settingsData,
        uiSettings, // Get the uiSettings store
        saveCardPositions // Get the function to save positions
    } from '$lib/stores/apiDataStore.js'; // Adjust path if needed
    // Removed import from uiStore.js
    import ProbeCard from '$lib/components/ProbeCard.svelte';
    import InfoCard from '$lib/components/InfoCard.svelte';

    console.log("Component Script Initializing (using apiDataStore)...");

    let items = []; // Holds the final sorted items, managed by dndzone
    let rawItems = []; // Temporary holder for unsorted items
    let isInitialized = false;

    // --- Derived Store for Card Positions ---
    // Reads the 'cardPositions' property from the uiSettings store (now in apiDataStore)
    const serverCardPositionsStore = derived(uiSettings, $settings => {
        console.log("Derived store: uiSettings updated:", $settings);
        return $settings?.cardPositions || null;
    });

    // --- Build Raw Items when settingsData is available ---
    $: probeDataReady = !!$settingsData?.probe_settings?.probe_map?.probe_info;
    $: console.log("Reactive: $settingsData changed, probeDataReady:", probeDataReady);
    $: if (probeDataReady) {
        console.log("Reactive: Probe data is ready, building rawItems...");
        const probeInfo = $settingsData.probe_settings.probe_map.probe_info;
        const probes = probeInfo.map(probe => ({
            id: `probe-${probe.port}`,
            name: probe.name,
            type: 'probe',
            probeType: probe.type,
            value: probe.profile,
            label: probe.label,
            enabled: probe.enabled,
            device: probe.device
        }));
        const infoCard = { id: 'info-card', type: 'info' };
        rawItems = [...probes, infoCard];
        console.log("Reactive: Raw items built:", rawItems.map(i => i.id));
    } else {
        if (rawItems.length > 0 || !isInitialized) {
             console.log("Reactive: Probe data is NOT ready or removed.");
        }
        rawItems = [];
        items = [];
        if (isInitialized) {
            isInitialized = false;
            console.log("Reactive: Resetting initialization because probe data removed.");
        }
    }

    // --- Check if UI Settings are loaded ---
    $: uiSettingsValue = $uiSettings; // Keep for debugging
    $: console.log("Reactive: $uiSettings changed, Value:", uiSettingsValue);

    // --- Initialize Items when Probe Data is ready ---
    // (No longer waits for uiSettings to be non-null)
    $: {
        console.log(`Reactive Check: probeDataReady=${probeDataReady}, isInitialized=${isInitialized}`);
        if (probeDataReady && !isInitialized) {
            console.log(">>> Probe data ready! Calling initializeItems()...");
            initializeItems();
        } else if (!isInitialized) {
             console.log(">>> Conditions NOT met for initialization (waiting for probe data).");
        }
    }

    // --- Initialize and Sort Items ---
    function initializeItems() {
        console.log("Function: initializeItems() called.");
        // Get the latest positions map from the derived store
        const currentPositions = $serverCardPositionsStore;
        console.log("Function: initializeItems() - Current Positions from store:", currentPositions);
        console.log("Function: initializeItems() - Current rawItems:", rawItems);

        if (!rawItems || rawItems.length === 0) {
            console.warn("Function: initializeItems() - Initialization skipped: rawItems is empty.");
            return;
        }

        let initialItems = [];
        if (currentPositions && typeof currentPositions === 'object' && Object.keys(currentPositions).length > 0) {
            console.log("Function: initializeItems() - Sorting by SERVER positions map.");
            const sortableItems = rawItems.map(item => ({
                ...item,
                position: currentPositions[item.id] !== undefined ? currentPositions[item.id] : Infinity
            }));
            sortableItems.sort((a, b) => a.position - b.position);
            initialItems = sortableItems.map(({ position, ...rest }) => rest);
            const itemsNotInMap = sortableItems.filter(item => item.position === Infinity);
            if (itemsNotInMap.length > 0) {
                console.warn("Items not found in saved positions map (will be added to end):", itemsNotInMap.map(i => i.id));
            }
        } else {
            console.log("Function: initializeItems() - Sorting by DEFAULT order (rawItems).");
            initialItems = [...rawItems];
        }
        console.log("Function: initializeItems() - Initial sorted 'items' for dndzone:", initialItems.map(i => i.id));

        items = initialItems; // Update the array bound to dndzone

        if (items.length > 0) {
            isInitialized = true;
            console.log("Function: initializeItems() - Initialization COMPLETE. Setting isInitialized=true.");
        } else {
             console.warn("Function: initializeItems() - Initialization finished, but no items to display. isInitialized remains false.");
        }
    }

    // --- Options for dndzone ---
    const flipDurationMs = 300;

    // --- Event Handlers for dndzone ---

    function handleDndConsider(e) {
        // Update the local 'items' state for smooth animation during drag-over
        items = e.detail.items;
    }

    function handleDndFinalize(e) {
        // Final arrangement of items from the event detail
        items = e.detail.items;
        console.log("DND Finalize - Final items order:", items.map(i => i.id));

        // Create the position map { 'id': position }
        const newPositions = {};
        items.forEach((item, index) => {
            newPositions[item.id] = index + 1; // 1-based index
        });

        console.log("Saving new positions map via apiDataStore:", newPositions);
        // *** UPDATED: Call the function from the consolidated store ***
        saveCardPositions(newPositions)
            .then(() => console.log("saveCardPositions call successful (acknowledged by store)."))
            .catch(error => console.error("saveCardPositions call failed:", error));
    }

</script>

{#if isInitialized}
    <div class="min-h-screen from-slate-50 to-slate-100 p-8">
        <div class="max-w-2x mt-4">
            <div
                class="grid grid-cols-3 gap-6"
                use:dndzone={{
                    items: items,
                    flipDurationMs: flipDurationMs
                }}
                on:consider={handleDndConsider}
                on:finalize={handleDndFinalize}
            >
                {#each items as item (item.id)}
                    <div
                        class="relative aspect-square rounded-xl bg-white/50 p-1 backdrop-blur-sm transition-all duration-300 hover:bg-white/60"
                        animate:flip={{ duration: flipDurationMs }}
                    >
                        <div class="h-full w-full cursor-move">
                            {#if item.type === 'probe'}
                                <ProbeCard name={item.name} type={item.probeType} units="F" />
                            {:else if item.type === 'info'}
                                <InfoCard />
                            {/if}
                        </div>
                    </div>
                {/each}
            </div>
        </div>
    </div>
{:else}
    <div class="flex flex-col justify-center items-center min-h-screen text-center p-4">
        <Spinner color="primary" />
        <p class="text-xl text-gray-500 mt-4">Loading cards...</p>
        <div class="mt-4 text-sm text-gray-400">
             <p>Debug Status:</p>
             <p>Probe Data Ready: {probeDataReady}</p>
             <p>UI Settings Value: {JSON.stringify(uiSettingsValue)}</p>
             <p>Is Initialized: {isInitialized}</p>
        </div>
    </div>
{/if}

<style>
/* Styles remain unchanged */
.grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1.5rem;
    width: 100%;
    margin: 0 auto;
    justify-content: center;
}

:global(.svelte-dnd-action-dragged-element) {
    transform: scale(1.05);
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.2);
    opacity: 1 !important;
    z-index: 1000;
    cursor: grabbing !important;
}

:global(.svelte-dnd-action-dragged-element-placeholder) {
    /* opacity: 0.5; */
    /* border: 2px dashed #ccc; */
}

@media (max-width: 576px) { .grid { grid-template-columns: 1fr; } }
@media (min-width: 577px) and (max-width: 992px) { .grid { grid-template-columns: repeat(2, 1fr); } }
@media (min-width: 993px) and (max-width: 1199px) { .grid { grid-template-columns: repeat(3, 1fr); max-width: 95vw; } }
@media (min-width: 1200px) { .grid { grid-template-columns: repeat(4, minmax(0, 1fr)); max-width: 95vw; } }
</style>
