<script>
	import { settingsData } from '$lib/stores/apiDataStore.js';
	$: console.log('grillControlData:', $settingsData);
  </script>
  
  <div>
	<pre>{JSON.stringify($settingsData, null, 2)}</pre>
  </div>