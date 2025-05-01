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
export const pelletsData = writable({});
export const eventsData = writable({});
export const infoData = writable({});
export const manualData = writable({});
// *** NEW: Store for UI Settings ***
export const uiSettings = writable(null); // Initialize as null (not loaded yet)

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

        // Request initial data upon successful connection
        emitEvent('get_dash_data', { force: true });
        requestSettings();
        requestPelletsData();
        requestUiSettings(); // *** NEW: Request UI settings on connect ***
    });

    currentSocket.on('disconnect', (reason) => {
        console.log(`Socket disconnected. Reason: ${reason}`);
        isConnected.set(false);
        socketStatus.set('Disconnected');
        // Clear stores on disconnect? Optional, depends on desired behavior.
        // settingsData.set({});
        // uiSettings.set(null); // Reset to null on disconnect
    });

    currentSocket.on('connect_error', (error) => {
        console.error('Socket connection error:', error.message);
        isConnected.set(false);
        socketStatus.set('Error');
        // uiSettings.set(null); // Reset to null on connection error
    });

    // Listener for continuous dashboard updates
    currentSocket.on('grill_control_data', (data) => {
        grillControlData.set(data);
    });

    // *** NEW: Listener for broadcasted UI settings updates (Optional) ***
    // This handles updates pushed from the server after *another* client saved changes.
    currentSocket.on('ui_settings_data', (settings) => {
        console.log("Received broadcasted 'ui_settings_data':", settings);
        uiSettings.set(settings || {}); // Update store with pushed data
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
    currentSocket.off('ui_settings_data'); // *** NEW: Remove UI settings listener ***
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

    // Reset uiSettings to null when attempting new connection
    uiSettings.set(null);

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
        uiSettings.set(null); // Reset UI settings on manual disconnect
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
    uiSettings.set(null); // *** NEW: Clear UI settings store ***
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

/** Requests settings_data and updates the settingsData store. */
export async function requestSettings() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'settings_data' });
        settingsData.set(response || {}); // Ensure store gets an object
        return response;
    } catch (error) {
        console.error("Failed to request settings data:", error);
        settingsData.set({}); // Set to empty on error
        throw error;
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

// *** NEW: Function to request UI settings ***
/** Requests ui_settings and updates the uiSettings store. */
export async function requestUiSettings() {
    console.log("Requesting UI Settings...");
    try {
        // Assuming backend 'get_app_data' handles { action: 'ui_settings' }
        const response = await _emitWithAck('get_app_data', { action: 'ui_settings' });
        console.log("Received UI Settings:", response);
        // Set store to received object or empty object if null/undefined
        uiSettings.set(response || {});
        return response;
    } catch (error) {
        console.error("Failed to request UI settings:", error);
        // Set store to empty object on error to prevent hanging on null
        uiSettings.set({});
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
export async function postAppData(action, type, payload = {}, timeoutMs = 5000) {
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

// *** NEW: Function to save UI settings (including card positions) ***
/**
 * Saves the entire UI settings object to the backend.
 * It's expected that the object passed contains the merged cardPositions.
 * @param {object} settingsToSave - The complete UI settings object to save.
 */
export async function saveUiSettings(settingsToSave) {
    console.log("Saving UI Settings:", settingsToSave);
    if (typeof settingsToSave !== 'object' || settingsToSave === null) {
        console.error("Invalid data provided to saveUiSettings. Expected an object.");
        return Promise.reject(new Error("Invalid data for saveUiSettings"));
    }
    try {
        // Use postAppData assuming backend handles { action: 'update_action', type: 'ui_settings' }
        const response = await postAppData('update_action', 'ui_settings', settingsToSave);
        console.log("Save UI Settings successful:", response);
        // Optimistic update: Update local store immediately after sending
        // Note: If save fails, store might be out of sync until next fetch or refresh
        uiSettings.set(settingsToSave);
        return response;
    } catch (error) {
        console.error("Failed to save UI settings:", error);
        // Handle error in UI if needed
        throw error; // Re-throw for calling code
    }
}

/**
 * Saves just the card positions by merging them into the current UI settings.
 * @param {Object.<string, number>} newPositions - Object mapping card IDs to their 1-based positions.
 */
export async function saveCardPositions(newPositions) {
    console.log("Attempting to save new card positions:", newPositions);

    // Get the current full settings state to merge with
    const currentSettings = get(uiSettings) || {}; // Use current value or empty object

    // Prepare the updated settings object
    const updatedSettings = {
        ...currentSettings,         // Keep existing settings
        cardPositions: newPositions // Update/add the card positions map
    };

    // Call the function to save the entire updated object
    return saveUiSettings(updatedSettings);
}
