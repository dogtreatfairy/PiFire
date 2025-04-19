<script>
    import { draggable, droppable } from '@thisux/sveltednd';
    import { flip } from 'svelte/animate';
    import { onMount, onDestroy } from 'svelte';
    import { settingsStore, pfAddress, getSettings, getCurrent, getControl, getHopper } from '$lib/stores/apiDataStore.js';
    import ProbeCard from './ProbeCard.svelte';
    import InfoCard from './InfoCard.svelte';

    // Initialize items with runes (combines probes and InfoCard)
    let items = $state([]);

    // Sanitize pfAddress for use in localStorage key
    function sanitizeKey(address) {
        return address.replace(/[^a-zA-Z0-9-_]/g, '_');
    }

    // Get server-specific storage key
    function getStorageKey() {
        const address = $pfAddress || 'localhost';
        return `itemOrder_${sanitizeKey(address)}`;
    }

    function buildItems(settings) {
        const probeData = settings?.probe_settings?.probe_map?.probe_info
            ?.filter(probe => probe.enabled)
            ?.map((probe, index) => ({
                id: `probe-${index}`,
                name: probe.name,
                type: 'probe',
                probeType: probe.type,
                enabled: probe.enabled
            })) || [];

        // Add InfoCard as an item
        const infoCard = {
            id: 'info-card',
            type: 'info'
        };

        // Load saved order from server-specific local storage
        const savedOrder = localStorage.getItem(getStorageKey());
        if (savedOrder) {
            const order = JSON.parse(savedOrder);
            const orderedItems = order
                .map(id => {
                    if

(id === 'info-card') return infoCard;
                    return probeData.find(probe => probe.id === id);
                })
                .filter(item => item);
            // Append any new probes not in saved order
            return orderedItems.concat(
                probeData.filter(probe => !order.includes(probe.id)),
                !order.includes('info-card') ? [infoCard] : []
            );
        }
        return [...probeData, infoCard];
    }

    // Initialize and update items
    $effect(() => {
        if ($settingsStore) {
            items = buildItems($settingsStore);
        }
    });

    // Save item order whenever items change
    $effect(() => {
        if (items.length) {
            localStorage.setItem(getStorageKey(), JSON.stringify(items.map(item => item.id)));
        }
    });

    // Update items when pfAddress changes
    $effect(() => {
        if ($settingsStore && $pfAddress) {
            items = buildItems($settingsStore);
        }
    });

    // Periodic updates
    onMount(() => {
        const interval = setInterval(async () => {
            await getSettings();
            await getCurrent();
            await getControl();
			await getHopper();
        }, 1000);

        return () => clearInterval(interval);
    });

    // Handle drag and drop for items
    function handleDrop(state) {
        const { draggedItem, sourceContainer, targetContainer } = state;
        if (!targetContainer || !draggedItem || sourceContainer === targetContainer) return;

        const draggedIndex = items.findIndex(item => item.id === draggedItem.id);
        const targetIndex = parseInt(targetContainer);

        if (draggedIndex === -1 || targetIndex === draggedIndex) return;

        // Reorder items
        const newItems = [...items];
        const [movedItem] = newItems.splice(draggedIndex, 1);
        newItems.splice(targetIndex, 0, movedItem);

        // Update state
        items = newItems;
    }
</script>

<div class="min-h-screen from-slate-50 to-slate-100 p-8">
    <div class="max-w-2x mt-4">
        <div class="grid grid-cols-3 gap-6">
            {#each items as item, index (item.id)}
                <div
                    use:droppable={{ container: index.toString(), callbacks: { onDrop: handleDrop } }}
                    class="relative aspect-square rounded-xl bg-white/50 p-1 backdrop-blur-sm
                           transition-all duration-300 hover:bg-white/60"
                    animate:flip={{ duration: 300 }}
                >
                    <div
                        use:draggable={{
                            container: index.toString(),
                            dragData: item
                        }}
                        class="h-full w-full cursor-move transition-all duration-300 hover:scale-[1.02] hover:shadow-xl active:scale-95 active:brightness-110"
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