<script lang="js">
    import { Modal } from '@sveltestrap/sveltestrap';
    import { modalTimer } from '$lib/stores/modalStore';
    import { onMount } from 'svelte';
	import { timerLaunch } from '$lib/timer'; // Import the timer function

    let hours = '';
    let minutes = '';
    let error = '';

    // Function to validate hours input
    function validateHours() {
        if (hours.length === 2) {
            if (parseInt(hours) < 0 || parseInt(hours) > 23) {
                error = 'ERROR: Hours Out of Range [0 - 23]';
                hours = ''; // Clear the hours input
                document.getElementById('hoursInput').focus(); // Re-focus on hours input
            } else {
                error = ''; // Clear error
                document.getElementById('minutesInput').focus(); // Move focus to minutes input
            }
        }
    }

    // Function to validate minutes input
    function validateMinutes() {
        if (minutes.length === 2) {
            if (parseInt(minutes) < 0 || parseInt(minutes) > 59) {
                error = 'ERROR: Minutes Out of Range [0 - 59]';
                minutes = ''; // Clear the minutes input
                document.getElementById('minutesInput').focus(); // Re-focus on minutes input
            } else {
                error = ''; // Clear error
                document.getElementById('setTimerButton').focus(); // Move focus to the "Set Timer" button
            }
        }
    }

    // Automatically focus on the hours input and clear inputs when the modal opens
    onMount(() => {
        const unsubscribe = modalTimer.subscribe((isOpen) => {
            if (isOpen) {
                setTimeout(() => {
                    hours = ''; // Clear hours input
                    minutes = ''; // Clear minutes input
                    error = ''; // Clear any existing error
                    document.getElementById('hoursInput').focus(); // Focus on hours input
                }, 0);
            }
        });
        return unsubscribe;
    });
</script>

<div>
    <Modal body header="Set Timer" isOpen={$modalTimer} toggle={() => modalTimer.set(false)}>
        <div class="modal-body text-center">
            <div class="d-flex justify-content-center align-items-center">
                <div class="me-2">
                    <input
                        id="hoursInput"
                        type="text"
                        class="form-control text-center"
                        style="font-size: 2.5rem; width: 100px;"
                        maxlength="2"
                        bind:value={hours}
                        on:input={validateHours}
                    />
                    <label for="hoursInput" class="form-label mt-2">Hours</label>
                </div>
                <span style="font-size: 2.5rem;">:</span>
                <div class="ms-2">
                    <input
                        id="minutesInput"
                        type="text"
                        class="form-control text-center"
                        style="font-size: 2.5rem; width: 100px;"
                        maxlength="2"
                        bind:value={minutes}
                        on:input={validateMinutes}
                    />
                    <label for="minutesInput" class="form-label mt-2">Minutes</label>
                </div>
            </div>
            {#if error}
                <div class="text-danger mt-3">{error}</div>
            {/if}
        </div>
        <div class="modal-footer">
            <button
                type="button"
                class="btn btn-outline-secondary"
                on:click={() => modalTimer.set(false)}
            >
                Cancel
            </button>
			<button
				id="setTimerButton"
				type="button"
				class="btn btn-danger"
				on:click={() => timerLaunch(hours, minutes, modalTimer, (message) => error = message)}
			>
				Start
			</button>
        </div>
    </Modal>
</div>