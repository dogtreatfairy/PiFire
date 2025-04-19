import { writable, get } from 'svelte/store';

export const controlStore = writable({});
export const currentStore = writable({});
export const settingsStore = writable({});
export const statusStore = writable({});
export const hopperStore = writable({});
export const pfAddress = writable('http://pifire.local'); // Base address of your Flask API


// Generic function to fetch data from the API
export async function getApiData(endpoint, store, dataKey) {
    try {
        const address = get(pfAddress); // Get the current value of pfAddress
        const response = await fetch(`${address}/api${endpoint}`, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
            },
        });

        if (!response.ok) {
            throw new Error(`Failed to fetch data from ${endpoint}: ${response.status}`);
        }

        const data = await response.json();
        store.set(data[dataKey]); // Dynamically set the store with the appropriate key
    } catch (error) {
        console.error(`Error loading data from ${endpoint}:`, error);
    }
}

// Generic function to write data to the API
export async function writeApiData(path, value) {
    try {
        const address = get(pfAddress); // Get the current value of pfAddress

        // Get the current settings from the store
        const settings = get(settingsStore);

        // Dynamically update the nested structure
        const pathParts = path.split('.');
        let current = settings;
        for (let i = 0; i < pathParts.length - 1; i++) {
            const key = pathParts[i];
            if (!(key in current)) {
                current[key] = {}; // Create nested objects if they don't exist
            }
            current = current[key];
        }
        current[pathParts[pathParts.length - 1]] = value;

        // Send the updated settings back to the API
        const response = await fetch(`${address}/api/settings`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(settings), // Send the updated settings as JSON
        });

        if (!response.ok) {
            throw new Error(`Failed to write data to ${path}: ${response.status}`);
        }

        const data = await response.json();
        settingsStore.set(data.settings); // Update the store with the new settings
        return data; // Return the response data for further use
    } catch (error) {
        console.error(`Error writing data to ${path}:`, error);
    }
}


export async function setMode(mode, primeAmount = null, nextMode = null) {
	const postdata = {
		updated: true,
		mode: mode,
	};

	// Add primeAmount and nextMode if provided
	if (mode === 'Prime' && primeAmount !== null && nextMode) {
		postdata.prime_amount = primeAmount;
		postdata.next_mode = nextMode;
	}

	try {
		const address = get(pfAddress);
		const response = await fetch(`${address}/api/control`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
			},
			body: JSON.stringify(postdata),
		});

		if (!response.ok) {
			throw new Error(`Failed to set mode to: ${mode}. HTTP status: ${response.status}`);
		}

		const data = await response.json();
		console.log(`API Post Call: Mode set to ${data.control}`);
	} catch (error) {
		console.error(`Error setting mode to ${mode}:`, error.message);
	}
}

// Calls to fetch specific data
export async function getSettings() {
    await getApiData('/settings', settingsStore, 'settings');
}

export async function getCurrent() {
    await getApiData('/get/current', currentStore, 'data');
}

export async function getControl() {
    await getApiData('/get/control', controlStore, 'data');
}
export async function getStatus() {
	await getApiData('/get/status', statusStore, 'data');
}
export async function getHopper() {
	await getApiData('/get/hopper', hopperStore, 'data');
}
