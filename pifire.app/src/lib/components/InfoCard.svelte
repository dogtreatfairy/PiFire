<script>
    import { grillControlData, socketStatus } from '$lib/stores/apiDataStore.js';
    import { Progress } from '@sveltestrap/sveltestrap';

    let caution = 20;
    let danger = 10;

    $: currentMode = $grillControlData?.current_mode || 'Unknown';
    $: hopperLevel = $grillControlData?.hopper_level || 100;
    $: connectionStatus = $socketStatus;

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
            Status
        </h4>
        <span class="badge bg-{connectionBadgeColor}">{connectionStatus}</span>
    </div>
    <div class="card-body d-flex flex-column justify-content-start align-items-start p-2 w-100">
        <div class="justify-content-start align-items-center d-flex flex-column mb-2 align-self-start">
            <span class="text-start fs-5 fw-semibold">
                Mode: <span class="text-warning">{currentMode}</span>
            </span>
        </div>
        <div class="w-100 rounded nav-btn-height position-relative">
            <!-- Hopper Level Label -->
            <span
                class="fs-5 fw-semibold position-absolute top-50 start-50 translate-middle {hopperLevel > 50 ? 'text-light' : 'text-dark'}"
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
</style>