<script lang="js">
    import { Modal } from '@sveltestrap/sveltestrap';
    import { modalTimer } from '$lib/stores/modalStore';
    import { timerLaunch, timerStore } from '$lib/timer';
    import { grillControlData } from '$lib/stores/apiDataStore';

    let error = '';
    let _hours ='0';
    let _minutes = '0';
    let _shutdown = false;
    let _keepWarm = false;
    let _initialLoad = true;
	let hoursInputRef;
    let minutesInputRef;

	$: if (!$modalTimer) {
		_initialLoad = true;
	}
	

    // Initialize modal state when modal opens
    $: if ($modalTimer && _initialLoad) {
        error = '';
        _hours =  $timerStore.hours || '0';
        _minutes = $timerStore.minutes || '0';
        _shutdown = $grillControlData?.timer_info?.timer_shutdown || false;
        _keepWarm = $grillControlData?.timer_info?.timer_keep_warm || false;
		_initialLoad = false;
        setTimeout(() => {
            if (hoursInputRef) {
                hoursInputRef.focus();
                hoursInputRef.select();
            }
        }, 100);
    }

    // Add event listener for Enter key to submit the modal
    function handleKeyPress(event) {
        if (event.key === 'Enter') {
            _timerLaunch();
        }
    }

    // Handle toggle changes to enforce mutual exclusivity
    function handleShutdownChange() {
        if (_shutdown) {
            _keepWarm = false; // Disaible keepWarm if shutdown is enabled
        }
    }

    function handleKeepWarmChange() {
        if (_keepWarm) {
            _shutdown = false; // Disable shutdown if keepWarm is enabled
        }
    }

    // Focus and input handling (unchanged)
    function _focusAndSelectMinutes() {
        setTimeout(() => {
            if (minutesInputRef) {
                minutesInputRef.focus();
                minutesInputRef.select();
            }
        }, 0);
    }

    function _handleHoursFocus() {
        if (_hours === '0') {
            _hours = '';
        }
    }

    function _handleMinutesFocus() {
        if (_minutes === '0') {
            _minutes = '';
        }
    }

    function _timerLaunch() {

        const options = {
            timer_shutdown: _shutdown,
            timer_keep_warm: _keepWarm
        };

        // Post to API
        timerLaunch(_hours, _minutes, options);

        // Update the store
        grillControlData.update((data) => ({
            ...data,
            timer_info: {
                ...data?.timer_info,
                timer_shutdown: _shutdown,
                timer_keep_warm: _keepWarm
            }
        }));

        // Close the modal
        modalTimer.set(false);
		_initialLoad = true;
    }
</script>

<Modal
    body
    keyboard
    centered
    header="Set Timer"
    isOpen={$modalTimer}
    toggle={() => modalTimer.set(false)}
    autofocus={false}
>
    <div class="modal-body text-center" on:keypress={handleKeyPress}>
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
                    class="form-control text-center fs-4"
                    style="width: 80px;"
                    bind:value={_hours}
                    on:focus={_handleHoursFocus}
                    on:input={() => {
                        const valStr = String(_hours);
                        if (valStr.length >= 2) {
                            _hours = valStr.slice(0, 2);
                            _focusAndSelectMinutes();
                        }
                    }}
                    tabindex="1"
                    placeholder="0"
                />
            </div>
            <span class="fs-4 mx-1">:</span>
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
                    class="form-control text-center fs-4"
                    style="width: 80px;"
                    bind:value={_minutes}
                    on:focus={_handleMinutesFocus}
                    on:input={() => {
                        const valStr = String(_minutes);
                        if (valStr.length >= 2) {
                            _minutes = valStr.slice(0, 2);
                            document.getElementById('setTimerButton')?.focus();
                        }
                    }}
                    tabindex="2"
                    placeholder="00"
                />
            </div>
        </div>

        <div class="form-check form-switch">
            <input
                class="form-check-input"
                type="checkbox"
                id="shutdownCheckbox"
                bind:checked={_shutdown}
                on:change={handleShutdownChange}
            />
            <label class="form-check-label" for="shutdownCheckbox">Shutdown</label>
        </div>
        <div class="form-check form-switch">
            <input
                class="form-check-input"
                type="checkbox"
                id="keepWarmCheckbox"
                bind:checked={_keepWarm}
                on:change={handleKeepWarmChange}
            />
            <label class="form-check-label" for="keepWarmCheckbox">Keep Warm</label>
        </div>

        {#if error}
            <div class="text-danger mt-2">{error}</div>
        {/if}
    </div>
    <div class="modal-footer">
        <button
            type="button"
            class="btn btn-outline-secondary"
            on:click={() => {
                            modalTimer.set(false);
                            _initialLoad = true;
                        }}
            tabindex="4"
        >
            Cancel
        </button>
        <button
            id="setTimerButton"
            type="button"
            class="btn btn-danger"
            on:click={_timerLaunch}
            tabindex="3"
        >
            Start Timer
        </button>
    </div>
</Modal>