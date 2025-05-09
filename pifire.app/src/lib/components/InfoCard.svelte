<script>
    import { grillControlData, pelletsData, socketStatus } from '$lib/stores/apiDataStore.js';
    import { Progress, colorMode } from '@sveltestrap/sveltestrap';
    import { onMount, onDestroy } from 'svelte';

    let caution = 20;
    let danger = 10;

    let startupClock = '--:--:--';
    let timerInterval;
    let cardEl;
    let cardWidth = 0;
    let showLabels = true;

    function updateSizes() {
        if (cardEl) {
            cardWidth = cardEl.clientWidth;
            showLabels = cardWidth >= 350; // Threshold where labels disappear
        }
    }

    onMount(() => {
        const updateClock = () => {
            const mode = $grillControlData?.status_data?.mode || 'Unknown';

            if (['Stop', 'Manual', 'Monitor'].includes(mode)) {
                clearInterval(timerInterval);
                startupClock = '--:--:--';
                return;
            }

            const startupTimestamp = $grillControlData?.status_data?.startup_timestamp || 0;

            if (startupTimestamp) {
                timerInterval = setInterval(() => {
                    const currentTime = Date.now() / 1000;
                    const elapsedTime = Math.max(0, currentTime - startupTimestamp);

                    const hours = String(Math.floor(elapsedTime / 3600)).padStart(2, '0');
                    const minutes = String(Math.floor((elapsedTime % 3600) / 60)).padStart(2, '0');
                    const seconds = String(Math.floor(elapsedTime % 60)).padStart(2, '0');

                    startupClock = `${hours}:${minutes}:${seconds}`;
                }, 1000);
            }
        };

        updateClock();
        updateSizes();

        const unsubscribe = grillControlData.subscribe(() => {
            updateClock();
        });

        window.addEventListener('resize', updateSizes);

        return () => {
            clearInterval(timerInterval);
            unsubscribe();
            window.removeEventListener('resize', updateSizes);
        };
    });

    onDestroy(() => {
        if (timerInterval) {
            clearInterval(timerInterval);
        }
    });

    $: auger = $grillControlData?.status_data?.outpins?.auger || false;
    $: igniter = $grillControlData?.status_data?.outpins?.igniter || false;
    $: fan = $grillControlData?.status_data?.outpins?.fan || false;
    $: pmode = $grillControlData?.status_data?.p_mode || 0;

    $: currentMode = $grillControlData?.status_data?.mode || 'Unknown';
    $: hopperLevel = $grillControlData?.hopper_level || 100;
    $: connectionStatus = $socketStatus;

    $: currentPelletId = $pelletsData?.current?.pelletid || 'Unknown';
    $: currentPelletBrand = $pelletsData?.archive?.[currentPelletId]?.brand || 'Unknown';
    $: currentPelletWood = $pelletsData?.archive?.[currentPelletId]?.wood || 'Unknown';

    $: progressColor = hopperLevel <= danger ? 'danger' : hopperLevel <= caution ? 'warning' : 'success';

    $: connectionBadgeColor =
        connectionStatus === 'Connected' ? 'success' :
        connectionStatus === 'Disconnected' ? 'danger' :
        connectionStatus === 'Refused' ? 'warning' : 'text-secondary';
</script>

<div class="card rounded shadow h-100 w-100 d-flex flex-column align-items-start" bind:this={cardEl}>
    <div class="card-header d-flex flex-column align-items-start p-2 fw-semibold w-100">
        <div class="d-flex justify-content-between align-items-center w-100">
            <h4 class="ms-1 mb-0">
                Mode: <span class="fw-bold { $colorMode === 'dark' ? 'text-warning' : 'text-primary' }">{currentMode}</span>
            </h4>
            <span class="badge bg-{connectionBadgeColor}">{connectionStatus}</span>
        </div>
    </div>
    <div class="card-body d-flex flex-column justify-content-start align-items-start p-2 w-100">
        <div class="d-flex justify-content-around align-items-center w-100 mt-3">
            <div class="text-center outpin-item">
                <i class="fas fa-fan fa-2x { fan ? ($colorMode === 'dark' ? 'text-info spin' : 'text-primary spin') : 'text-secondary' }"></i>
                {#if showLabels}
                    <span class="outpin-label">FAN</span>
                {/if}
            </div>
            <div class="text-center outpin-item">
                <i class="fas fa-angle-double-right fa-2x { auger ? 'text-success pulse' : 'text-secondary' }"></i>
                {#if showLabels}
                    <span class="outpin-label">AUG</span>
                {/if}
            </div>
            <div class="text-center outpin-item">
                <i class="fas fa-fire fa-2x { igniter ? 'text-warning pulse' : 'text-secondary' }"></i>
                {#if showLabels}
                    <span class="outpin-label">IGN</span>
                {/if}
            </div>
            <div class="text-center outpin-item">
                <span class="fa-stack" style="color: {currentMode === 'Smoke' ? 'rgb(175, 0, 175)' : 'var(--bs-secondary)'};">
                    <i class="far fa-square fa-stack-2x"></i>
                    {#if pmode > 0 && currentMode === 'Smoke'}
                        <span class="fa-stack-1x fw-bold">{pmode}</span>
                    {:else}
                        <i class="fas fa-minus fa-stack-1x"></i>
                    {/if}
                </span>
                {#if showLabels}
                    <span class="outpin-label" style="margin-top: .7rem;">PMD</span>
                {/if}
            </div>
        </div>
        <div class="d-flex flex-column justify-content-center align-items-center w-100 rounded mt-3">
            <span class="text-center my-0 py-0" style="font-size: {cardWidth * 0.01}rem;">{startupClock}</span>
        </div>
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
            <span
                class="fs-5 fw-semibold position-absolute top-50 start-50 translate-middle {colorMode !== 'dark' && hopperLevel < 50 ? 'text-dark' : 'text-light'}"
            >
                {hopperLevel}%
            </span>
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

    .outpin-item {
        font-size: 1rem;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
    }

    @media (max-width: 576px) {
        .outpin-item {
            font-size: 1.2rem;
        }
    }

    @media (min-width: 577px) and (max-width: 992px) {
        .outpin-item {
            font-size: 1.1rem;
        }
    }

    @media (min-width: 993px) and (max-width: 1199px) {
        .outpin-item {
            font-size: 1rem;
        }
    }

    .fa-stack .fa-square {
        font-size: 2.5rem;
        border-radius: 0.25rem;
        margin-top: -0.2rem;
    }

    .fa-stack-1x {
        font-size: 1.25rem;
        line-height: 2em;
        margin-top: -0.3rem;
    }

    .outpin-label {
        margin-top: 0.7rem;
        font-size: 1.1rem;
        font-weight: 600;
    }
</style>