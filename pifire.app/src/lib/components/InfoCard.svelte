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
    <div class="card-header d-flex flex-column align-items-start p-2 fw-semibold w-100">
        <div class="d-flex justify-content-between align-items-center w-100">
            <h4 class="ms-1 mb-0">
                Mode: <span class="fw-bold { $colorMode === 'dark' ? 'text-warning' : 'text-primary' }">{currentMode}</span>
            </h4>
            <span class="badge bg-{connectionBadgeColor}">{connectionStatus}</span>
        </div>
        <div class="outpins w-100 d-flex justify-content-around align-items-center mt-4 pt-2 fs-5 fw-semibold">
            <div class="outpin-item d-flex flex-column align-items-center { fan ? ($colorMode === 'dark' ? 'text-info' : 'text-primary') : 'text-secondary' }">
                <span 
                    class="fas fa-fan fa-xl"
                    class:spin={fan}>
                </span>
                <span class="mt-4">Fan</span>
            </div>
            <div class="outpin-item d-flex flex-column align-items-center { auger ? 'text-success' : 'text-secondary' }">
                <span 
                    class="fas fa-angle-double-right fa-xl"
                    class:pulse={auger}>
                </span>
                <span class="mt-4">Auger</span>
            </div>
            <div class="outpin-item d-flex flex-column align-items-center { igniter ? 'text-warning' : 'text-secondary' }">
                <span 
                    class="fas fa-fire fa-xl"
                    class:pulse={igniter}>
                </span>
                <span class="mt-4">Ignition</span>
            </div>
        </div>
    </div>
    <div class="card-body d-flex flex-column justify-content-start align-items-start p-2 w-100">

	</div>
	<div class="card-footer d-flex flex-column justify-content-start align-items-start p-2 w-100">
		<div class="d-flex justify-content-between align-items-center w-100 mb-2">
			<span class="text-start fs-4 fw-semibold border border-secondary rounded px-2 py-1 nav-btn-height text-truncate flex-grow-1 me-2 d-flex align-items-center">
				<span class="me-2">Pellets:</span><span>{currentPelletBrand} {currentPelletWood}</span>
			</span>
			<div class="btn nav-btn-square border rounded ms-2">
				<span class="fas fa-arrow-left fa-xl"></span>
			</div>
			<div class="btn nav-btn-square border rounded ms-2">
				<span class="fas fa-arrow-right fa-xl"></span>
			</div>
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
        animation: spin 3s linear infinite;
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