<script>
    import { draggable, droppable } from '@thisux/sveltednd';
    import { flip } from 'svelte/animate';
    import { onMount, onDestroy } from 'svelte';
    import { settingsStore, pfAddress, getSettings, getCurrent, getControl, getHopper } from '$lib/stores/apiDataStore.js';
    import ProbeCard from '$lib/components/ProbeCard.svelte';
    import InfoCard from '$lib/components/InfoCard.svelte';

    // Initialize items with runes
    let items = $state([]);
    // Track which drop zone is active (hovered)
    let activeDropZone = $state(null);
	let interval;
	let interval2;

    // Sanitize pfAddress for use in localStorage key
    function sanitizeKey(address) {
        return address.replace(/[^a-zA-Z0-9-_]/g, '_');
    }

    // Get server-specific storage key
    function getStorageKey(address) {
        return `itemOrder_${sanitizeKey(address || 'localhost')}`;
    }

    // Build items from settings, ensuring stable IDs
    function buildItems(settings, address) {
        if (!settings || !address) return [];

        const probeData = settings?.probe_settings?.probe_map?.probe_info
            ?.filter(probe => probe.enabled)
            ?.map(probe => ({
                id: `${address}-${probe.port}`, // Stable ID: pfAddress-probe.port
                name: probe.name,
                port: probe.port,
                type: 'probe',
                probeType: probe.type,
                enabled: probe.enabled
            })) || [];

        // Add InfoCard with a fixed ID
        const infoCard = {
            id: 'info-card',
            type: 'info'
        };

        // Load saved order from server-specific local storage
        const savedOrder = localStorage.getItem(getStorageKey(address));
        if (savedOrder) {
            const order = JSON.parse(savedOrder);
            const orderedItems = order
                .map(id => {
                    if (id === 'info-card') return infoCard;
                    return probeData.find(probe => probe.id === id);
                })
                .filter(item => item); // Remove undefined items
            // Append any new probes not in saved order
            return [
                ...orderedItems,
                ...probeData.filter(probe => !order.includes(probe.id)),
                ...(order.includes('info-card') ? [] : [infoCard])
            ];
        }

        // Default order: probes followed by info card
        return [...probeData, infoCard];
    }

    // Clear and rebuild items when settings or pfAddress change
    $effect(() => {
        if ($settingsStore && $pfAddress) {
            items = buildItems($settingsStore, $pfAddress);
        } else {
            items = []; // Clear items if no settings or address
        }
    });

    // Save item order whenever items change
    $effect(() => {
        if (items.length && $pfAddress) {
            localStorage.setItem(getStorageKey($pfAddress), JSON.stringify(items.map(item => item.id)));
        }
    });

    // Periodic updates
    onMount(() => {
        const interval = setInterval(async () => {
            await getSettings();
            await getCurrent();
            await getControl();
        }, 1000);

		const interval2 = setInterval(async () => {
			await getHopper();
		}, 10000);

        // Reset activeDropZone when drag ends (drop or cancel)
        const handleDragEnd = () => {
            activeDropZone = null;
        };

        document.addEventListener('dragend', handleDragEnd);

        return () => {
            clearInterval(interval);
            document.removeEventListener('dragend', handleDragEnd);
        };
    });

	// Cleanup on destroy
	onDestroy(() => {
        clearInterval(interval);
        clearInterval(interval2);
    });

    // Handle drag and drop for items
    function handleDrop(state) {
        const { draggedItem, sourceContainer, targetContainer } = state;
        if (!targetContainer || !draggedItem || sourceContainer === targetContainer) {
            activeDropZone = null; // Clear on invalid drop
            return;
        }

        const draggedIndex = items.findIndex(item => item.id === draggedItem.id);
        const targetIndex = parseInt(targetContainer);

        if (draggedIndex === -1 || targetIndex === draggedIndex) {
            activeDropZone = null; // Clear if no valid reorder
            return;
        }

        // Reorder items
        const newItems = [...items];
        const [movedItem] = newItems.splice(draggedIndex, 1);
        newItems.splice(targetIndex, 0, movedItem);

        // Update state
        items = newItems;
        activeDropZone = null; // Clear after successful drop
    }

    // Handle drag enter for drop zone highlighting
    function handleDragEnter(state) {
        if (state.targetContainer) {
            activeDropZone = state.targetContainer;
        }
    }

    // Handle drag leave for drop zone highlighting
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

/* Style for drop zone when active (hovered) */
.drop-zone-active {
    border: 2px dashed #3b82f6; /* Blue dashed border */
    background-color: rgba(59, 130, 246, 0.1); /* Light blue background */
    transform: scale(0.98); /* Slight shrink to emphasize drop zone */
}

/* Style for dragged item */
:global(.dragging.dragged) {
    opacity: 1 !important; /* Ensure full visibility */
    transform: scale(1.05); /* Slightly larger to indicate dragging */
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.2); /* Add shadow for depth */
    z-index: 1000; /* Ensure dragged item is on top */
    cursor: grabbing; /* Grabbing cursor */
}

/* Prevent border on click */
:global(.dragging) {
    border: none !important; /* No border on click */
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