Settings<script>
	import { pelletsData } from '$lib/stores/apiDataStore.js';
	$: console.log('grillControlData:', $pelletsData);
  </script>
  
  <div>
	<pre>{JSON.stringify($pelletsData, null, 2)}</pre>
  </div>