import { writable } from 'svelte/store';

export const currentStore = writable({});
export const controltStore = writable({});
export const settingStore = writable({});


// Load Settings data from the API
export async function getSettings() {
    try {
        const response = await fetch('/api/settings');
        if (!response.ok) {
            throw new Error(`Failed to fetch settings: ${response.status}`);
        }
        const data = await response.json();
        settingStore.set(data.settings); 
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
        currentStore.set(data.data);
    } catch (error) {
        console.error('Error loading Probe Data:', error);
    }
}

// Load Current data from the API
export async function getControl() {
    try {
        const response = await fetch('/api/get/control');
        if (!response.ok) {
            throw new Error(`Failed to fetch settings: ${response.status}`);
        }
        const data = await response.json();
        controlStore.set(data.data);
    } catch (error) {
        console.error('Error loading Probe Data:', error);
    }
}