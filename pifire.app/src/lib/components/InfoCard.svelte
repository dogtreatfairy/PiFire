<script>
    import { grillControlData, pelletsData, socketStatus } from '$lib/stores/apiDataStore.js';
    import { Progress, colorMode } from '@sveltestrap/sveltestrap';

    let caution = 20;
    let danger = 10;

	$: auger = $grillControlData?.status_data?.outpins?.auger || false;
	$: igniter = $grillControlData?.status_data?.outpins?.igniter || false;
	$: fan = $grillControlData?.status_data?.outpins?.fan || false;

    $: currentMode = $grillControlData?.status_data?.mode || 'Unknown';
    $: hopperLevel = $grillControlData?.hopper_level || 100;
    $: connectionStatus = $socketStatus;

	$: currentPelletId = $pelletsData?.current?.pelletid || 'Unknown';
	$: currentPelletBrand = $pelletsData?.archive?.[currentPelletId]?.brand || 'Unknown';
	$: currentPelletWood = $pelletsData?.archive?.[currentPelletId]?.wood || 'Unknown';

    // Determine the color of the progress bar based on hopperLevel
    $: progressColor = hopperLevel <= danger ? 'danger' : hopperLevel <= caution ? 'warning' : 'success';

    // Determine the badge color based on connection status
    $: connectionBadgeColor =
        connectionStatus === 'Connected' ? 'success' :
        connectionStatus === 'Disconnected' ? 'danger' :
        connectionStatus === 'Refused' ? 'warning' : 'text-secondary';
</script>

<div class="card rounded shadow h-100 w-100 d-flex flex-column align-items-start">
    <div class="card-header d-flex justify-content-between align-items-center p-2 fw-semibold w-100">
        <h4 class="ms-1 mb-0">
            Mode: <span class=" fw-bold { $colorMode === 'dark' ? 'text-warning' : 'text-primary' }">{currentMode}</span>
        </h4>
        <span class="badge bg-{connectionBadgeColor}">{connectionStatus}</span>
    </div>
    <div class="card-body d-flex flex-column justify-content-start align-items-start p-2 w-100">
        <div class="outpins w-100 d-flex justify-content-around align-items-center my-5">
			<div class="outpin-item d-flex flex-column align-items-center">
				<span 
					class="fas fa-fan fa-2xl"
					class:text-primary={fan}
					class:spin={fan}>
				</span>
				<span class="badge mt-4 fs-6 { $colorMode === 'dark' ? 'text-white' : 'text-dark' }">Fan</span>
			</div>
			<div class="outpin-item d-flex flex-column align-items-center">
				<span 
					class="fas fa-angle-double-right fa-2xl"
					class:text-success={auger}
					class:pulse={auger}>
				</span>
				<span class="badge mt-4 fs-6 { $colorMode === 'dark' ? 'text-white' : 'text-dark' }">Auger</span>
			</div>
			<div class="outpin-item d-flex flex-column align-items-center">
				<span 
					class="fas fa-fire fa-2xl"
					class:text-warning={igniter}
					class:pulse={igniter}>
				</span>
				<span class="badge mt-4 fs-6 { $colorMode === 'dark' ? 'text-white' : 'text-dark' }">Ignition</span>
			</div>
		</div>
		<div class="justify-content-start align-items-center d-flex flex-column mb-2 align-self-start">
            <span class="text-start fs-5 fw-semibold">
                Pellets: <span class="">{currentPelletBrand} - {currentPelletWood}</span>
            </span>
        </div>
        <div class="w-100 rounded nav-btn-height position-relative">
            <!-- Hopper Level Label -->
            <span
                class="fs-5 fw-semibold position-absolute top-50 start-50 translate-middle {colorMode !== 'dark' && hopperLevel < 50 ? 'text-dark' : 'text-light'}"
            >
                {hopperLevel}%
            </span>
            <!-- Hopper Level Indicator -->
            <Progress
                class="w-100 h-100"
                value={hopperLevel}
                striped
                color={progressColor}
            />
        </div>
		
    </div>
</div>

<style>
    .card {
        height: 100%;
        width: 100%;
        aspect-ratio: 1/1; /* Enforce 1:1 square ratio */
    }
    .spin {
        animation: spin 1s linear infinite;
    }

    @keyframes spin {
        from {
            transform: rotate(0deg);
        }
        to {
            transform: rotate(360deg);
        }
    }
</style>