import { writable } from 'svelte/store';

export const probeDataStore = writable({});
export const settingsStore = writable({});


// Load Settings data from the API
export async function getSettings() {
    try {
        const response = await fetch('/api/settings');
        if (!response.ok) {
            throw new Error(`Failed to fetch settings: ${response.status}`);
        }
        const data = await response.json();
        settingsStore.set(data.settings); 
    } catch (error) {
        console.error('Error loading settings:', error);
    }

}

// Load Current data from the API
export async function getCurrent() {
    try {
        const response = await fetch('/api/get/current');
        if (!response.ok) {
            throw new Error(`Failed to fetch settings: ${response.status}`);
        }
        const data = await response.json();
        probeDataStore.set(data.data);
    } catch (error) {
        console.error('Error loading Probe Data:', error);
    }
}