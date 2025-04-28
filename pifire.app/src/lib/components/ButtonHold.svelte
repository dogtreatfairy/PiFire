<script>
	import { grillControlData, settingsData, setMode, postAppData } from '$lib/stores/apiDataStore.js';
	import { Modal } from '@sveltestrap/sveltestrap';
	import { modalHold, focusSelect, enterSubmit } from '$lib/stores/modalStore.js';

	$: currentMode = $grillControlData?.current_mode || 'Unknown';
	$: primarySetPoint = $grillControlData?.probe_info?.PSP || 0;
	$: units = $settingsData?.globals?.units || 'F';
	$: maxTemp = $settingsData?.globals?.max_temp || 500;

	$: startupExitTemp = $settingsData?.startup?.startup_exit_temp || 0;
	$: startToModeTemp = $settingsData?.startup?.start_to_mode?.primary_setpoint || 0;
	$: startToMode = $settingsData?.startup?.start_to_mode?.after_startup || 'Unknown';
	$: keepWarmTemp = $settingsData?.keep_warm?.temp || 0;

	let setPointInputRef;
	let _initialLoad = true;
	let _setPoint = 0;
	let error = ''; // Define the error variable

	function _setTarget() {
		const setPoint = parseInt(_setPoint); // Parse the set point value
		const postdata = {
			updated: true,
			mode: 'Hold',
			primary_setpoint: setPoint
		};

		console.log('Requesting Hold at:', setPoint);

		postAppData('update_action', 'control', postdata)
			.then(response => {
				console.log('Hold mode set successfully:', response);
				modalHold.set(false); // Close the modal after success
			})
			.catch(error => {
				console.error('Failed to set Hold mode:', error);
				error = 'Failed to set Hold mode. Please try again.'; // Update error message
			});
	}

	// Initial Input Value Logic
	$: if ($modalHold && _initialLoad) {
        error = '';
        _setPoint =  primarySetPoint || 0;
		_initialLoad = false;
        setTimeout(() => {
            if (setPointInputRef) {
                setPointInputRef.focus();
                setPointInputRef.select();
            }
        }, 100);
    }

	$: if (!$modalHold) {
		_initialLoad = true;
	}
</script>

<!-- Hold Button -->
<button 
	type="button" 
	class="btn border border-secondary nav-btn-height {currentMode === 'Hold' ? 'btn-success' : 'btn-outline-secondary'}"
	id="hold_btn" 
	on:click={() => modalHold.set(true)}
	aria-label="Hold Mode Modal"
>
	<i class="fas fa-crosshairs"></i>
	<span class="ms-2 fw-semibold p-1" style="margin-bottom: 2px;" class:d-none={currentMode !== 'Hold'}>{primarySetPoint} &deg{units}</span>
</button>

<Modal 
	body
	keyboard
	centered
	header="Set Hold Temperature"
	isOpen={$modalHold}
	toggle={() => modalHold.set(false)}
	autofocus={true}
>
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="modal-body text-center" on:keypress={enterSubmit(_setTarget)}>
        <div class="d-flex justify-content-center align-items-center mb-3">
            <div class="me-2">
                <label for="hoursInput" class="form-label">Hours</label>
                <input
                    id="_setPoint"
                    bind:this={setPointInputRef}
                    type="number"
                    inputmode="numeric"
                    pattern="[0-9]*"
                    min="0"
                    max={maxTemp}
                    class="form-control text-center fs-4"
                    style="width: 80px;"
                    bind:value={_setPoint}
                />
            </div>
            <span class="fs-4 mx-1"> &deg{units}</span>
        </div>
	</div>
	<div class="modal-footer">
		<button
			type="button"
			class="btn btn-outline-secondary"
			on:click={() => {
							modalHold.set(false);
							_initialLoad = true;
						}}
		>
			Cancel
		</button>
		<button
			id="setTargetButton"
			type="button"
			class="btn btn-success"
			on:click={_setTarget}
		>
			Set Target
		</button>
	</div>
</Modal>