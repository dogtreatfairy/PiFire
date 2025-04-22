<script lang="js">
    import { Modal } from '@sveltestrap/sveltestrap';
    import { modalTimer } from '$lib/stores/modalStore';
    import { grillControlData } from '$lib/stores/apiDataStore';
    import { onMount } from 'svelte';
    import { timerLaunch } from '$lib/timer'; // Import the timer function

    let error = '';

    $: timerInfo = $grillControlData?.timer_info || {};
    $: hours = Math.floor((timerInfo.timer_end_time || 0) / 3600);
    $: minutes = Math.floor(((timerInfo.timer_end_time || 0) % 3600) / 60);

    // Function to handle the Enter key press
    function handleKeyDown(event) {
        if (event.key === 'Enter') {
            timerLaunch(hours, minutes, modalTimer, (message) => (error = message));
        }
    }

    onMount(() => {
        const unsubscribe = grillControlData.subscribe((data) => {
            timerInfo = data?.timer_info || {};
        });

        // Add global keydown listener
        window.addEventListener('keydown', handleKeyDown);

        return () => {
            unsubscribe();
            window.removeEventListener('keydown', handleKeyDown); // Clean up listener
        };
    });
</script>

<Modal body autofocus keyboard centered header="Set Timer" isOpen={$modalTimer} toggle={() => modalTimer.set(false)}>
	<div class="modal-body text-center">
		<div class="d-flex justify-content-center align-items-center">
			<div class="me-2">
				<!-- svelte-ignore a11y_positive_tabindex -->
				<input
					id="hoursInput"
					type="text"
					class="form-control text-center fs-5"
					style="width: 100px;"
					maxlength="2"
					bind:value={hours}
					tabindex="1"
					disabled
				/>
				<label for="hoursInput" class="form-label mt-2">Hours</label>
			</div>
			<span class="fs-5">:</span>
			<div class="ms-2">
				<!-- svelte-ignore a11y_positive_tabindex -->
				<input
					id="minutesInput"
					type="text"
					class="form-control text-center fs-5"
					style="width: 100px;"
					maxlength="2"
					bind:value={minutes}
					tabindex="2"
					disabled
				/>
				<label for="minutesInput" class="form-label mt-2">Minutes</label>
			</div>
		</div>
		{#if error}
			<div class="text-danger mt-3">{error}</div>
		{/if}
	</div>
	<div class="modal-footer">
		<!-- svelte-ignore a11y_positive_tabindex -->
		<button
			type="button"
			class="btn btn-outline-secondary"
			on:click={() => modalTimer.set(false)}
			tabindex="4"
		>
			Cancel
		</button>
		<!-- svelte-ignore a11y_positive_tabindex -->
		<button
			id="setTimerButton"
			type="button"
			class="btn btn-danger"
			on:click={() => timerLaunch(hours, minutes, modalTimer, (message) => (error = message))}
			tabindex="3"
		>
			Start
		</button>
	</div>
</Modal>