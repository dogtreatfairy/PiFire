<script lang="js">
    import { get } from 'svelte/store';
    import { Modal } from '@sveltestrap/sveltestrap';
    import { modalTimer, enterSubmit, focusSelect } from '$lib/stores/modalStore'; // Assuming focusSelect is from here
    // Import timer functions and the store from the new timer module
    import { 
        startTimer, // Changed from timerLaunch to match the new timer.js
        timerStore  // The main store for timer status, display, hours, minutes
    } from '$lib/timer'; // Path to your new timer.js (svelte_timer_store_v2)

    let error = '';
    let _hours ='00';      // Local state for hours input, initialized for display
    let _minutes = '00';   // Local state for minutes input, initialized for display
    let _shutdown = false; // Local state for shutdown toggle
    let _keepWarm = false; // Local state for keep warm toggle
    let _initialLoad = true; // Flag to handle initial loading of modal data

    let hoursInputRef;    // Reference to hours input element
    let minutesInputRef;  // Reference to minutes input element

    // When modal is closed, reset _initialLoad for the next time it opens
    $: if (!$modalTimer) {
        _initialLoad = true;
        // error = ''; // Optionally reset error when modal closes
    }
    
    // Initialize modal state when it opens and it's the initial load for this specific opening
    $: if ($modalTimer && _initialLoad) {
        error = ''; // Clear any previous errors
        const currentTimer = get(timerStore); // Get current state from timerStore

        // If timer is running or paused, pre-fill hours and minutes from the store
        // This reflects the *remaining time* of an active timer.
        if (currentTimer.status === 'running' || currentTimer.status === 'paused') {
            _hours = String(currentTimer.hours).padStart(2, '0');
            _minutes = String(currentTimer.minutes).padStart(2, '0');
            // Note: The new timerStore also has isShutdownSet and isKeepWarmSet.
            // Here, we are choosing NOT to pre-fill _shutdown and _keepWarm from the
            // active timer's settings, allowing the user to define settings for a *new* timer
            // or to modify settings if they intend to "restart" with new options.
            // If you wanted to pre-fill these from an active timer, you would use:
            // _shutdown = currentTimer.isShutdownSet;
            // _keepWarm = currentTimer.isKeepWarmSet;
        } else {
            // Default to 00:00 if timer is stopped or expired, or for a new timer.
            _hours = '00'; 
            _minutes = '00';
            // Reset options for a completely new timer if no active one
            // _shutdown = false; 
            // _keepWarm = false;
        }
        
        _initialLoad = false; // Mark as loaded for this opening

        // Auto-focus and select the hours input when modal is ready
        setTimeout(() => {
            if (hoursInputRef && (typeof document === 'undefined' || !document.activeElement || document.activeElement === document.body)) {
                hoursInputRef.focus();
                hoursInputRef.select();
            }
        }, 100); // Delay to ensure modal is rendered and focusable
    }

    // Handle toggle changes to enforce mutual exclusivity for shutdown/keep-warm
    function handleShutdownChange() {
        if (_shutdown) {
            _keepWarm = false; // If shutdown is enabled, disable keep warm
        }
    }

    function handleKeepWarmChange() {
        if (_keepWarm) {
            _shutdown = false; // If keep warm is enabled, disable shutdown
        }
    }

    // Clear input if '0' or '00' when focusing for better UX
    function _handleHoursFocus() {
        if (_hours === '0' || _hours === '00') _hours = '';
    }

    function _handleMinutesFocus() {
        if (_minutes === '0' || _minutes === '00') _minutes = '';
    }

    // Function to validate inputs and launch the timer with selected options
    async function _startTimerAndSetOptions() {
        error = ''; // Clear previous errors
        const hoursNum = parseInt(_hours || 0, 10);
        const minutesNum = parseInt(_minutes || 0, 10);

        // Validate hours
        if (isNaN(hoursNum) || hoursNum < 0 || hoursNum > 99) {
            error = 'Hours must be between 0 and 99.';
            return;
        }
        // Validate minutes
        if (isNaN(minutesNum) || minutesNum < 0 || minutesNum > 59) {
            error = 'Minutes must be between 0 and 59.';
            return;
        }

        // The startTimer function in timer.js now handles the "duration must be positive" check.
        // if ((hoursNum * 3600) + (minutesNum * 60) <= 0) {
        //     error = 'Timer duration must be greater than 0 seconds.';
        //     return;
        // }

        try {
            console.log(`Timer.svelte: Calling startTimer with ${hoursNum}h ${minutesNum}m, Shutdown: ${_shutdown}, KeepWarm: ${_keepWarm}`);
            // Call the startTimer function from the new timer.js, passing hours, minutes, and options
            // Note the change in option keys: `shutdown` and `keepWarm`
            await startTimer(hoursNum, minutesNum, { 
                shutdown: _shutdown, 
                keepWarm: _keepWarm 
            });
            
            // If startTimer itself doesn't throw and postData is successful, close modal.
            // Error display within startTimer (e.g., "Invalid Duration") will update timerStore.display.
            // We rely on the timerStore to reflect any immediate validation errors from startTimer.
            // If a more specific error from startTimer needs to be caught here, startTimer would need to throw.
            const currentErrorInStore = get(timerStore).display;
            if (currentErrorInStore === "Invalid Duration" || currentErrorInStore === "Start Failed") {
                error = currentErrorInStore; // Show error from store in the modal
            } else {
                modalTimer.set(false); // Close modal on success
            }

        } catch (err) {
            // This catch block might not be hit if startTimer handles its own errors by updating the store.
            // It's here as a fallback.
            console.error('Timer.svelte: Error calling startTimer:', err);
            error = err.message || 'Failed to start timer. Please try again.';
        }
    }
