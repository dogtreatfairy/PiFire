import { get } from 'svelte/store';
import { loadSettings } from '$lib/stores/apiDataStore.js';

/**
 * Function to build a list of probes based on the type
 * @param {string} type - The type of probes to filter ('Primary' or 'Food')
 * @returns {Array} - Array of filtered probes
 */
// Build probes array from settingsStore
export function buildProbes(settings) {
	return settings?.probe_settings?.probe_map?.probe_info?.map((probe) => ({
		name: probe.name,
		type: probe.type,
		enabled: probe.enabled
	})) || [];
}