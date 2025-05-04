<script>
	import { controlData } from '$lib/stores/apiDataStore.js';
	$: console.log('controlData:', $controlData);
  </script>
  
  <div>
	<pre>{JSON.stringify($controlData, null, 2)}</pre>
  </div>