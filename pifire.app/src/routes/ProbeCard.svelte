<script>
    import { probeDataStore, settingsStore } from '$lib/stores/apiDataStore.js';
	import { darkMode } from '$lib/stores/themeStore';
    import { derived } from 'svelte/store';
    import Gauge from 'svelte-gauge';
    import { cubicOut } from "svelte/easing";

    export let name; // The name of the probe passed from +page.svelte
    export let type; // The type of the probe (e.g., "Food", "Primary", "Auxiliary")
    export let units; // The units of the probe (e.g., "F" or "C")

    let gaugeValue = 0;
    let gaugeLabels;
    let gaugeRedZone;

    // Set max gauge temp
    $: maxTemp = type === 'Food' ? 250 : ($settingsStore?.safety?.maxtemp || 0);
    gaugeLabels = type === 'Food' ? 50 : 100;
    gaugeRedZone = type === 'Food' ? 25 : 50;
    $: isDanger = gaugeValue > maxTemp;

    // Subscribe to the derived store to update gaugeValue
    $: gaugeValue = $gaugeValueStore;

    // Map the passed type to the corresponding key in probeDataStore
    function mapTypeToStoreKey(type) {
        if (type === 'Food') return 'F';
        if (type === 'Primary') return 'P';
        if (type === 'Auxiliary') return 'AUX';
        return null; // Return null if the type doesn't match
    }

    // Derive the value for the specific probe from probeDataStore
    const gaugeValueStore = derived(probeDataStore, ($probeDataStore) => {
        const storeKey = mapTypeToStoreKey(type); // Map the store key
        if (!$probeDataStore || !storeKey || !name) return 0;
        return $probeDataStore[storeKey]?.[name] || 0;
    });

    // Function to generate labels at intervals
    const generateLabels = (step, max) =>
        Array.from({ length: Math.floor(max / step) + 1 }, (_, i) => (i * step).toString());
</script>

<div class="card rounded shadow h-100 w-100 d-flex flex-column">
    <div class="card-header d-flex justify-content-between align-items-center p-2 fw-semibold">
        <h4 class="ms-1 mb-0">
            {name}
        </h4>
		<div class="d-flex align-items-end">
			<div class="btn btn-outline-secondary nav-btn-square me-1">
				<i class="fas fa-cog"></i>
			</div>
			<div class="btn btn-outline-secondary nav-btn-square">
				<i class="fas fa-bell"></i>
			</div>
		</div>
		
    </div>
    <div class="card-body d-flex flex-column justify-content-center align-items-center p-2">
        <div class="gauge-container">
            <Gauge
                stop={maxTemp+gaugeRedZone}
                labels={generateLabels(gaugeLabels, maxTemp+gaugeRedZone)}
                startAngle={45}
                stopAngle={315}
                stroke={20}
                easing={cubicOut}
                value={gaugeValue}
                color="var(--bs-primary)"
                class="gauge-dotted"
                segments={[
                    {start:maxTemp, stop:maxTemp+gaugeRedZone, color:"var(--bs-danger)"},
                ]}
                let:value
            >
                <div class="gauge-content">
                    <span class="fw-bold" class:pulse={isDanger} class:text-danger={isDanger}>
                        {Math.round(value)}
                    </span>
                </div>
                <div class="gauge-units">
                    <span>°{units}</span>
                </div>
            </Gauge>
        </div>
    </div>
</div>

<style>
    .card {
        height: 100%;
        width: 100%;
        aspect-ratio: 1/1; /* Enforce 1:1 square ratio */
    }

    .gauge-container {
        width: 80%; /* Scale gauge to 80% of card */
        height: 80%;
        display: block;
		transform: translate(-0%, -10%);
    }

    .gauge-content {
        position: absolute;
        top: 45%;
        left: 50%;
        transform: translate(-50%, -50%);
        font-size: calc(var(--gauge-radius) / 2.5); /* Scale font with gauge */
        text-align: center;
        font-weight: 600;
    }

    .gauge-units {
        position: absolute;
        bottom: 0%;
        left: 50%;
		transform: translateX(-50%);
        font-size: calc(var(--gauge-radius) / 5); /* Scale units with gauge */
        font-weight: 600;
        text-align: center;
    }
</style>