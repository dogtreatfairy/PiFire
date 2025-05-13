<script>
    import { onMount } from 'svelte';
    import { controlData } from '$lib/stores/socketioStore';
	import { colorMode } from '@sveltestrap/sveltestrap';
	import ButtonPrime from '$lib/components/ButtonPrime.svelte';
	import ButtonStart from '$lib/components/ButtonStart.svelte';
	import ButtonSmoke from '$lib/components/ButtonSmoke.svelte';
	import ButtonHold from '$lib/components/ButtonHold.svelte';
	import ButtonStop from '$lib/components/ButtonStop.svelte';
	import ButtonFinish from '$lib/components/ButtonFinish.svelte';
	import ButtonManual from '$lib/components/ButtonManual.svelte';

    // Reactive statement to get the current mode from the controlData
	$: currentMode = $controlData?.status_data?.mode || 'Unknown'; // Use controlData for current mode

	onMount(() => {
		const interval = setInterval(() => {
			// No need to fetch status manually; data is updated via WebSocket
		}, 1000);

		return () => clearInterval(interval); // Cleanup on destroy
	});
</script>

<footer class="navbar fixed-bottom border-top text-center border-2 border-secondary { $colorMode === 'dark' ? 'bg-dark' : 'bg-light' }">
    <div class="container d-flex justify-content-center">

		<!-- Stop -->
		<div class="btn-toolbar justify-content-center" role="toolbar" id="stopped_group" class:d-none={currentMode !=='Stop' && currentMode !=='Error'}>
			<div class="btn-group me-2 shadow" role="group">
				<ButtonPrime />
				<ButtonStart />
			</div>
			<ButtonManual />
			<div class="btn-group shadow" role="group" id="error_group" style={{ display: 'none' }}>
			</div>
		</div>

		<!-- Startup / Reignite -->
		<div class="btn-toolbar justify-content-center" role="toolbar" id="startup_group" class:d-none={currentMode !=='Startup' && currentMode !=='Reignite'}>
			<div class="btn-group me-2 shadow" role="group">
				<ButtonSmoke />
				<ButtonHold />
			</div>
			<ButtonStop />
			<span class="me-2"></span>
			<ButtonManual />
		</div>

		<!-- Prime -->
		<div class="btn-toolbar justify-content-center" role="toolbar" id="startup_group" class:d-none={currentMode !=='Prime'}>
			<div class="btn-group me-2 shadow" role="group">
				<ButtonPrime />
				<ButtonSmoke />
				<ButtonHold />
			</div>
			<ButtonStop />
			<span class="me-2"></span>
			<ButtonManual />
		</div>

		<!-- Hold / Smoke -->
		<div class="btn-toolbar justify-content-center" role="toolbar" id="active_group" class:d-none={currentMode !=='Hold' && currentMode !=='Smoke'}>
			<div class="btn-group me-2 shadow" role="group">
				<ButtonSmoke /> 
				<ButtonHold /> 
			</div>
			<ButtonFinish />
			<span class="me-2"></span> 
			<ButtonManual />
		</div>

		<!-- Finish -->
		<div class="btn-toolbar justify-content-center" role="toolbar" id="shutdown_group" class:d-none={currentMode !=='Finish'}>
			<div class="btn-group me-2 shadow" role="group">
				<ButtonSmoke /> 
				<ButtonHold /> 
			</div>
			<ButtonStop />
			<span class="me-2"></span>
			<ButtonManual /> 
		</div>

		<!-- Manual / Monitor -->
		<div class="btn-toolbar justify-content-center" role="toolbar" id="shutdown_group" class:d-none={currentMode !=='Manual' && currentMode !=='Monitor'}>
			<ButtonStart />
			<span class="me-2"></span>
			<ButtonStop />
			<div class="btn-group ms-2 shadow" role="group">
				<ButtonHold /> 
			</div>
		</div>
</footer>