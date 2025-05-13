<script>
	import { settingsData } from '$lib/stores/socketioStore';
	$: console.log('settingsData:', $settingsData);
</script>

<h1 class="text-danger">Settings Data</h1>

<div>
	<pre>{JSON.stringify($settingsData, null, 2)}</pre>
</div>