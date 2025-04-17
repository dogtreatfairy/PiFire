<script>
    import { draggable, droppable } from '@thisux/sveltednd';
    import { flip } from 'svelte/animate';
    import { onMount, onDestroy } from 'svelte';
    import { settingStore, getSettings, getCurrent, getControl } from '$lib/stores/apiDataStore.js';
    import ProbeCard from './ProbeCard.svelte';

    // Initialize probes with runes
    let probes = $state([]);

    function buildProbeCards(settings) {
        const probeData = settings?.probe_settings?.probe_map?.probe_info?.map((probe, index) => ({
            id: index.toString(),
            name: probe.name,
            type: probe.type,
            enabled: probe.enabled
        })) || [];

        // Load saved order from local storage
        const savedOrder = localStorage.getItem('probeOrder');
        if (savedOrder) {
            const order = JSON.parse(savedOrder);
            return order
                .map(id => probeData.find(probe => probe.id === id))
                .filter(probe => probe)
                .concat(probeData.filter(probe => !order.includes(probe.id)));
        }
        return probeData;
    }

    // Initialize and update probes
    $effect(() => {
        if ($settingStore) {
            probes = buildProbeCards($settingStore);
        }
    });

    // Save probe order whenever probes change
    $effect(() => {
        if (probes.length) {
            localStorage.setItem('probeOrder', JSON.stringify(probes.map(probe => probe.id)));
        }
    });

    // Periodic updates
    onMount(() => {
        const interval = setInterval(async () => {
            await getSettings();
            await getCurrent();
			await getControl();
        }, 1000);

        return () => clearInterval(interval); // Cleanup on destroy
    });

    // Handle drag and drop for probes
    function handleDrop(state) {
        const { draggedItem, sourceContainer, targetContainer } = state;
        if (!targetContainer || !draggedItem || sourceContainer === targetContainer) return;

        const draggedIndex = probes.findIndex(probe => probe.id === draggedItem.id);
        const targetIndex = parseInt(targetContainer);

        if (draggedIndex === -1 || targetIndex === draggedIndex) return;

        // Reorder probes
        const newProbes = [...probes];
        const [movedProbe] = newProbes.splice(draggedIndex, 1);
        newProbes.splice(targetIndex, 0, movedProbe);

        // Update state
        probes = newProbes;
    }
</script>

<div class="min-h-screen from-slate-50 to-slate-100 p-8">
    <div class="max-w-2x mt-4">
        <div class="grid grid-cols-3 gap-6">
            {#each probes as probe, index (probe.id)}
                <div
                    use:droppable={{ container: index.toString(), callbacks: { onDrop: handleDrop } }}
                    class="relative aspect-square rounded-xl bg-white/50 p-1 backdrop-blur-sm
                           transition-all duration-300 hover:bg-white/60"
                    animate:flip={{ duration: 300 }}
                >
                    <div
                        use:draggable={{
                            container: index.toString(),
                            dragData: probe
                        }}
                        class="h-full w-full cursor-move transition-all duration-300 hover:scale-[1.02] hover:shadow-xl active:scale-95 active:brightness-110"
                    >
                        <ProbeCard name={probe.name} type={probe.type} units="F" />
                    </div>
                </div>
            {/each}
        </div>
    </div>
</div>

<style>
.grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1.5rem;
    width: 100%;
    margin: 0 auto; /* Center the grid */
    justify-content: center;
}

/* Small screens (sm) - 1 column */
@media (max-width: 576px) {
    .grid {
        grid-template-columns: 1fr;
    }
}

/* Medium screens (md) - 2 columns */
@media (min-width: 577px) and (max-width: 992px) {
    .grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

/* Large screens (lg) - 3 columns */
@media (min-width: 993px) and (max-width: 1199px) {
    .grid {
        grid-template-columns: repeat(3, 1fr);
        max-width: 95vw; /* Ensure the grid fits within the viewport */
    }
}

/* Extra-large screens (xl) - 4 columns */
@media (min-width: 1200px) {
    .grid {
        grid-template-columns: repeat(4, minmax(0, 1fr)); /* Ensure 4 flexible columns */
        max-width: 95vw; /* Ensure the grid fits within the viewport */
    }
}
</style>