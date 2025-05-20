<script>
	import { dndzone } from 'svelte-dnd-action';
	import { flip } from 'svelte/animate';
	import { Spinner } from '@sveltestrap/sveltestrap';
	import { settingsData, uiSettings, saveCardOrder } from '$lib/stores/socketioStore';
	import ProbeCard from '$lib/components/ProbeCard.svelte';
	import InfoCard from '$lib/components/InfoCard.svelte';
  
	let items = [];
	let rawItems = [];
	let isInitialized = false;
  
	$: probeDataReady = !!$settingsData?.probe_settings?.probe_map?.probe_info;
	$: if (probeDataReady) {
	  const probeInfo = $settingsData.probe_settings.probe_map.probe_info;
	  const probes = probeInfo.map(probe => ({
		id: `probe-${probe.port}`,
		name: probe.name,
		type: 'probe',
		probeType: probe.type,
		value: probe.profile,
		label: probe.label,
		enabled: probe.enabled,
		device: probe.device
	  }));
	  const infoCard = { id: 'info-card', type: 'info' };
	  rawItems = [...probes, infoCard];
	} else {
	  if (rawItems.length > 0 || !isInitialized) {
	  }
	  rawItems = [];
	  items = [];
	  if (isInitialized) {
		isInitialized = false;
	  }
	}
  
	$: uiSettingsFetchComplete = $uiSettings !== null;
	$: uiSettingsValue = $uiSettings;
  
	$: {
	  if (probeDataReady && uiSettingsFetchComplete && !isInitialized) {
		initializeItems();
	  } else if (!isInitialized) {
		console.warn(">>> Conditions NOT met for initialization (waiting for probe data and/or UI settings fetch).");
	  }
	}
  
	function initializeItems() {
	  const cardOrder = $uiSettings?.cardOrder || [];
  
	  if (!rawItems || rawItems.length === 0) {
		console.warn("Function: initializeItems() - Initialization skipped: rawItems is empty.");
		return;
	  }
  
	  const orderedItems = [];
	  const remainingItems = [...rawItems];
  
	  cardOrder.forEach(id => {
		const index = remainingItems.findIndex(item => item.id === id);
		if (index !== -1) {
		  orderedItems.push(remainingItems[index]);
		  remainingItems.splice(index, 1);
		}
	  });
  
	  orderedItems.push(...remainingItems);
  
	  items = orderedItems;
  
	  if (items.length > 0) {
		isInitialized = true;
	  } else {
		console.warn("Function: initializeItems() - Initialization finished, but no items to display. isInitialized remains false.");
	  }
	}
  
	const flipDurationMs = 300;
  
	async function handleDndConsider(e) {
	  items = e.detail.items;
	}
  
	async function handleDndFinalize(e) {
	  items = e.detail.items;
  
	  const newCardOrder = items.map(item => item.id);
	  try {
		await saveCardOrder(newCardOrder);
  
		// Update the uiSettings store
		uiSettings.update(currentSettings => {
		  const updatedSettings = { ...currentSettings, cardOrder: newCardOrder };
		  return updatedSettings;
		});
	  } catch (error) {
		console.error("saveCardOrder call failed:", error);
		initializeItems();
	  }
	}
  </script>
  
  {#if isInitialized}
	<div class="min-h-screen from-slate-50 to-slate-100 p-8">
	  <div class="max-w-2x mt-4">
		<div
		  class="grid grid-cols-3 gap-6"
		  use:dndzone={{
			items: items,
			flipDurationMs: flipDurationMs
		  }}
		  on:consider={handleDndConsider}
		  on:finalize={handleDndFinalize}
		>
		  {#each items as item (item.id)}
			<div
			  class="relative aspect-square rounded-xl bg-white/50 p-1 backdrop-blur-sm transition-all duration-300 hover:bg-white/60"
			  animate:flip={{ duration: flipDurationMs }}
			>
			  <div class="h-full w-full cursor-move">
				{#if item.type === 'probe'}
				  <ProbeCard name={item.name} label={item.label} type={item.probeType} />
				{:else if item.type === 'info'}
				  <InfoCard />
				{/if}
			  </div>
			</div>
		  {/each}
		</div>
	  </div>
	</div>
  {:else}
	<div class="flex flex-col justify-center items-center min-h-screen text-center p-4">
	  <Spinner color="primary" />
	  <p class="text-xl text-gray-500 mt-4">Loading cards...</p>
	  <div class="mt-4 text-sm text-gray-400">
		<p>Debug Status:</p>
		<p>Probe Data Ready: {probeDataReady}</p>
		<p>UI Settings Fetch Complete: {uiSettingsFetchComplete}</p>
		<p>Is Initialized: {isInitialized}</p>
	  </div>
	</div>
  {/if}
  
  <style>
	.grid {
	  display: grid;
	  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
	  gap: 1.5rem;
	  width: 100%;
	  margin: 0 auto;
	  justify-content: center;
	}
  
	.grid > * {
	  min-width: 0;
	}
  
	@media (max-width: 576px) {
	  .grid { grid-template-columns: 1fr; }
	}
	@media (min-width: 577px) and (max-width: 992px) {
	  .grid { grid-template-columns: repeat(2, minmax(275px, 1fr)); }
	}
	@media (min-width: 993px) and (max-width: 1199px) {
	  .grid { grid-template-columns: repeat(3, minmax(275px, 1fr)); max-width: 95vw; }
	}
	@media (min-width: 1200px) {
	  .grid { grid-template-columns: repeat(4, minmax(275px, 1fr)); max-width: 95vw; }
	}
  
	:global(.svelte-dnd-action-dragged-element) {
	  transform: scale(1.05);
	  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.2);
	  opacity: 1 !important;
	  z-index: 1000;
	  cursor: grabbing !important;
	}
  </style>