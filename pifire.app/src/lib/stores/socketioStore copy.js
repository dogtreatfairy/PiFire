import { writable, get } from 'svelte/store';
import { io } from 'socket.io-client';

export const isConnected = writable(false);
export const socketStatus = writable('Disconnected');
export const serverAddress = writable('http://localhost');
export const serverPort = writable('8000');
export const controlData = writable({});
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

        // Request initial data
        emitEvent('get_dash_data', { force: true });
        requestSettings();
        requestPelletsData();
    });

    currentSocket.on('disconnect', (reason) => {
        console.log(`Socket disconnected. Reason: ${reason}`);
        isConnected.set(false);
        socketStatus.set('Disconnected');
        uiSettings.set({});
    });

    currentSocket.on('connect_error', (error) => {
        console.error('Socket connection error:', error.message);
        isConnected.set(false);
        socketStatus.set('Error');
        uiSettings.set({});
    });

    currentSocket.on('grill_control_data', (data) => {
        controlData.set(data);
    });

    currentSocket.on('settings_data', (fullSettings) => {
        console.log("Received broadcasted 'settings_data':", fullSettings);
        settingsData.set(fullSettings || {});
        const dashSettings = fullSettings?.webui?.dash || {};
        console.log("Updating uiSettings store:", dashSettings);
        uiSettings.set(dashSettings);
    });

    currentSocket.on('control_data', (controlData) => {
        console.log("Received broadcasted 'control_data':", controlData);
        controlData.set(controlData || {});
    });

    currentSocket.on('pellets_data', (pelletsData) => {
        console.log("Received broadcasted 'pellets_data':", pelletsData);
        pelletsData.set(pelletsData || {});
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
    currentSocket.off('settings_data');
    currentSocket.off('control_data');
    currentSocket.off('pellets_data');
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
        uiSettings.set({});
    }
}

/**
 * Switches the connection to a new server, clears local stores, and reconnects.
 * @param {string} newAddress - Base address (e.g., 'http://192.168.1.100').
 * @param {string} [newPort] - Optional port.
 */
export function switchServer(newAddress, newPort) {
    console.log(`Switching server to ${newAddress}:${newPort || get(serverPort)}`);
    disconnectSocket();

    controlData.set({});
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
    if (typeof window !== 'undefined') {
        localStorage.setItem('serverAddress', newAddress);
    }
    setTimeout(_connectInternal, 100);
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
 * Emit an event and wait for an acknowledgement.
 * @param {string} eventName - The event name to emit.
 * @param {object} data - The data payload to send.
 * @param {number} [timeoutMs=5000] - Timeout duration in milliseconds.
 * @returns {Promise<object>} Resolves with response data or rejects on error/timeout.
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
            clearTimeout(timer);
            if (timedOut) return;

            if (response && typeof response === 'object' && response.response?.result === 'error') {
                console.error(`Server returned error for ${eventName}:`, response.response.message);
                reject(new Error(response.response.message || `Server error for ${eventName}`));
            } else if (response !== undefined && response !== null) {
                resolve(response);
            } else {
                console.error(`Failed to retrieve data for ${eventName} (server responded empty/unexpected). Response:`, response);
                reject(new Error(`Server responded unsuccessfully or with unexpected format for ${eventName}`));
            }
        });
    });
}

/**
 * Sends data to the server's 'post_app_data' handler.
 * @param {string} action - The action type (e.g., 'control', 'manual', 'settings').
 * @param {object|string} data - The data payload (object for most actions, string component for 'manual').
 * @param {any} [value=null] - The value for 'manual' action (e.g., true/false).
 * @param {number} [timeoutMs=5000] - Timeout duration in milliseconds.
 * @returns {Promise<object>} Server response.
 */
export async function postAppData(action, data, value = null, timeoutMs = 5000) {
    if (!action) {
        console.error("postAppData requires 'action' argument.");
        return Promise.reject(new Error("postAppData requires 'action' argument."));
    }

    let emitArgs;
    if (action === 'manual') {
        if (typeof data !== 'string' || (value === null && value !== 'toggle')) {
            console.error("For 'manual' action, data must be a string (component) and value must be true, false, or 'toggle'.");
            return Promise.reject(new Error("Invalid arguments for 'manual' action."));
        }
        emitArgs = [action, data, value];
    } else {
        const jsonPayloadString = JSON.stringify(data || {});
        emitArgs = [action, jsonPayloadString];
    }

    console.log(`Posting App Data - Action: ${action}, Data:`, data, value !== null ? `Value: ${value}` : '');

    return new Promise((resolve, reject) => {
        if (!socket || !socket.connected) {
            console.error(`Cannot postAppData ${action}: Socket is not connected.`);
            return reject(new Error('Socket is not connected'));
        }

        let timedOut = false;
        const timer = setTimeout(() => {
            timedOut = true;
            console.error(`Timeout waiting for acknowledgement for post_app_data ${action}.`);
            reject(new Error(`Timeout waiting for post_app_data ${action} response`));
        }, timeoutMs);

        socket.emit('post_app_data', ...emitArgs, (response) => {
            clearTimeout(timer);
            if (timedOut) return;

            if (response && typeof response === 'object' && response.response?.result === 'error') {
                console.error(`Server returned error for post_app_data ${action}:`, response.response.message);
                reject(new Error(response.response.message || `Server error for post_app_data ${action}`));
            } else if (response && typeof response === 'object' && response.response?.result === 'success') {
                console.log(`postAppData successful for ${action}:`, response);
                resolve(response);
            } else {
                console.error(`postAppData ${action} received unexpected acknowledgement format:`, response);
                reject(new Error(`Server responded unsuccessfully or with unexpected format for post_app_data ${action}`));
            }
        });
    });
}

// --- Application Specific Actions ---

/**
 * Sets the control mode.
 * @param {string} mode - The mode to set (e.g., 'Prime', 'Cook').
 * @param {number|null} [primeAmount=null] - Amount for 'Prime' mode.
 * @param {string|null} [nextMode=null] - Next mode after 'Prime'.
 */
export async function setMode(mode, primeAmount = null, nextMode = null) {
    const payload = {
        updated: true,
        mode: mode
    };
    if (mode === 'Prime' && primeAmount !== null && nextMode) {
        payload.prime_amount = primeAmount;
        payload.next_mode = nextMode;
    }
    return postAppData('control', payload);
}

/**
 * Saves the card order as an array.
 * @param {string[]} cardOrder - Array of card IDs.
 */
export async function saveCardOrder(cardOrder) {
    console.log("Saving card order:", cardOrder);
    return postAppData('settings', { webui: { dash: { cardOrder } } });
}

// --- Functions to Request Specific Data ---

export async function requestSettings() {
    console.log("Requesting Settings Data...");
    try {
        const response = await _emitWithAck('get_app_data', { action: 'settings_data' });
        console.log("Received Full Settings:", response);
        const fullSettings = response || {};
        settingsData.set(fullSettings);
        const dashSettings = fullSettings?.webui?.dash || {};
        console.log("Updating uiSettings store:", dashSettings);
        uiSettings.set(dashSettings);
        return fullSettings;
    } catch (error) {
        console.error("Failed to request settings data:", error);
        settingsData.set({});
        uiSettings.set({});
        throw error;
    }
}

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

export async function requestcontrolData() {
    try {
        const response = await _emitWithAck('get_app_data', { action: 'grill_control_data' });
        controlData.set(response || {});
        return response;
    } catch (error) {
        console.error("Failed to request grill control data:", error);
        controlData.set({});
        throw error;
    }
}