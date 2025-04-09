<script>
    import { draggable, droppable } from '$lib/index.js';
    import '$lib/styles/dnd.css'; // Import the external CSS file

    let isDragging = false;

    let cards = [
        { id: '1', color: 'bg-danger', icon: '🎨' },
        { id: '2', color: 'bg-primary', icon: '🌊' },
        { id: '3', color: 'bg-success', icon: '🌿' },
        { id: '4', color: 'bg-warning', icon: '⭐' },
        { id: '5', color: 'bg-info', icon: '🔮' },
        { id: '6', color: 'bg-secondary', icon: '🌸' }
    ];

    // Create an 8-slot grid (4x2), filling empty slots with null
    let grid = [...cards, ...Array(8 - cards.length).fill(null)];

    function handleDrop(state) {
        const { draggedItem, sourceContainer, targetContainer } = state;
        if (!targetContainer || sourceContainer === targetContainer) return;

        const sourceIndex = parseInt(sourceContainer);
        const targetIndex = parseInt(targetContainer);

        const temp = grid[targetIndex];
        grid[targetIndex] = grid[sourceIndex];
        grid[sourceIndex] = temp;
        grid = grid; // Trigger reactivity
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
    <div class="container-fluid p-1 d-flex justify-content-center align-items-center flex-grow-1 navbar-top-margin">
        <div class="grid">
            {#each grid as slot, index (index)}
                <div class="grid-cell {isDragging ? 'dragging-border' : ''}">
                    <div
                        use:droppable={{ container: index.toString(), callbacks: { onDrop: handleDrop } }}
                        class="dnd-droppable"
                    >
                        {#if slot}
                            <!-- svelte-ignore a11y_no_static_element_interactions -->
                            <div
                                use:draggable={{ container: index.toString(), dragData: slot }}
                                on:dragstart={handleDragStart}
                                on:dragend={handleDragEnd}
                                class="dnd-draggable {slot.color}"
                            >
                                <span class="fs-1">{slot.icon}</span>
                            </div>
                        {/if}
                    </div>
                </div>
            {/each}
        </div>
    </div>
</div>