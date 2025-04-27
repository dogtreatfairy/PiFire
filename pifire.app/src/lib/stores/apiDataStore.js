import { writable, get } from 'svelte/store';
import { io } from 'socket.io-client'; // Client library

// --- Svelte Stores for Reactive State ---
// Connection & Core Data
export const isConnected = writable(false);
export const socketStatus = writable('Disconnected');
export const serverAddress = writable('http://localhost');
export const serverPort = writable('8000');
export const grillControlData = writable({}); // From 'grill_control_data' event

// Data from get_app_data endpoint
export const settingsData = writable({});
export const pelletsData = writable({});   // New store for pellets_data
export const eventsData = writable({});    // New store for events_data
export const infoData = writable({});      // New store for info_data
export const manualData = writable({});    // New store for manual_data

// --- Internal Module State ---
let socket = null; // Holds the current Socket.IO client instance

// --- Private Helper Functions ---

/**
 * Attaches event listeners to the socket.
 * @param {object} currentSocket - The socket instance.
 */
function _attachListeners(currentSocket) {
    currentSocket.on('connect', () => {
        const address = `${get(serverAddress)}:${get(serverPort)}`;
        console.log(`Socket connected to server at ${address}`);
        isConnected.set(true);
        socketStatus.set('Connected');
        
		// Request initial dashboard data upon successful connection
        emitEvent('get_dash_data', { force: true });
        requestSettings();
        requestPelletsData();
    });

    currentSocket.on('disconnect', (reason) => {
        console.log(`Socket disconnected. Reason: ${reason}`);
        isConnected.set(false);
        socketStatus.set('Disconnected');
    });

    currentSocket.on('connect_error', (error) => {
        console.error('Socket connection error:', error.message);
        isConnected.set(false);
        socketStatus.set('Error');
    });

    // Listener for continuous dashboard updates
    currentSocket.on('grill_control_data', (data) => {
        grillControlData.set(data);
    });
    // Add listeners for any other push events from the server if needed
}

/**
 * Removes event listeners for cleanup.
 * @param {object} currentSocket - The socket instance.
 */
function _removeListeners(currentSocket) {
    currentSocket.off('connect');
    currentSocket.off('disconnect');
    currentSocket.off('connect_error');
    currentSocket.off('grill_control_data');
    // Add .off() for other custom listeners
}

/**
 * Internal function to establish the connection.
 */
function _connectInternal() {
    if (socket && (socket.connected || socket.connecting)) {
        console.warn('Socket connection attempt ignored: Already connected or connecting.');
        return;
    }
    if (socket) {
        _removeListeners(socket);
        socket.disconnect();
        socket = null;
    }

    const address = `${get(serverAddress)}:${get(serverPort)}`;
    console.log(`Attempting to connect to socket server at ${address}...`);
    socketStatus.set('Connecting');

    socket = io(address, {
        reconnection: true,
    });

    _attachListeners(socket);
}

export function initializeSocket() {
    if (typeof window !== 'undefined') {
        const savedAddress = localStorage.getItem('serverAddress');
        if (savedAddress) {
            serverAddress.set(savedAddress);
        }
        _connectInternal();
    } else {
        console.warn("Socket initialization skipped: Not running in a browser environment.");
    }
}

export function disconnectSocket() {
    if (socket) {
        console.log('Disconnecting socket...');
        _removeListeners(socket);
        socket.disconnect();
        socket = null;
        isConnected.set(false);
        socketStatus.set('Disconnected');
    }
}

/**
 * Switches the connection to a new server.
 * @param {string} newAddress - Base address (e.g., 'http://192.168.1.100').
 * @param {string} [newPort] - Optional port.
 */
export function switchServer(newAddress, newPort) {
    console.log(`Switching server to ${newAddress}:${newPort || get(serverPort)}`);
    disconnectSocket(); // Clean up old connection

    // Clear all data stores on server switch
    grillControlData.set({});
    settingsData.set({});
    pelletsData.set({});
    eventsData.set({});
    infoData.set({});
    manualData.set({});
    console.log('Cleared local data stores for server switch.');

    serverAddress.set(newAddress);
    if (newPort) {
        serverPort.set(newPort);
    }
    if (typeof window !== 'undefined') { // Client-side check
        localStorage.setItem('serverAddress', newAddress); // Persist
    }
    setTimeout(_connectInternal, 100); // Connect to new server
}

