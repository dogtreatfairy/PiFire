<script>
	import { controlData, setMode, postAppData } from '$lib/stores/socketioStore';
	// Ensure Bootstrap's JavaScript is loaded in your project for the dropdown functionality to work.

	$: currentMode = $controlData?.status_data?.mode || 'Unknown';
	// currentDisplayPMode is used for showing the P-Mode in the UI.
	// It's derived from status_data.p_mode as in your original code.
	$: currentDisplayPMode = $controlData?.status_data?.p_mode || 0;

	// Function to activate Smoke Mode
	async function activateSmokeMode() {
		console.log('Activating Smoke Mode...');
		try {
			// The setMode function from socketioStore is expected to send:
			// postAppData('update_action', 'control', { updated: true, mode: 'Smoke' })
			await setMode('Smoke');
			console.log('Smoke mode activation request sent successfully.');
		} catch (error) {
			console.error('Failed to activate Smoke mode:', error.message || error);
		}
	}

	// Function to set a new P-Mode value
	async function setNewPMode(newPModeValue) { // newPModeValue will be a number (0-9)
		console.log(`Attempting to set P-Mode to: P-${newPModeValue}`);
		try {
			// Construct payload to update cycle_data.PMode
			const payload = {
				updated: true,
				cycle_data: {
					PMode: newPModeValue // Corrected key to 'PMode' (uppercase P, M)
				}
			};

			// Update settings first
			const response = await postAppData('update_action', 'settings', payload);

			if (response && response.response && response.response.result === 'success') {
				console.log(`P-Mode successfully set to P-${newPModeValue} in settings.`);

				// Issue a control update after settings update
				const controlPayload = { updated: true };
				const controlResponse = await postAppData('update_action', 'control', controlPayload);

				if (controlResponse && controlResponse.response && controlResponse.response.result === 'success') {
					console.log('Control update issued successfully after settings update.');
				} else {
					const errorMessage = controlResponse?.response?.message || controlResponse?.message || 'Unknown error during control update.';
					console.error('Failed to issue control update:', errorMessage);
				}
			} else {
				const errorMessage = response?.response?.message || response?.message || 'Unknown error during P-Mode set.';
				console.error(`Failed to set P-Mode to P-${newPModeValue}:`, errorMessage);
			}
		} catch (error) {
			console.error(`Error setting P-Mode to P-${newPModeValue}:`, error.message || error);
		}
	}
</script>

{#if currentMode === 'Smoke'}
	<div class="btn-group dropup shadow" role="group" aria-label="Smoke P-Mode Options">
		<button
			type="button"
			class="btn dropdown-toggle nav-btn-height btn-warning"
			id="smoke_btn_active"
			data-bs-toggle="dropdown"
			aria-expanded="false"
			aria-label="Change P-Mode Setting (Currently P-{currentDisplayPMode})"
		>
			<i class="fas fa-cloud"></i>
			<span class="badge rounded bg-dark text-warning me-2 ms-1"> P-{currentDisplayPMode}</span>
			</button>
		<div class="dropdown-menu">
			{#each Array.from({ length: 10 }, (_, i) => i) as pModeNum (pModeNum)}
				<button
					class="dropdown-item"
					type="button"
					on:click={() => setNewPMode(pModeNum)}
					disabled={pModeNum === currentDisplayPMode} >
					P-{pModeNum}
				</button>
			{/each}
		</div>
	</div>
{:else}
	<button
		type="button"
		class="btn nav-btn-height btn-outline-secondary shadow" id="smoke_btn_inactive"
		on:click={activateSmokeMode}
		aria-label="Activate Smoke Mode"
	>
		<i class="fas fa-cloud"></i>
		</button>
{/if}