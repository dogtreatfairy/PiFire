// src/lib/stores/uiStore.js
import { writable } from 'svelte/store';
import { socket } from '$lib/socketClient';

console.log("Initializing uiStore with SocketIO...");

const SOCKET_EVENT_GET_UI_SETTINGS = 'get_ui_settings';
const SOCKET_EVENT_RECEIVE_UI_SETTINGS = 'ui_settings_data';
const SOCKET_EVENT_SAVE_UI_SETTINGS = 'save_ui_settings';

const uiSettings = writable(null);

function setupSocketListeners() {
    if (!socket) {
        console.error("Socket not available. Cannot set up listeners.");
        return;
    }

    socket.on(SOCKET_EVENT_RECEIVE_UI_SETTINGS, (settings) => {
        console.log(`Persistent ${SOCKET_EVENT_RECEIVE_UI_SETTINGS} received:`, settings);
        const transformedSettings = {
            ...settings,
            cardOrder: settings.cardPositions || settings.cardOrder || []
        };
        uiSettings.set(transformedSettings);
    });

    socket.on('connect', () => {
        console.log("Socket reconnected. Refetching UI settings...");
        fetchUiSettings();
    });
}

setupSocketListeners();

async function fetchUiSettings() {
    console.log(`Emitting ${SOCKET_EVENT_GET_UI_SETTINGS} via SocketIO...`);
    if (!socket || !socket.connected) {
        console.error("Socket not connected or available. Cannot fetch UI settings.");
        uiSettings.set({});
        return;
    }

    try {
        socket.emit(SOCKET_EVENT_GET_UI_SETTINGS);
    } catch (error) {
        console.error(`Error emitting ${SOCKET_EVENT_GET_UI_SETTINGS}:`, error);
        uiSettings.set({});
    }
}

async function saveCardOrder(newCardOrder) {
    console.log("Attempting to save new card order via SocketIO:", newCardOrder);

    if (!socket || !socket.connected) {
        console.error("Socket not connected or available. Cannot save UI settings.");
        return;
    }

    let currentSettings = {};
    const unsubscribe = uiSettings.subscribe(value => {
        currentSettings = value || {};
    });
    unsubscribe();

    const updatedSettings = {
        ...currentSettings,
        cardOrder: newCardOrder
    };

    try {
        console.log(`Emitting ${SOCKET_EVENT_SAVE_UI_SETTINGS} with data:`, updatedSettings);
        socket.emit(SOCKET_EVENT_SAVE_UI_SETTINGS, updatedSettings);
        uiSettings.set(updatedSettings);
        console.log("Card order sent to server via SocketIO. Local store updated optimistically.");
    } catch (error) {
        console.error(`Error emitting ${SOCKET_EVENT_SAVE_UI_SETTINGS}:`, error);
    }
}

export {
    uiSettings,
    fetchUiSettings,
    saveCardOrder
};