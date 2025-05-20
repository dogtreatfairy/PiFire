<script>
	import { controlData, setMode, postData, setPMode } from '$lib/stores/socketioStore';
	$: currentMode = $controlData?.status?.mode || 'Unknown'; 
	$: currentDisplayPMode = $controlData?.status?.p_mode || 0;
	async function activateSmokeMode() {
		try {
			await setMode('Smoke');
		} catch (error) {
			console.error('Failed to activate Smoke mode:', error.message || error);
		}
	}
	async function setNewPMode(newPModeValue) { 
		try {
			await setPMode(newPModeValue);
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
					disabled={pModeNum === currentDisplayPMode} 
				>
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
