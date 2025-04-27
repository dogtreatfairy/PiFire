<script>
    import { draggable, droppable } from '@thisux/sveltednd';
    import { flip } from 'svelte/animate';
    import { grillControlData, settingsData} from '$lib/stores/apiDataStore.js';
    import ProbeCard from '$lib/components/ProbeCard.svelte';
    import InfoCard from '$lib/components/InfoCard.svelte';

    let items = [];
    let activeDropZone = null;

    // Update items to build all probes under probe_info
    $: items = (() => {
        const probeInfo = $settingsData?.probe_settings?.probe_map?.probe_info || [];

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

        const infoCard = {
            id: 'info-card',
            type: 'info'
        };

        return [...probes, infoCard];
    })();

    function handleDrop(state) {
        const { draggedItem, sourceContainer, targetContainer } = state;
        if (!targetContainer || !draggedItem || sourceContainer === targetContainer) {
            activeDropZone = null;
            return;
        }

        const draggedIndex = items.findIndex(item => item.id === draggedItem.id);
        const targetIndex = parseInt(targetContainer);

        if (draggedIndex === -1 || targetIndex === draggedIndex) {
            activeDropZone = null;
            return;
        }

        const newItems = [...items];
        const [movedItem] = newItems.splice(draggedIndex, 1);
        newItems.splice(targetIndex, 0, movedItem);

        items = newItems;
        activeDropZone = null;
    }

    function handleDragEnter(state) {
        if (state.targetContainer) {
            activeDropZone = state.targetContainer;
        }
    }

    function handleDragLeave() {
        activeDropZone = null;
    }
</script>

<div class="min-h-screen from-slate-50 to-slate-100 p-8">
    <div class="max-w-2x mt-4">
        <div class="grid grid-cols-3 gap-6">
            {#each items as item, index (item.id)}
                <div
                    use:droppable={{
                        container: index.toString(),
                        callbacks: {
                            onDrop: handleDrop,
                            onDragEnter: handleDragEnter,
                            onDragLeave: handleDragLeave
                        }
                    }}
                    class="relative aspect-square rounded-xl bg-white/50 p-1 backdrop-blur-sm
                           transition-all duration-300 hover:bg-white/60
                           {activeDropZone === index.toString() ? 'drop-zone-active' : ''}"
                    animate:flip={{ duration: 300 }}
                >
                    <div
                        use:draggable={{
                            container: index.toString(),
                            dragData: item
                        }}
                        class="h-full w-full cursor-move transition-all duration-300
                               hover:scale-[1.02] hover:shadow-xl active:scale-95 active:brightness-110
                               dragging"
                    >
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

<style>
.grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1.5rem;
    width: 100%;
    margin: 0 auto;
    justify-content: center;
}

.drop-zone-active {
    border: 2px dashed #3b82f6;
    background-color: rgba(59, 130, 246, 0.1);
    transform: scale(0.98);
}

:global(.dragging.dragged) {
    opacity: 1 !important;
    transform: scale(1.05);
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.2);
    z-index: 1000;
    cursor: grabbing;
}

:global(.dragging) {
    border: none !important;
}

@media (max-width: 576px) {
    .grid {
        grid-template-columns: 1fr;
    }
}

@media (min-width: 577px) and (max-width: 992px) {
    .grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

@media (min-width: 993px) and (max-width: 1199px) {
    .grid {
        grid-template-columns: repeat(3, 1fr);
        max-width: 95vw;
    }
}

@media (min-width: 1200px) {
    .grid {
        grid-template-columns: repeat(4, minmax(0, 1fr));
        max-width: 95vw;
    }
}
</style>