/**
 * Generic function to emit an event to the server.
 * @param {string} eventName - Event name.
 * @param {object} [data={}] - Payload.
 */
export function emitEvent(eventName, data = {}) {
    if (socket && socket.connected) {
        socket.emit(eventName, data);
    } else {
        console.error(`Socket not connected. Cannot emit event '${eventName}'. Status: ${get(socketStatus)}`);
    }
}

/**
 * Generic function to emit an event and wait for an acknowledgement (callback).
 * Used internally by request* functions.
 * @param {string} eventName - The event name to emit.
 * @param {object} data - The data payload to send.
 * @param {number} [timeoutMs=5000] - Timeout duration in milliseconds.
 * @returns {Promise<object>} A promise that resolves with the response data or rejects on error/timeout.
 */
function _emitWithAck(eventName, data, timeoutMs = 5000) {
    return new Promise((resolve, reject) => {
        if (!socket || !socket.connected) {
            console.error(`Cannot emit ${eventName}: Socket is not connected.`);
            return reject(new Error('Socket is not connected'));
        }

        let timedOut = false;
        const timer = setTimeout(() => {
            timedOut = true;
            console.error(`Timeout waiting for acknowledgement for event '${eventName}'.`);
            reject(new Error(`Timeout waiting for ${eventName} response`));
        }, timeoutMs);

        socket.emit(eventName, data, (response) => {
            clearTimeout(timer); // Clear the timeout timer
            if (timedOut) return; // Ignore if already timed out

            // Basic check if server responded. Server might send specific error structure.
            if (response && typeof response === 'object' && response.response?.result === 'error') {
                 console.error(`Server returned error for ${eventName}:`, response.response.message);
                 reject(new Error(response.response.message || `Server error for ${eventName}`));
            } else if (response) {
                // console.log(`Received ack for ${eventName}:`, response); // Optional log
                resolve(response);
            } else {
                // Server acknowledged, but sent no data or an unexpected format
                console.error(`Failed to retrieve data for ${eventName} (server responded empty/unexpected).`);
                reject(new Error(`Server responded unsuccessfully for ${eventName}`));
            }
        });
    });
}


// --- Functions to Request Specific Data (using get_app_data) ---

/** Requests settings_data and updates the settingsData store. */
export async function requestSettings() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'settings_data' });
        settingsData.set(response);
        return response; // Return data for potential chaining/direct use
    } catch (error) {
        console.error("Failed to request settings data:", error);
        // Optionally set store to an error state or empty object
        // settingsData.set({ error: error.message });
        throw error; // Re-throw error for calling code to handle
    }
}

/** Requests pellets_data and updates the pelletsData store. */
export async function requestPelletsData() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'pellets_data' });
        pelletsData.set(response);
        return response;
    } catch (error) {
        console.error("Failed to request pellets data:", error);
        // pelletsData.set({ error: error.message });
        throw error;
    }
}

/** Requests events_data and updates the eventsData store. */
export async function requestEventsData() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'events_data' });
        eventsData.set(response);
        return response;
    } catch (error) {
        console.error("Failed to request events data:", error);
        // eventsData.set({ error: error.message });
        throw error;
    }
}

/** Requests info_data and updates the infoData store. */
export async function requestInfoData() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'info_data' });
        infoData.set(response);
        return response;
    } catch (error) {
        console.error("Failed to request info data:", error);
        // infoData.set({ error: error.message });
        throw error;
    }
}

/** Requests manual_data and updates the manualData store. */
export async function requestManualData() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'manual_data' });
        manualData.set(response);
        return response;
    } catch (error) {
        console.error("Failed to request manual data:", error);
        // manualData.set({ error: error.message });
        throw error;
    }
}

/** Requests timer_data and updates the grillControlData store. */
export async function requestGrillControlData() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'grill_control_data' });
        grillControlData.set(response);
        return response;
    } catch (error) {
        console.error("Failed to request manual data:", error);
        // manualData.set({ error: error.message });
        throw error;
    }
}

