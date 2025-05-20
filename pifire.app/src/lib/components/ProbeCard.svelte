<script>
	import { controlData, settingsData } from '$lib/stores/socketioStore';
	import Gauge from 'svelte-gauge';
	import { cubicOut } from "svelte/easing";

	export let name; // The name of the probe (e.g., "Grill", "P1")
	export let label; // The label of the probe, used as the key in the data (e.g., "Grill", "P1")
	export let type; // The type of the probe (e.g., "Primary", "Food", "Auxiliary")

	// Reactive variables sourced from stores or props
	$: units = $settingsData?.globals?.units || 'F';
	
	// Determine maxTemp based on probe type, defaulting to safety.maxtemp from settings
	let probeSpecificMaxTemp; 
	$: {
		if (type === 'Food') {
			probeSpecificMaxTemp = (units === 'F') ? 250 : 121; // Example: 250F or 121C for food
		} else {
			// For Primary and Aux, use the general max temp from settings
			probeSpecificMaxTemp = $settingsData?.safety?.maxtemp || ((units === 'F') ? 600 : 315); 
		}
	}

	// convertedType is used to key into the 'probes' object structure (P, F, Aux)
	$: convertedType = type === 'Primary' ? 'P' : type === 'Food' ? 'F' : 'Aux';

	// Access probe data: $controlData.probes is the object containing P, F, Aux keys
	// then $controlData.probes[convertedType] is the object for that type (e.g., $controlData.probes.P)
	// then $controlData.probes[convertedType][label] is the specific probe's temperature
	$: gaugeValue = $controlData?.probes?.[convertedType]?.[label] || 0;

	// Gauge configuration variables
	let _gaugeLabelsStep = 100; // Default step for gauge labels
	let _gaugeRedZoneStartOffset = 50; // How much above maxTemp the red zone starts
	let _gaugeTarget = 0; 
	let _gaugeGreenRange = (units === 'F') ? 10 : 5; // +/- range for target, e.g., 10F or 5C

	// Reactive block to update gauge parameters based on probe type and data
	$: {
		if (type === 'Food') {
			_gaugeLabelsStep = (units === 'F') ? 50 : 25;
			// For food probes, target can be set via notifications.
			// Accessing it from $controlData.probes.NT (Notification Targets)
			_gaugeTarget = $controlData?.probes?.NT?.[label] || 0; 
		} else if (type === 'Primary') {
			// For the primary grill probe, the target is the main Primary Set Point (PSP)
			_gaugeTarget = $controlData?.probes?.PSP || 0; 
			_gaugeLabelsStep = (units === 'F') ? 100 : 50;
		} else { // Auxiliary probes
			_gaugeTarget = $controlData?.probes?.NT?.[label] || 0; // Aux probes might also have notification targets
			_gaugeLabelsStep = (units === 'F') ? 100 : 50;
		}
		// Ensure _gaugeTarget is a number
		_gaugeTarget = Number(_gaugeTarget) || 0;
	}
	
	// Max value for the gauge display
	$: gaugeDisplayMax = probeSpecificMaxTemp + _gaugeRedZoneStartOffset;

	// Boolean Values for gauge styling
	$: inRange = _gaugeTarget !== 0 && Math.abs(gaugeValue - _gaugeTarget) <= _gaugeGreenRange;
	$: isDanger = gaugeValue > probeSpecificMaxTemp;

	const generateLabels = (step, max) => {
		if (step <= 0 || max <= 0) return ["0"]; // Avoid infinite loops or errors
		const labels = [];
		for (let i = 0; i <= max; i += step) {
			labels.push(i.toString());
		}
		if (labels[labels.length -1] < max && !labels.includes(max.toString())) {
			// Ensure the max value itself is a label if not perfectly divisible
			// This might make the last segment look small, adjust step logic if needed
		}
		return labels;
	}
</script>

<div class="card rounded shadow h-100 w-100 d-flex flex-column">
	<div class="card-header d-flex justify-content-between align-items-center p-2 fw-semibold">
		<h4 class="ms-1 mb-0 text-truncate" title={name}>
			{name} </h4>
		<div class="d-flex align-items-end">
			<div class="btn btn-outline-secondary nav-btn-square me-1" title="Probe Settings (Not Implemented)">
				<i class="fas fa-cog"></i>
			</div>
			<div class="btn btn-outline-secondary nav-btn-square" title="Notification Settings (Not Implemented)">
				<i class="fas fa-bell"></i>
			</div>
		</div>
	</div>
	<div class="card-body d-flex flex-column justify-content-center align-items-center p-2">
		<div class="gauge-container">
			<Gauge
				max={gaugeDisplayMax} labels={generateLabels(_gaugeLabelsStep, gaugeDisplayMax)}
				startAngle={45}
				stopAngle={315}
				stroke={20}
				easing={cubicOut}
				value={gaugeValue}
				color={isDanger ? "var(--bs-danger)" : (inRange && _gaugeTarget !== 0 ? "var(--bs-success)" : "var(--bs-primary)")}
				class="gauge-dotted {isDanger ? 'pulse' : ''}"
				segments={[
					...(_gaugeTarget !== 0 && _gaugeTarget < probeSpecificMaxTemp ? [{start: Math.max(0, _gaugeTarget - _gaugeGreenRange), stop: Math.min(probeSpecificMaxTemp, _gaugeTarget + _gaugeGreenRange), color:"var(--bs-success)"}] : []),
					{start: probeSpecificMaxTemp, stop: gaugeDisplayMax, color:"rgba(220, 53, 69, 0.7)"} 
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
						class:text-success={inRange && !isDanger} 
						class:text-danger={_gaugeTarget >= probeSpecificMaxTemp && !isDanger} 
						class:pulse={_gaugeTarget >= probeSpecificMaxTemp && !isDanger} 
						class:d-none={_gaugeTarget === 0 || type === 'Aux'} 
					>
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
		width: 90%; /* Scale gauge to 90% of card */
		height: 90%;
		display: block;
		/* transform: translate(-0%, -2%); Removed minor transform, adjust if needed */
	}

	.gauge-content {
		position: absolute;
		top: 45%; /* Adjusted for better centering */
		left: 50%;
		transform: translate(-50%, -50%);
		font-size: calc(var(--gauge-radius) / 2.2); /* Slightly larger font */
		text-align: center;
		font-weight: 600;
	}
	
	.gauge-target {
		position: absolute;
		bottom: 22%; /* Adjusted position */
		left: 50%;
		transform: translateX(-50%);
		font-size: calc(var(--gauge-radius) / 3.5); /* Adjusted size */
		font-weight: 600;
		text-align: center;
	}

	.gauge-units {
		position: absolute;
		bottom: 5%; /* Adjusted position */
		left: 50%;
		transform: translateX(-50%);
		font-size: calc(var(--gauge-radius) / 5.5); /* Adjusted size */
		font-weight: 600;
		text-align: center;
	}
	.text-truncate {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
</style>
