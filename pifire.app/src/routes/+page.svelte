<script>
    import { draggable, droppable } from '$lib/index.js';
    import '$lib/styles/dnd.css';

    let isDragging = false;

    let cards = [
        { id: '1', color: 'bg-danger', icon: '🎨', height: '1-3' },
        { id: '2', color: 'bg-primary', icon: '🌊', height: '1-3' },
        { id: '3', color: 'bg-success', icon: '🌿', height: '2-3' },
        { id: '4', color: 'bg-warning', icon: '⭐', height: '1-3' },
        { id: '5', color: 'bg-info', icon: '🔮', height: '2-3' },
        { id: '6', color: 'bg-secondary', icon: '🌸', height: '1-3' }
    ];

    // Initialize grid with 4 cells
    let grid = Array(4).fill().map(() => []);
    
    // Distribute cards to grid cells initially
    cards.forEach((card, index) => {
        const cellIndex = index % grid.length;
        grid[cellIndex].push(card);
    });

    function calculateAvailableHeight(cellItems) {
        // Calculate total height units used (1/3 or 2/3)
        const usedHeight = cellItems.reduce((total, item) => {
            return total + (item.height === '2-3' ? 2 : 1);
        }, 0);
        
        // Return available height units (max 3)
        return 3 - usedHeight;
    }

    function canAddToCellWithHeight(cellItems, newItem) {
        const availableHeight = calculateAvailableHeight(cellItems);
        const requiredHeight = newItem.height === '2-3' ? 2 : 1;
        
        return availableHeight >= requiredHeight;
    }

    function handleDrop(state) {
        const { draggedItem, sourceContainer, targetContainer } = state;
        if (!targetContainer || sourceContainer === targetContainer) return;

        const sourceIndex = parseInt(sourceContainer);
        const targetIndex = parseInt(targetContainer);
        
        // Find the dragged item in the source container
        const sourceCell = grid[sourceIndex];
        const itemIndex = sourceCell.findIndex(item => item.id === draggedItem.id);
        
        if (itemIndex === -1) return;
        
        const item = sourceCell[itemIndex];
        
        // Check if target cell has enough space for this item
        if (canAddToCellWithHeight(grid[targetIndex], item)) {
            // Remove from source cell
            sourceCell.splice(itemIndex, 1);
            
            // Add to target cell
            grid[targetIndex].push(item);
            
            // Update grid to trigger reactivity
            grid = [...grid];
        }
    }

    function handleDragStart() {
        isDragging = true;
    }

    function handleDragEnd() {
        isDragging = false;
    }
</script>

<div class="d-flex flex-column">
    <!-- Centered grid section -->
    <div class="container-fluid p-3 d-flex justify-content-center align-items-center flex-grow-1">
        <div class="grid">
            {#each grid as cellItems, cellIndex (cellIndex)}
                <div class="grid-cell {isDragging ? 'dragging-border' : ''}">
                    <div
                        use:droppable={{ container: cellIndex.toString(), callbacks: { onDrop: handleDrop } }}
                        class="dnd-droppable {isDragging ? 'highlight-drop-zone' : ''}"
                    >
                        {#if cellItems.length === 0}
                            <div class="empty-cell-placeholder"></div>
                        {:else}
                            {#each cellItems as item (item.id)}
                                <!-- svelte-ignore a11y_no_static_element_interactions -->
                                <div
                                    use:draggable={{ container: cellIndex.toString(), dragData: item }}
                                    on:dragstart={handleDragStart}
                                    on:dragend={handleDragEnd}
                                    class="dnd-draggable {item.color} item-height-{item.height}"
                                >
                                    <span class="fs-1">{item.icon}</span>
                                </div>
                            {/each}
                        {/if}
                    </div>
                </div>
            {/each}
        </div>
    </div>
</div>