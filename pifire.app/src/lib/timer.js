import { writable } from 'svelte/store';
import { browserNotification } from './notify';
import { grillControlData } from '$lib/stores/apiDataStore';

// API Variables
let timerPaused = false;
let timerEnd = 0;
let timerExpired = false;
let notificationSent = false;
let localTimerInterval = null;
let localTimerRunning = false;

// Svelte stores for reactive values
export const timerStatus = writable('stopped'); // Timer status: stopped, running, paused, expired
export const timerDisplay = writable("--:--:--");

// Fetch timer data from the grillControlData
export async function timerUpdate() {
    grillControlData.subscribe((data) => {
        const timerInfo = data?.timer_info || {};

        timerPaused = timerInfo.timer_paused === 'true';
        timerEnd = parseInt(timerInfo.timer_end_time || "0", 10);
        timerExpired = timerInfo.timer_expired === 'true';

        computeMode();

        if (timerExpired || timerStatus === 'expired') {
            timerDisplay.set("ALARM");
            if (!notificationSent) {
                browserNotification("PiFire Timer Expired", "PiFire Timer has expired.");
                notificationSent = true;
            }
            clearInterval(localTimerInterval);
            localTimerInterval = null;
            localTimerRunning = false;
            return;
        }

        if (timerEnd === 0 && !timerExpired) {
            timerDisplay.set("--:--:--");
            clearInterval(localTimerInterval);
            localTimerInterval = null;
            localTimerRunning = false;
            return;
        }
    });
}

function computeMode() {
    if (timerExpired) {
        timerStatus.set('expired');
    } else if (timerEnd === 0) {
        timerStatus.set('stopped');
    } else if (!timerPaused) {
        timerStatus.set('running');
        if (!localTimerRunning) {
            computeDisplay();
        }
    } else {
        timerStatus.set('paused');
    }
}

// Control functions
export async function timerPause() {
    try {
        const response = await fetch('/api/set/timer/pause', { method: 'POST' });
        if (!response.ok) throw new Error(`Pause failed: ${response.statusText}`);
        await timerUpdate();
        timerStatus.set('paused');
    } catch (err) {
        console.error('Pause error:', err.message);
    }
}

export async function timerUnpause() {
    try {
        const response = await fetch('/api/set/timer/start', { method: 'POST' });
        if (!response.ok) throw new Error(`Unpause failed: ${response.statusText}`);
        await timerUpdate();
        timerStatus.set('running');
    } catch (err) {
        console.error('Unpause error:', err.message);
    }
}

export async function timerStop() {
    try {
        const response = await fetch('/api/set/timer/stop', { method: 'POST' });
        if (!response.ok) throw new Error(`Stop failed: ${response.statusText}`);
        await timerUpdate();
        timerStatus.set('stopped');
        notificationSent = false;
    } catch (err) {
        console.error('Stop error:', err.message);
    }
}

export async function timerLaunch(hours, minutes, modalTimer, setError) {
    const totalSeconds = (parseInt(hours) || 0) * 3600 + (parseInt(minutes) || 0) * 60;

    notificationSent = false;

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

export function computeDisplay() {
    if (localTimerInterval) return; // Prevent multiple intervals

    const updateCountdown = () => {
        if (timerEnd === 0 || timerPaused) {
            clearInterval(localTimerInterval);
            localTimerInterval = null;
            return;
        }

        const now = Math.floor(Date.now() / 1000); // Current time in seconds
        const remainingSeconds = Math.max(0, Math.floor(timerEnd - now));

        const hours = Math.floor(remainingSeconds / 3600);
        const minutes = Math.floor((remainingSeconds % 3600) / 60);
        const seconds = remainingSeconds % 60;
        const displayValue = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
        timerDisplay.set(displayValue);

        if (remainingSeconds === 0) {
            clearInterval(localTimerInterval);
            localTimerInterval = null;
        }
    };

    const now = Date.now();
    const delay = 1000 - (now % 1000); // Align with the next second
    setTimeout(() => {
        updateCountdown();
        localTimerInterval = setInterval(updateCountdown, 1000);
    }, delay);
}