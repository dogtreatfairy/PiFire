<script>
	import { controlData, postAppData } from '$lib/stores/socketioStore';

	$: igniterOn = $controlData?.status_data?.outpins?.igniter || false;
</script>

<!-- Igniter Toggle Button -->
<button
	type="button"
	class="btn nav-btn-height {igniterOn ? 'btn-warning' : 'btn-outline-secondary'}"
	aria-label="{igniterOn ? 'Turn igniter off' : 'Turn igniter on'}"
	on:click={() => postAppData('manual', { component: 'igniter', toggle: true })}
>
	<i class="fas fa-fire-alt"></i> Igniter {igniterOn ? 'On' : 'Off'}
</button>