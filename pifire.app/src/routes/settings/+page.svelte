
<script>
	import { pelletsData } from '$lib/stores/socketioStore';
	$: console.log('grillControlData:', $pelletsData);
</script>

<h1 class="text-danger">Pellets Data</h1>

<div>
	<pre>{JSON.stringify($pelletsData, null, 2)}</pre>
</div>