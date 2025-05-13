<script>
	import { controlData, settingsData, setMode, postAppData } from '$lib/stores/socketioStore';
	import { Modal } from '@sveltestrap/sveltestrap';
	import { modalHold, focusSelect, enterSubmit } from '$lib/stores/modalStore.js';

	$: currentMode = $controlData?.status_data?.mode || 'Unknown';
	$: primarySetPoint = $controlData?.probe_info?.PSP || 0;
	$: units = $settingsData?.globals?.units || 'F';
	$: maxTemp = $settingsData?.globals?.max_temp || 500;

	$: startupExitTemp = $settingsData?.startup?.startup_exit_temp || 0;
	$: startToModeTemp = $settingsData?.startup?.start_to_mode?.primary_setpoint || 0;
	$: startToMode = $settingsData?.startup?.start_to_mode?.after_startup || 'Unknown';
	$: keepWarmTemp = $settingsData?.keep_warm?.temp || 0;

	let setPointInputRef;
	let _initialLoad = true;
	let _setPoint = 0;
	let error = '';

	function _setPointInit() {
		if (primarySetPoint > 0) {
			_setPoint = primarySetPoint;
		} else if (startToMode === 'Hold' && startToModeTemp > 0) {
			_setPoint = startToModeTemp;
		} else if (startupExitTemp > 0) {
			_setPoint = startupExitTemp;
		} else if (keepWarmTemp > 0) {
			_setPoint = keepWarmTemp;
		} else {
			_setPoint = 200; // Default fallback
		}
	}

	function _setTarget() {
		const setPoint = parseInt(_setPoint);
		if (isNaN(setPoint) || setPoint < 0 || setPoint > maxTemp) {
			error = `Please enter a valid temperature between 0 and ${maxTemp} °${units}.`;
			return;
		}

		const postdata = {
			updated: true,
			mode: 'Hold',
			primary_setpoint: setPoint
		};

		console.log('Requesting Hold at:', setPoint);

		postAppData('update_action', 'control', postdata)
			.then(response => {
				console.log('Hold mode set successfully:', response);
				modalHold.set(false);
				error = '';
			})
			.catch(err => {
				console.error('Failed to set Hold mode:', err);
				error = err.message || 'Failed to set Hold mode. Please try again.';
			});
	}

	// Initialize input when modal opens
	$: if ($modalHold && _initialLoad) {
		error = '';
		_setPointInit();
		_initialLoad = false;
		setTimeout(() => {
			if (setPointInputRef && !document.activeElement) {
				setPointInputRef.focus();
				setPointInputRef.select();
			}
		}, 100);
	}

	$: if (!$modalHold) {
		_initialLoad = true;
		error = '';
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
	<span class="ms-2 fw-semibold p-1" style="margin-bottom: 2px;" class:d-none={currentMode !== 'Hold'}>{primarySetPoint} °{units}</span>
</button>

<Modal
	body
	keyboard
	centered
	header="Set Hold Temperature"
	isOpen={$modalHold}
	toggle={() => {
		modalHold.set(false);
		_initialLoad = true;
		error = '';
	}}
>
	<div class="modal-body text-center">
		{#if error}
			<div class="alert alert-danger" role="alert">
				{error}
			</div>
		{/if}
		<div class="d-flex justify-content-center align-items-center mb-3">
			<div class="me-2">
				<label for="_setPoint" class="form-label">Temperature</label>
				<input
					id="_setPoint"
					bind:this={setPointInputRef}
					type="number"
					inputmode="numeric"
					pattern="[0-9]*"
					min="0"
					max={maxTemp}
					class="form-control text-center fs-1"
					bind:value={_setPoint}
					on:keypress={enterSubmit(_setTarget)}
				/>
			</div>
			<span class="fs-4 mx-1"> °{units}</span>
		</div>
	</div>
	<div class="modal-footer">
		<button
			type="button"
			class="btn btn-outline-secondary"
			on:click={() => {
				modalHold.set(false);
				_initialLoad = true;
				error = '';
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