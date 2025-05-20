<script>
	import { controlData, settingsData, setMode } from '$lib/stores/socketioStore';
	import { Modal } from '@sveltestrap/sveltestrap';
	import { modalHold, focusSelect, enterSubmit } from '$lib/stores/modalStore.js';

	$: currentMode = $controlData?.status?.mode || 'Unknown'; 
	$: currentDisplayPSP = $controlData?.status?.primary_setpoint !== undefined ? $controlData?.status?.primary_setpoint : ($controlData?.probes?.PSP || 0);

	$: units = $settingsData?.globals?.units || 'F';
	$: maxTemp = $settingsData?.safety?.maxtemp || 550;

	$: startupExitTemp = $settingsData?.startup?.startup_exit_temp || 0;
	$: startToModeTemp = $settingsData?.startup?.start_to_mode?.primary_setpoint || 0;
	$: startToModeAfterStartup = $settingsData?.startup?.start_to_mode?.after_startup_mode || 'Unknown';
	$: keepWarmTemp = $settingsData?.keep_warm?.temp || 0;

	let setPointInputRef;
	let _initialLoad = true;
	let _setPoint = 0;
	let error = '';

	function _setPointInit() {
		if (currentMode === 'Hold' && currentDisplayPSP > 0) {
			_setPoint = currentDisplayPSP;
		} else if (startToModeAfterStartup === 'Hold' && startToModeTemp > 0) {
			_setPoint = startToModeTemp;
		} else if (startupExitTemp > 0 && currentMode === 'Startup') {
			_setPoint = startupExitTemp;
		} else if (keepWarmTemp > 0) {
			_setPoint = keepWarmTemp;
		} else {
			_setPoint = (units === 'F') ? 225 : 100;
		}
	}

	async function _setTarget() { 
		const setPointValue = parseInt(_setPoint); 
		if (isNaN(setPointValue) || setPointValue < 0 || setPointValue > maxTemp) {
			error = `Please enter a valid temperature between 0 and ${maxTemp} °${units}.`;
			return;
		}
		try {
			const response = await setMode('Hold', {psp: setPointValue}); 
			modalHold.set(false);
			error = '';
		} catch (err) {
			console.error('Failed to set Hold mode:', err);
			error = err.message || 'Failed to set Hold mode. Please try again.';
		}
	}

	$: if ($modalHold && _initialLoad) {
		error = '';
		_setPointInit();
		_initialLoad = false;
		setTimeout(() => {
			if (setPointInputRef && (typeof document === 'undefined' || !document.activeElement || document.activeElement === document.body)) {
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

<button
	type="button"
	class="btn border border-secondary nav-btn-height {currentMode === 'Hold' ? 'btn-success' : 'btn-outline-secondary'}"
	id="hold_btn"
	on:click={() => modalHold.set(true)}
	aria-label="Set Hold Temperature"
>
	<i class="fas fa-crosshairs"></i>
	{#if currentMode === 'Hold'}
		<span class="ms-2 fw-semibold p-1" style="margin-bottom: 2px;">{currentDisplayPSP}°{units}</span>
	{/if}
</button>

<Modal
	body
	keyboard
	centered
	header="Set Hold Temperature"
	isOpen={$modalHold}
	toggle={() => {
		modalHold.set(false);
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
				<label for="setPointInput" class="form-label">Temperature</label>
				<input
					id="setPointInput"
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
