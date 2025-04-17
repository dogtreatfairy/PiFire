<script>
    import { probeDataStore } from '$lib/stores/apiDataStore.js';
    import { derived } from 'svelte/store';
    import Gauge from 'svelte-gauge';
	import { cubicOut } from "svelte/easing";

    export let name; // The name of the probe passed from +page.svelte
    export let type; // The type of the probe (e.g., "Food", "Primary", "Auxiliary")
    export let units; // The units of the probe (e.g., "F" or "C")

    let gaugeValue = 0;

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
        const storeKey = mapTypeToStoreKey(type); // Map the type to the store key
        if (!$probeDataStore || !storeKey || !name) return 0;
        return $probeDataStore[storeKey]?.[name] || 0;
    });

	// Function to generate labels at intervals
	const generateLabels = (step, count) =>
    Array.from({ length: count }, (_, i) => (i * step).toString());
</script>

<div class="card h-100 w-100 d-flex flex-column navbar-dark text-white">
    <div class="card-header d-flex justify-content-between align-items-center p-2 fw-semibold">
        <h5 class="mb-0">
            <i class="fas fa-tachometer-alt"></i>&nbsp; {name}
        </h5>
    </div>
    <div class="card-body d-flex flex-column justify-content-center align-items-center p-2">
        <div class="gauge-container">
            <Gauge
                stop={500}
                labels={generateLabels(100, 6)}
                startAngle={45}
                stopAngle={315}
                stroke={20}
                easing={cubicOut}
                value={gaugeValue}
                color="#0d6efd"
                class="gauge-dotted"
                let:value
            >
                <div class="gauge-content">
                    <span>{Math.round(value)}</span>
                </div>
				<div class="gauge-units">
					<span>&deg;{units}</span>
				</div>
            </Gauge>
        </div>
    </div>
    <div class="card-footer d-flex justify-content-between align-items-center p-2">
        {#if type === 'Food'}
            <button class="btn btn-sm btn-light">
                <i class="fas fa-alarm"></i> Alarm
            </button>
        {/if}
        <button class="btn btn-sm btn-light">
            <i class="fas fa-cog"></i> Settings
        </button>
    </div>
</div>