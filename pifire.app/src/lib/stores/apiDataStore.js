import { writable, get } from 'svelte/store';
import { io } from 'socket.io-client';

export const isConnected = writable(false);
export const socketStatus = writable('Disconnected');
export const serverAddress = writable('http://localhost');
export const serverPort = writable('8000');
export const grillControlData = writable({});

export const settingsData = writable({});
export const pelletsData = writable({});
export const eventsData = writable({});
export const infoData = writable({});
export const manualData = writable({});
export const uiSettings = writable({}); 

let socket = null;

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

        // Request initial data upon successful connection
        emitEvent('get_dash_data', { force: true });
        requestSettings(); // This will now also populate uiSettings store
        requestPelletsData();
    });

    currentSocket.on('disconnect', (reason) => {
        console.log(`Socket disconnected. Reason: ${reason}`);
        isConnected.set(false);
        socketStatus.set('Disconnected');
        // Clear stores on disconnect? Optional.
        // settingsData.set({});
        uiSettings.set({}); // Reset to empty on disconnect
    });

    currentSocket.on('connect_error', (error) => {
        console.error('Socket connection error:', error.message);
        isConnected.set(false);
        socketStatus.set('Error');
        uiSettings.set({}); // Reset to empty on connection error
    });

    // Listener for continuous dashboard updates
    currentSocket.on('grill_control_data', (data) => {
        grillControlData.set(data);
    });

    // *** MODIFIED: Listener for broadcasted *main* settings updates ***
    // This handles updates pushed from the server after *any* client saved settings.
    currentSocket.on('settings_data', (fullSettings) => {
        console.log("Received broadcasted 'settings_data':", fullSettings);
        // Update the main settings store
        settingsData.set(fullSettings || {});
        // Extract the relevant part for the uiSettings store
        const dashSettings = fullSettings?.webui?.dash || {};
        console.log("Updating uiSettings store from broadcast:", dashSettings);
        uiSettings.set(dashSettings);
    });
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
    currentSocket.off('settings_data'); // *** MODIFIED: Listen for main settings ***
    currentSocket.off('control_data');
    // REMOVED: currentSocket.off('ui_settings_data');
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

    // Reset uiSettings to empty object when attempting new connection
    uiSettings.set({});

    socket = io(address, {
        reconnection: true,
    });

    _attachListeners(socket);
}

// --- Public API ---

/** Initializes the socket connection based on saved or default address. */
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

/** Disconnects the socket and cleans up listeners. */
export function disconnectSocket() {
    if (socket) {
        console.log('Disconnecting socket...');
        _removeListeners(socket);
        socket.disconnect();
        socket = null;
        isConnected.set(false);
        socketStatus.set('Disconnected');
        uiSettings.set({}); // Reset UI settings on manual disconnect
    }
}

/**
 * Switches the connection to a new server, clears local stores, and reconnects.
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
    uiSettings.set({});
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
 * Generic function to emit an event to the server without waiting for ACK.
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
    // ... (_emitWithAck logic remains the same) ...
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
            } else if (response !== undefined && response !== null) { // Allow empty objects/arrays as valid responses
                 // console.log(`Received ack for ${eventName}:`, response); // Optional log
                 resolve(response);
            } else {
                 // Server acknowledged, but sent no data or an unexpected format
                 console.error(`Failed to retrieve data for ${eventName} (server responded empty/unexpected). Response:`, response);
                 reject(new Error(`Server responded unsuccessfully or with unexpected format for ${eventName}`));
            }
        });
    });
}


// --- Functions to Request Specific Data (using get_app_data) ---

/** Requests settings_data and updates the settingsData and uiSettings stores. */
export async function requestSettings() {
    console.log("Requesting Settings Data (including UI)...");
    try {
        const response = await _emitWithAck('get_app_data', { action: 'settings_data' });
        console.log("Received Full Settings:", response);
        const fullSettings = response || {};
        // Update the main settings store
        settingsData.set(fullSettings);
        // Extract the relevant part for the uiSettings store
        const dashSettings = fullSettings?.webui?.dash || {};
        console.log("Updating uiSettings store from fetch:", dashSettings);
        uiSettings.set(dashSettings);
        return fullSettings; // Return full data for potential chaining/direct use
    } catch (error) {
        console.error("Failed to request settings data:", error);
        settingsData.set({}); // Set to empty on error
        uiSettings.set({});   // Set UI to empty on error
        throw error; // Re-throw error for calling code to handle
    }
}

/** Requests pellets_data and updates the pelletsData store. */
export async function requestPelletsData() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'pellets_data' });
        pelletsData.set(response || {});
        return response;
    } catch (error) {
        console.error("Failed to request pellets data:", error);
        pelletsData.set({});
        throw error;
    }
}

