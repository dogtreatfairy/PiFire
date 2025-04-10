import { writable } from 'svelte/store';
import { browserNotification } from './notify';

// API Variables
let timerPaused = 0;
let timerEnd = 0;
let timerExpired = false;
let notificationSent = false;
let localTimerInterval = null;
let localTimerRunning = false;

// Svelte stores for reactive values
export const timerStatus = writable('stopped'); // Timer status: stopped, running, paused, expired
export const timerDisplay = writable("--:--:--");

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

    } catch (error) {
        console.error('Error updating timer:', error);
    }
}
function computeMode() {
    if (timerExpired) {
        timerStatus.set('expired');
    } else if (timerEnd === 0) {
        timerStatus.set('stopped');
    } else if (timerPaused === 0) {
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

		if (timerEnd === 0 || timerPaused > 0) {
            // Stop the timer if timerEnd is 0 or timer is paused
            clearInterval(localTimerInterval);
            localTimerInterval = null;
            return;
        }

        // Calculate remaining seconds
        const now = Math.floor(Date.now() / 1000); // Current time in seconds
        const remainingSeconds = Math.max(0, Math.floor(timerEnd - now));

        // Update the display
        const hours = Math.floor(remainingSeconds / 3600);
        const minutes = Math.floor((remainingSeconds % 3600) / 60);
        const seconds = remainingSeconds % 60;
        const tdHrs = String(hours).padStart(2, '0');
        const tdMins = String(minutes).padStart(2, '0');
        const tdSecs = String(seconds).padStart(2, '0');
        const displayValue = `${tdHrs}:${tdMins}:${tdSecs}`;
        timerDisplay.set(displayValue);

        // Stop the timer if it reaches 0
        if (remainingSeconds === 0) {
            clearInterval(localTimerInterval);
            localTimerInterval = null;
        }
    };

    // Sync with the system clock
    const now = Date.now();
    const delay = 1000 - (now % 1000); // Calculate delay to align with the next second
    setTimeout(() => {
        updateCountdown(); // Initial update
        localTimerInterval = setInterval(updateCountdown, 1000); // Update every second
    }, delay);
}