</script>

<Modal
    body
    centered
    keyboard
    header="Set Timer"
    isOpen={$modalTimer}
    toggle={() => {
        modalTimer.set(false); 
    }}
>
    <div class="modal-body text-center" on:keypress={enterSubmit(_startTimerAndSetOptions)}>
        <div class="d-flex justify-content-center align-items-center mb-3">
            <div class="me-2">
                <label for="hoursInput" class="form-label">Hours</label>
                <input
                    id="hoursInput"
                    bind:this={hoursInputRef}
                    type="number"
                    inputmode="numeric"
                    pattern="[0-9]*"
                    min="0"
                    max="99"
                    class="form-control text-center fs-1"
                    bind:value={_hours}
                    on:focus={_handleHoursFocus}
                    on:input={() => {
                        const valStr = String(_hours);
                        if (valStr.length >= 2 && minutesInputRef) {
                            _hours = valStr.slice(0, 2); // Ensure max 2 digits
                            minutesInputRef.focus();    // Auto-focus minutes
                            minutesInputRef.select();
                        } else if (valStr.length > 2) {
                            _hours = valStr.slice(0,2); // Prevent more than 2 digits
                        }
                    }}
                    tabindex="1"
                />
            </div>
            <span class="fs-1 mx-1">:</span>
            <div class="ms-2">
                <label for="minutesInput" class="form-label">Minutes</label>
                <input
                    id="minutesInput"
                    bind:this={minutesInputRef}
                    type="number"
                    inputmode="numeric"
                    pattern="[0-9]*"
                    min="0"
                    max="59"
                    class="form-control text-center fs-1"
                    bind:value={_minutes}
                    on:focus={_handleMinutesFocus}
                    on:input={() => {
                        const valStr = String(_minutes);
                        if (valStr.length >= 2) {
                            _minutes = valStr.slice(0, 2); // Ensure max 2 digits
                            const startButton = document.getElementById('setTimerButton');
                            if (startButton) startButton.focus(); // Optionally focus "Start Timer" button
                        } else if (valStr.length > 2) {
                            _minutes = valStr.slice(0,2); // Prevent more than 2 digits
                        }
                    }}
                    tabindex="2"
                />
            </div>
        </div>

        <div class="form-check form-switch text-start ps-5 mb-2">
            <input
                class="form-check-input"
                type="checkbox"
                role="switch"
                id="shutdownCheckbox"
                bind:checked={_shutdown}
                on:change={handleShutdownChange}
            />
            <label class="form-check-label" for="shutdownCheckbox">Shutdown Grill when Timer Ends</label>
        </div>
        <div class="form-check form-switch text-start ps-5">
            <input
                class="form-check-input"
                type="checkbox"
                role="switch"
                id="keepWarmCheckbox"
                bind:checked={_keepWarm}
                on:change={handleKeepWarmChange}
            />
            <label class="form-check-label" for="keepWarmCheckbox">Keep Warm when Timer Ends</label>
        </div>

        {#if error}
            <div class="text-danger mt-3">{error}</div>
        {/if}
    </div>
    <div class="modal-footer">
        <button
            type="button"
            class="btn btn-outline-secondary"
            on:click={() => {
                modalTimer.set(false);
            }}
            tabindex="4"
        >
            Cancel
        </button>
        <button
            id="setTimerButton"
            type="button"
            class="btn btn-danger"
            on:click={_startTimerAndSetOptions}
            tabindex="3"
        >
            Start Timer
        </button>
    </div>
</Modal>
