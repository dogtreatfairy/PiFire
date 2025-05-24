<script>
	import { onMount } from 'svelte';
	import { controlData } from '$lib/stores/socketioStore'; 
	import { colorMode } from '@sveltestrap/sveltestrap';

	import ButtonPrime from '$lib/components/ButtonPrime.svelte';
	import ButtonStart from '$lib/components/ButtonStart.svelte';
	import ButtonSmoke from '$lib/components/ButtonSmoke.svelte';
	import ButtonHold from '$lib/components/ButtonHold.svelte';
	import ButtonStop from '$lib/components/ButtonStop.svelte';
	import ButtonShutdown from '$lib/components/ButtonShutdown.svelte';
	import ButtonManual from '$lib/components/ButtonManual.svelte';
	import ButtonManFan from '$lib/components/ButtonManFan.svelte';
	import ButtonManAug from '$lib/components/ButtonManAug.svelte';
	import ButtonManIgn from '$lib/components/ButtonManIgn.svelte';

	$: currentMode = $controlData?.mode || 'Unknown'; 
	onMount(() => {
		const interval = setInterval(() => {
		}, 1000);

		return () => clearInterval(interval);
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
			</div>

		<div class="btn-toolbar justify-content-center" role="toolbar" id="startup_group" class:d-none={currentMode !=='Startup' && currentMode !=='Reignite'}>
			<div class="btn-group me-2 shadow" role="group">
				<ButtonSmoke />
				<ButtonHold />
			</div>
			<ButtonStop />
			<span class="me-2"></span>
			<ButtonManual />
		</div>

		<div class="btn-toolbar justify-content-center" role="toolbar" id="prime_group" class:d-none={currentMode !=='Prime'}>
			<div class="btn-group me-2 shadow" role="group">
				<ButtonPrime /> 
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
			<ButtonShutdown />
			<span class="me-2"></span> 
			<ButtonManual />
		</div>

		<div class="btn-toolbar justify-content-center" role="toolbar" id="shutdown_group" class:d-none={currentMode !=='Shutdown'}>
			<div class="btn-group me-2 shadow" role="group">
				<ButtonSmoke /> 
				<ButtonHold /> 
			</div>
			<ButtonStop />
			<span class="me-2"></span>
			<ButtonManual /> 
		</div>

		<div class="btn-toolbar justify-content-center" role="toolbar" id="manual_monitor_group" class:d-none={currentMode !=='Manual' && currentMode !=='Monitor'}>
			<div class="btn-group shadow ms-2 me-2" role="group">
				<ButtonStart />
				<ButtonSmoke />
				<ButtonHold /> 
			</div>
			<ButtonStop />
			<span class="me-2"></span>
			<div class="btn-group shadow me-2" role="group">
				<ButtonManFan />
				<ButtonManAug />
				<ButtonManIgn /> 
			</div>
		</div>
	</div>
</footer>
