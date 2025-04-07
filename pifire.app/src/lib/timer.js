import { writable } from 'svelte/store';

// API Variables
let timerPaused = 0;
let timerEnd = 0;
let timerExpired = false;
let remainingSeconds = 0;

// Svelte stores for reactive values
export const timerStatus = writable('stopped'); // Timer status: stopped, running, paused, expired
export const timerDisplay = writable("--:--:--");

// Real-time update loop
let intervalId = null;
function startTimerLoop() {
    if (intervalId) return; // Prevent multiple intervals
    intervalId = setInterval(() => {
        computeTime(); // Update remaining time
        computeMode(); // Update status (triggers 'expired' when needed)
        computeDisplay(); // Update display
    }, 1000);
}

function stopTimerLoop() {
    if (intervalId) {
        clearInterval(intervalId);
        intervalId = null;
    }
}

// Fetch timer data from API
export async function timerUpdate() {
    try {
        const response = await fetch('/api/get/timer', { method: 'GET' });
        if (!response.ok) {
            throw new Error(`Failed to fetch timer data: ${response.statusText}`);
        }

        const { data: apiTimerData } = await response.json();

        timerPaused = apiTimerData.paused;
        timerEnd = apiTimerData.end;
        timerExpired = apiTimerData.expired;

        computeTime(); // Ensure remainingSeconds is up-to-date
        computeMode();
        computeDisplay();

        // Start/stop the loop based on timer state
        if (timerEnd > 0 && !timerExpired) {
            startTimerLoop();
        } else {
            stopTimerLoop();
        }
    } catch (error) {
        console.error('Error updating timer:', error);
    }
}

function computeTime() {
    if (timerPaused > 0) {
        // Use paused time as the reference point
        remainingSeconds = Math.floor(timerEnd - timerPaused);
    } else if (timerEnd > 0) {
        // Calculate remaining seconds using current time
        remainingSeconds = Math.floor(timerEnd - Date.now() / 1000);
    } else {
        remainingSeconds = 0;
    }
    if (remainingSeconds <= 0 && timerEnd > 0) {
        // Locally detect expiration if timer has run out
        timerExpired = true;
    }
    return remainingSeconds;
}

function computeMode() {
    if (timerExpired) {
        timerStatus.set('expired');
        stopTimerLoop(); // Stop the loop when expired
    } else if (timerEnd === 0) {
        timerStatus.set('stopped');
        stopTimerLoop();
    } else if (timerPaused === 0) {
        timerStatus.set('running');
    } else {
        timerStatus.set('paused');
    }
}

export function computeDisplay() {
    if (timerExpired) {
        timerDisplay.set("ALARM");
    } else if (timerEnd === 0) {
        timerDisplay.set("--:--:--");
    } else {
        const hours = Math.floor(remainingSeconds / 3600);
        const minutes = Math.floor((remainingSeconds % 3600) / 60);
        const seconds = remainingSeconds % 60;
        const tdHrs = String(hours).padStart(2, '0');
        const tdMins = String(minutes).padStart(2, '0');
        const tdSecs = String(seconds).padStart(2, '0');
        const displayValue = `${tdHrs}:${tdMins}:${tdSecs}`;
        timerDisplay.set(displayValue);
    }
}

// Control functions
export async function timerPause() {
    try {
        const response = await fetch('/api/set/timer/pause', { method: 'POST' });
        if (!response.ok) throw new Error(`Pause failed: ${response.statusText}`);
        await timerUpdate();
    } catch (err) {
        console.error('Pause error:', err.message);
    }
}

export async function timerUnpause() {
    try {
        const response = await fetch('/api/set/timer/start', { method: 'POST' });
        if (!response.ok) throw new Error(`Unpause failed: ${response.statusText}`);
        await timerUpdate();
    } catch (err) {
        console.error('Unpause error:', err.message);
    }
}

export async function timerStop() {
    try {
        const response = await fetch('/api/set/timer/stop', { method: 'POST' });
        if (!response.ok) throw new Error(`Stop failed: ${response.statusText}`);
        await timerUpdate();
    } catch (err) {
        console.error('Stop error:', err.message);
    }
}

export async function timerLaunch(hours, minutes, modalTimer, setError) {
    const totalSeconds = (parseInt(hours) || 0) * 3600 + (parseInt(minutes) || 0) * 60;

    if (totalSeconds <= 0) {
        setError('ERROR: Please set a valid time.');
        return;
    }

    try {
        const response = await fetch(`/api/set/timer/start/${totalSeconds}`, { method: 'POST' });
        if (!response.ok) {
            throw new Error(`Failed to start timer: ${response.statusText}`);
        }
        console.log(`Timer started for ${totalSeconds} seconds.`);
        await timerUpdate(); // Start the timer and loop
        modalTimer.set(false); // Close the modal on success
    } catch (err) {
        console.error('Error starting timer:', err.message);
        setError('ERROR: Failed to start timer.');
    }
}