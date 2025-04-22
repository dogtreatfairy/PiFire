/**
 * socketService.js - Svelte Store-based Socket.IO Client Service (Plain JavaScript)
 *
 * Provides a service for managing a Socket.IO connection using Svelte stores.
 *
 * Usage in a Svelte component:
 *
 * import { onMount, onDestroy } from 'svelte';
 * import {
 * initializeSocket,
 * disconnectSocket, // Optional cleanup
 * isConnected,      // Import stores and functions needed
 * socketStatus,
 * grillControlData,
 * switchServer,
 * setMode
 * } from './socketService'; // Adjust path
 *
 * onMount(() => {
 * initializeSocket(); // Connect when component mounts (client-side)
 *
 * // Optional: Disconnect when component is destroyed
 * // return () => {
 * //   disconnectSocket();
 * // };
 * });
 *
 * // In the template, use $storeName for reactivity:
 * // <p>Status: {$socketStatus}</p>
 * // {#if $isConnected} ... {/if}
 *
 */
import { writable, get } from 'svelte/store';
import { io } from 'socket.io-client'; // Client library

// --- Svelte Stores for Reactive State ---
export const isConnected = writable(false);
export const socketStatus = writable('Disconnected');
export const serverAddress = writable('http://localhost');
export const serverPort = writable('8000');
export const settingsData = writable({});
export const grillControlData = writable({});

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
        emitEvent('get_dash_data', { force: true });
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

    currentSocket.on('grill_control_data', (data) => {
        grillControlData.set(data);
    });
    // Add other listeners here...
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

// --- Public API Functions (Service Interface) ---

/**
 * Initializes the WebSocket connection. Call from onMount in Svelte.
 */
export function initializeSocket() {
    if (typeof window !== 'undefined') { // Client-side check
        const savedAddress = localStorage.getItem('serverAddress');
        if (savedAddress) {
            serverAddress.set(savedAddress);
        }
        _connectInternal();
    } else {
        console.warn("Socket initialization skipped: Not running in a browser environment.");
    }
}

/**
 * Disconnects the current WebSocket connection cleanly.
 */
export function disconnectSocket() {
    if (socket) {
        console.log('Disconnecting socket...');
        _removeListeners(socket);
        socket.disconnect();
        socket = null;
        isConnected.set(false);
        socketStatus.set('Disconnected');
        // Optionally clear data stores
        // grillControlData.set({});
        // settingsData.set({});
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
    grillControlData.set({}); // Clear old data
    settingsData.set({});     // Clear old data
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
 * Emits an event to the connected socket server.
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
 * Requests settings data using an event with acknowledgement.
 * @returns {Promise<object>} Promise resolving with settings data.
 */
export async function requestSettings() {
    // Using async/await for cleaner promise handling (still standard JS)
    return new Promise((resolve, reject) => {
        if (!socket || !socket.connected) {
            return reject(new Error('Socket is not connected'));
        }
        const timeout = 5000; // ms
        let timedOut = false;
        const timer = setTimeout(() => {
            timedOut = true;
            reject(new Error('Timeout waiting for settings data response'));
        }, timeout);

        socket.emit('get_app_data', { action: 'settings_data' }, (response) => {
            clearTimeout(timer);
            if (timedOut) return;
            if (response) {
                settingsData.set(response); // Update store
                resolve(response);
            } else {
                reject(new Error('Server responded unsuccessfully for settings data'));
            }
        });
    });
}

// --- Application Specific Actions ---

/**
 * Example: Set the mode via WebSocket.
 * @param {string} mode
 * @param {number|null} [primeAmount=null]
 * @param {string|null} [nextMode=null]
 */
export function setMode(mode, primeAmount = null, nextMode = null) {
    const postdata = { updated: true, mode: mode };
    if (mode === 'Prime' && primeAmount !== null && nextMode) {
        postdata.prime_amount = primeAmount;
        postdata.next_mode = nextMode;
    }
    emitEvent('post_app_data', {
        action: 'update_action',
        type: 'control',
        json_data: JSON.stringify(postdata) // Assuming server expects stringified JSON
    });
}