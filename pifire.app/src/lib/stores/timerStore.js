import { writable } from 'svelte/store';

function createPersistentStore(key, initialValue) {
    // Try to read the initial value from localStorage
    let storedValue;
    try {
        storedValue = localStorage.getItem(key);
    } catch (e) {
        // In case localStorage is unavailable, fallback to initialValue
    }
    
    // If storedValue is null or the literal string "undefined", ignore it.
    if (!storedValue || storedValue === "undefined") {
        storedValue = null;
    }
    
    const data = storedValue !== null ? JSON.parse(storedValue) : initialValue;
    const store = writable(data);

    store.subscribe((value) => {
        try {
            localStorage.setItem(key, JSON.stringify(value));
        } catch (e) {
            console.error("Failed to write to localStorage", e);
        }
    });

    return store;
}

// Replace timerFinishedFlag variable with a persistent Svelte store.
export const timerFinishedFlag = createPersistentStore('timerFinishedFlag', false);