/** Requests events_data and updates the eventsData store. */
export async function requestEventsData() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'events_data' });
        eventsData.set(response || {});
        return response;
    } catch (error) {
        console.error("Failed to request events data:", error);
        eventsData.set({});
        throw error;
    }
}

/** Requests info_data and updates the infoData store. */
export async function requestInfoData() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'info_data' });
        infoData.set(response || {});
        return response;
    } catch (error) {
        console.error("Failed to request info data:", error);
        infoData.set({});
        throw error;
    }
}

/** Requests manual_data and updates the manualData store. */
export async function requestManualData() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'manual_data' });
        manualData.set(response || {});
        return response;
    } catch (error) {
        console.error("Failed to request manual data:", error);
        manualData.set({});
        throw error;
    }
}

/** Requests grill_control_data and updates the grillControlData store. */
export async function requestGrillControlData() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'grill_control_data' });
        grillControlData.set(response || {});
        return response;
    } catch (error) {
        console.error("Failed to request grill control data:", error);
        grillControlData.set({});
        throw error;
    }
}

/**
 * Sends data to the server's 'post_app_data' handler.
 * Automatically stringifies the payload for the 'json_data' field.
 * @param {string} action - The action type (e.g., 'update_action', 'admin_action').
 * @param {string} type - The specific type within the action (e.g., 'settings', 'control', 'reboot').
 * @param {object} payload - The JavaScript object to be sent as JSON data.
 * @param {number} [timeoutMs=5000] - Timeout duration in milliseconds.
 * @returns {Promise<object>} A promise resolving with the server's acknowledgement response.
 */
export async function postAppData(action, type, payload = {}, timeoutMs = 5000) {
    // ... (postAppData logic remains the same) ...
    if (!action || !type) {
        console.error("postAppData requires 'action' and 'type' arguments.");
        return Promise.reject(new Error("postAppData requires 'action' and 'type' arguments."));
    }

    const jsonPayloadString = JSON.stringify(payload);
    console.log(`Posting App Data - Action: ${action}, Type: ${type}, Payload Object:`, payload);

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
            clearTimeout(timer);
            if (timedOut) return;

            console.log(`postAppData raw response for ${action}/${type}:`, response);

            if (response && typeof response === 'object' && response.response?.result === 'error') {
                console.error(`Server returned error for post_app_data ${action}/${type}:`, response.response.message);
                reject(new Error(response.response.message || `Server error for post_app_data ${action}/${type}`));
            } else if (response && response.response?.result === 'success') {
                console.log(`postAppData successful ack for ${action}/${type}:`, response);
                resolve(response);
            } else {
                console.error(`postAppData ${action}/${type} received unexpected acknowledgement format:`, response);
                reject(new Error(`Server responded unsuccessfully or with unexpected format for post_app_data ${action}/${type}`));
            }
        });
    });
}


// --- Application Specific Actions ---

/**
 * Example: Set the mode using WebSocket by emitting 'post_app_data'
 * @param {string} mode - The mode to set (e.g., 'Prime', 'Cook').
 * @param {number|null} [primeAmount=null] - Amount for 'Prime' mode.
 * @param {string|null} [nextMode=null] - Next mode after 'Prime'.
 */
export function setMode(mode, primeAmount = null, nextMode = null) {
    // ... (setMode logic remains the same) ...
    const payload = {
        updated: true,
        mode: mode,
    };
    if (mode === 'Prime' && primeAmount !== null && nextMode) {
        payload.prime_amount = primeAmount;
        payload.next_mode = nextMode;
    }
    postAppData('update_action', 'control', payload)
        .then(response => {
            console.log(`Set mode to ${mode} successful:`, response);
        })
        .catch(error => {
            console.error(`Failed to set mode to ${mode}:`, error);
        });
}

// REMOVED: saveUiSettings() function

/**
 * Saves just the card positions by sending a structured update payload.
 * @param {Object.<string, number>} newPositions - Object mapping card IDs to their 1-based positions.
 */
export async function saveCardPositions(newPositions) {
    console.log("Formatting payload to save new card positions:", newPositions);

    // Construct the specific payload structure the backend expects
    const payload = {
        webui: {
            dash: {
                cardPositions: newPositions // Send the {'id': position} map
            }
        }
    };

    try {
        // Call postAppData to update the main settings file
        const response = await postAppData('update_action', 'settings', payload);
        console.log("Save Card Positions successful:", response);
        // No optimistic update here - rely on backend broadcast via 'settings_data' event
        return response;
    } catch (error) {
        console.error("Failed to save card positions:", error);
        // Handle error in UI if needed
        throw error; // Re-throw for calling code
    }
}
