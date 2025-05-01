// src/lib/stores/uiStore.js
import { writable } from 'svelte/store';
// IMPORTANT: Import your configured SocketIO client instance
// This might come from context, another store, or a global export
// Example: import { socket } from '$lib/socketClient'; // Adjust path as needed
// For this example, we'll assume 'socket' is available globally or imported.
// If not, you'll need to pass it into the functions or make it accessible.
import { socket } from '$lib/socketClient'; // <--- MAKE SURE THIS PATH IS CORRECT

console.log("Initializing uiStore with SocketIO...");

// --- Event Names (Match these in your Flask backend) ---
const SOCKET_EVENT_GET_UI_SETTINGS = 'get_ui_settings';
const SOCKET_EVENT_RECEIVE_UI_SETTINGS = 'ui_settings_data'; // Event backend emits with data
const SOCKET_EVENT_SAVE_UI_SETTINGS = 'save_ui_settings';

// --- Store Definition ---
// Initialize with null - indicates settings haven't been loaded yet.
const uiSettings = writable(null);

// --- Store Actions ---

/**
 * Fetches UI settings via SocketIO and updates the store.
 */
async function fetchUiSettings() {
    console.log(`Emitting ${SOCKET_EVENT_GET_UI_SETTINGS} via SocketIO...`);
    if (!socket || !socket.connected) {
        console.error("Socket not connected or available. Cannot fetch UI settings.");
        // Set to empty object to prevent hanging, but log error
        uiSettings.set({});
        return;
    }

    try {
        // Emit event to request settings from backend
        socket.emit(SOCKET_EVENT_GET_UI_SETTINGS);

        // Set up a one-time listener for the response from the backend
        // Important: Handle potential race conditions or multiple calls if necessary
        socket.once(SOCKET_EVENT_RECEIVE_UI_SETTINGS, (settings) => {
            console.log(`${SOCKET_EVENT_RECEIVE_UI_SETTINGS} received:`, settings);
            // Update the store with received data or empty object
            uiSettings.set(settings || {});
        });

        // Optional: Add a timeout listener in case the backend doesn't respond
        const timeout = setTimeout(() => {
            console.warn(`Timeout waiting for ${SOCKET_EVENT_RECEIVE_UI_SETTINGS}. Setting default.`);
             // Check if store is still null before setting default
             let currentValue;
             const unsub = uiSettings.subscribe(v => currentValue = v);
             unsub();
             if (currentValue === null) {
                 uiSettings.set({});
             }
             // Remove the primary listener if timeout occurs
             socket.off(SOCKET_EVENT_RECEIVE_UI_SETTINGS);
        }, 5000); // 5 second timeout (adjust as needed)

        // Clean up timeout when data is received
         socket.once(SOCKET_EVENT_RECEIVE_UI_SETTINGS, () => clearTimeout(timeout));


    } catch (error) {
        console.error(`Error emitting ${SOCKET_EVENT_GET_UI_SETTINGS}:`, error);
        // Set to empty object on failure
        uiSettings.set({});
    }
}

/**
 * Saves the provided card positions map via SocketIO.
 * Merges the new positions map with existing settings before saving.
 * @param {Object.<string, number>} newPositions - Object mapping card IDs to their 1-based positions.
 */
async function saveCardOrder(newPositions) {
    console.log("Attempting to save new card positions via SocketIO:", newPositions);

    if (!socket || !socket.connected) {
        console.error("Socket not connected or available. Cannot save UI settings.");
        // Optionally notify user of failure
        return; // Don't proceed if socket isn't ready
    }

    // Get the current full settings state to merge with
    let currentSettings = {};
    const unsubscribe = uiSettings.subscribe(value => {
        currentSettings = value || {};
    });
    unsubscribe();

    // Prepare the updated settings object
    const updatedSettings = {
        ...currentSettings,
        cardPositions: newPositions
    };

    try {
        // Emit the entire updated settings object to the backend
        console.log(`Emitting ${SOCKET_EVENT_SAVE_UI_SETTINGS} with data:`, updatedSettings);
        socket.emit(SOCKET_EVENT_SAVE_UI_SETTINGS, updatedSettings);

        // Optimistic UI Update: Update the local store immediately.
        // The backend should handle the actual persistence.
        // If save fails, the next fetch will revert, or you could implement error handling.
        uiSettings.set(updatedSettings);
        console.log("Card positions sent to server via SocketIO. Local store updated optimistically.");

        // Optional: Listen for a success/failure confirmation from the backend if needed

    } catch (error) {
        console.error(`Error emitting ${SOCKET_EVENT_SAVE_UI_SETTINGS}:`, error);
        // Handle error (e.g., show notification)
    }
}

// --- Exports ---
export {
    uiSettings,
    fetchUiSettings,
    saveCardOrder
};

// --- Socket Listener Setup ---
// It's crucial that the listener for SOCKET_EVENT_RECEIVE_UI_SETTINGS
// is set up *before* fetchUiSettings might be called, especially on reconnects.
// Often, socket event listeners are set up once when the socket connects.
// If your socket connection logic is elsewhere (e.g., layout), ensure
// it handles setting up listeners appropriately.
// The fetchUiSettings function above uses socket.once for the initial fetch response.
// If settings can be pushed from the server later, you'd need a persistent socket.on listener.
