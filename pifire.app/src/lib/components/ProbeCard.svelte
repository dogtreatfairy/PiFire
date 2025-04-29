<script>
    import { grillControlData, settingsData } from '$lib/stores/apiDataStore.js';
    import Gauge from 'svelte-gauge';
    import { cubicOut } from "svelte/easing";

    export let name; // The name of the probe passed from +page.svelte
    export let type; // The type of the probe (e.g., "Food", "Primary", "Auxiliary")
    export let units; // The units of the probe (e.g., "F" or "C")

	$: maxTemp = $settingsData.safety?.maxtemp;
	$: convertedType = type === 'Primary' ? 'P' : type === 'Food' ? 'F' : 'Aux';
	$: probeData = $grillControlData?.probe_info?.[convertedType] || {};
    $: gaugeValue = probeData?.[name] || 0;

    let _gaugeLabels = 100;
    let _gaugeRedZone = 50;
	let _gaugeTarget = 0; 
	let _gaugeGreenRange = 10;

	$: {
		if (type === 'Food') {
			maxTemp = 250;
			_gaugeLabels = 50;
			_gaugeRedZone = 25;
		}

		else if (type === 'Primary') {
			_gaugeTarget = $grillControlData?.probe_info?.PSP || 0;
		}
	}

	//Boolean Values	
	$: inRange = Math.abs(gaugeValue - _gaugeTarget) <= _gaugeGreenRange;
    $: isDanger = gaugeValue > maxTemp;

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
                stop={maxTemp+_gaugeRedZone}
                labels={generateLabels(_gaugeLabels, maxTemp+_gaugeRedZone)}
                startAngle={45}
                stopAngle={315}
                stroke={20}
                easing={cubicOut}
                value={gaugeValue}
				color={isDanger ? "var(--bs-danger)" : (inRange && _gaugeTarget !== 0 ? "var(--bs-success)" : "var(--bs-primary)")}
                class="gauge-dotted {isDanger ? 'pulse' : ''}"
				segments={[
					...(_gaugeTarget !== 0 ? [{start:_gaugeTarget-_gaugeGreenRange, stop:_gaugeTarget+_gaugeGreenRange, color:"var(--bs-success)"}] : []),
					{start:maxTemp, stop:maxTemp+_gaugeRedZone, color:"rgb(238, 136, 145)"} // Solid red blended with 50% white
				]}
                let:value
            >
                <div class="gauge-content">
                    <span class="fw-bold mb-0 pb-0" class:pulse={isDanger} class:text-danger={isDanger} class:text-success={inRange && _gaugeTarget !== 0}>
                        {Math.round(value)}
                    </span>
                </div>
				<div class="gauge-target">
                    <span class="fs-1" 
					class:text-success={inRange} 
					class:text-danger={_gaugeTarget >= maxTemp} 
					class:pulse={_gaugeTarget >= maxTemp} 
					class:d-none={type !== 'Primary' || _gaugeTarget === 0}>
					
					&gt;{_gaugeTarget}&lt;
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
        width: 90%; /* Scale gauge to 80% of card */
        height: 90%;
        display: block;
		transform: translate(-0%, -2%);
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
	
	.gauge-target {
        position: absolute;
        bottom: 20%;
        left: 50%;
		transform: translateX(-50%);
        font-size: calc(var(--gauge-radius) / 3); /* Scale units with gauge */
        font-weight: 600;
        text-align: center;
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