// --- Function to Post Data (using post_app_data) ---

/**
 * Sends data to the server's 'post_app_data' handler.
 * Automatically stringifies the payload for the 'json_data' field.
 * @param {string} action - The action type (e.g., 'update_action', 'admin_action').
 * @param {string} type - The specific type within the action (e.g., 'settings', 'control', 'reboot').
 * @param {object} payload - The JavaScript object to be sent as JSON data.
 * @param {number} [timeoutMs=5000] - Timeout duration in milliseconds.
 * @returns {Promise<object>} A promise resolving with the server's acknowledgement response.
 */
export async function postAppData(action, type, payload = {}, timeoutMs = 5000) { // Added timeoutMs
	if (!action || !type) {
		console.error("postAppData requires 'action' and 'type' arguments.");
		return Promise.reject(new Error("postAppData requires 'action' and 'type' arguments."));
	}

	// Stringify the payload as expected by the backend's json_data parameter
	const jsonPayloadString = JSON.stringify(payload);

	console.log(`Posting App Data - Action: ${action}, Type: ${type}, Payload Object:`, payload);

	// *** MODIFICATION START ***
	// Bypass _emitWithAck and call socket.emit directly with the 3 arguments format
	// Use a Promise to handle the acknowledgement callback like _emitWithAck does.
	return new Promise((resolve, reject) => {
		if (!socket || !socket.connected) {
			console.error(`Cannot postAppData ${action}/${type}: Socket is not connected.`);
			return reject(new Error('Socket is not connected'));
		}

		let timedOut = false;
		const timer = setTimeout(() => {
			timedOut = true;
			console.error(`Timeout waiting for acknowledgement for post_app_data ${action}/${type}.`);
			reject(new Error(`Timeout waiting for post_app_data ${action}/${type} response`));
		}, timeoutMs);

		// Emit with the correct 3 arguments + ack callback
		socket.emit('post_app_data', action, type, jsonPayloadString, (response) => {
			clearTimeout(timer); // Clear the timeout timer
			if (timedOut) return; // Ignore if already timed out

            console.log(`postAppData raw response for ${action}/${type}:`, response); // Log the raw response

			// Check the structure of the server's acknowledgement response
			if (response && typeof response === 'object' && response.response?.result === 'error') {
				console.error(`Server returned error for post_app_data ${action}/${type}:`, response.response.message);
				reject(new Error(response.response.message || `Server error for post_app_data ${action}/${type}`));
			} else if (response && response.response?.result === 'success') {
                // Successfully received ack with expected structure
				console.log(`postAppData successful ack for ${action}/${type}:`, response);
				resolve(response); // Resolve with the full success response object
			} else {
				// Server acknowledged, but sent no data or an unexpected format
				console.error(`postAppData ${action}/${type} received unexpected acknowledgement format:`, response);
				reject(new Error(`Server responded unsuccessfully or with unexpected format for post_app_data ${action}/${type}`));
			}
		});
	});
}


// --- Application Specific Actions (Example using postAppData) ---

/**
 * Example: Set the mode using WebSocket by emitting 'post_app_data'
 * @param {string} mode - The mode to set (e.g., 'Prime', 'Cook').
 * @param {number|null} [primeAmount=null] - Amount for 'Prime' mode.
 * @param {string|null} [nextMode=null] - Next mode after 'Prime'.
 */
export function setMode(mode, primeAmount = null, nextMode = null) {
    const payload = {
        updated: true, // Assuming server needs this flag
        mode: mode,
    };

    // Conditionally add properties for 'Prime' mode
    if (mode === 'Prime' && primeAmount !== null && nextMode) {
        payload.prime_amount = primeAmount;
        payload.next_mode = nextMode;
    }

    // Use the generic postAppData function
    postAppData('update_action', 'control', payload)
        .then(response => {
            console.log(`Set mode to ${mode} successful:`, response);
            // Maybe trigger dashboard data refresh or rely on push updates
            // emitEvent('get_dash_data', { force: true });
        })
        .catch(error => {
            console.error(`Failed to set mode to ${mode}:`, error);
            // Handle error in UI if needed
        });
}