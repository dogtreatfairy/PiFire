<script>
    import { onMount } from 'svelte';
    import { grillControlData } from '$lib/stores/apiDataStore';
    import { get } from 'svelte/store';
	import { colorMode } from '@sveltestrap/sveltestrap';
	import ButtonPrime from '$lib/components/ButtonPrime.svelte';
	import ButtonStart from '$lib/components/ButtonStart.svelte';
	import ButtonSmoke from '$lib/components/ButtonSmoke.svelte';
	import ButtonHold from '$lib/components/ButtonHold.svelte';
	import ButtonStop from '$lib/components/ButtonStop.svelte';
	import ButtonFinish from '$lib/components/ButtonFinish.svelte';
	import ButtonManual from '$lib/components/ButtonManual.svelte';

    // Reactive statement to get the current mode from the grillControlData
	$: currentMode = $grillControlData?.current_mode || 'Unknown'; // Use grillControlData for current mode

	onMount(() => {
		const interval = setInterval(() => {
			// No need to fetch status manually; data is updated via WebSocket
		}, 1000);

		return () => clearInterval(interval); // Cleanup on destroy
	});
</script>

<footer class="navbar fixed-bottom border-top text-center border-2 border-secondary { $colorMode === 'dark' ? 'bg-dark' : 'bg-light' }">
    <div class="container d-flex justify-content-center">

		<div class="btn-toolbar justify-content-center" role="toolbar" id="stopped_group" class:d-none={currentMode !=='Stop' && currentMode !=='Error'}>
			<div class="btn-group me-2 shadow" role="group">
			  <ButtonPrime />
			  <ButtonStart />
			</div>
			<ButtonManual />
			<div class="btn-group shadow" role="group" id="error_group" style={{ display: 'none' }}>
			</div>
		</div>

		<div class="btn-toolbar justify-content-center" role="toolbar" id="startup_group" class:d-none={currentMode !=='Startup' && currentMode !=='Prime' && currentMode !=='Reignite'}>
			<div class="btn-group me-2 shadow" role="group">
			  <ButtonSmoke />
			  <ButtonHold />
			</div>
			<ButtonStop />
			<span class="me-2"></span>
			<ButtonManual />
		</div>
		<div class="btn-toolbar justify-content-center" role="toolbar" id="active_group" class:d-none={currentMode !=='Hold' && currentMode !=='Smoke'}>
			<div class="btn-group me-2 shadow" role="group">
			  <ButtonSmoke /> 
			  <ButtonHold /> 
			</div>
			<ButtonFinish />
			<span class="me-2"></span> 
			<ButtonManual />
		</div>
		<div class="btn-toolbar justify-content-center" role="toolbar" id="shutdown_group" class:d-none={currentMode !=='Finish'}>
			<div class="btn-group me-2 shadow" role="group">
			  <ButtonSmoke /> 
			  <ButtonHold /> 
			</div>
			<ButtonStop />
			<span class="me-2"></span>
			<ButtonManual /> 
		</div>
		<div class="btn-toolbar justify-content-center" role="toolbar" id="shutdown_group" class:d-none={currentMode !=='Manual' && currentMode !=='Monitor'}>
			<div class="btn-group me-2 shadow" role="group">
			  <ButtonSmoke /> 
			  <ButtonHold /> 
			</div>
			<ButtonStop />
			<span class="me-2"></span>
			<ButtonManual /> 
		</div>
</footer>