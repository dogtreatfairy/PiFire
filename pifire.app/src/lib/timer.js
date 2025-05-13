import { writable } from 'svelte/store';
// Corrected import from your socketioStore module
import { controlData, postAppData } from '$lib/stores/socketioStore'; // Adjust path if needed

// --- Svelte Store (Using writable) ---
export const timerStore = writable({
    status: 'stopped', // 'running', 'paused', 'expired', 'stopped'
    display: '--:--:--', // Formatted string: HH:MM:SS, 'ALARM', or '--:--:--'
	hours: 0,
	minutes: 0
});

// --- Internal Module State ---
let timerStatus = 'stopped'; // Internal tracking
let timerDisplay = '--:--:--'; // Internal tracking

let _timerEndTime = 0;
let _timerPausedTime = 0;
let _timerIsActive = false;
let _timerIsPaused = false;
let _timerIsExpired = false;

let updateIntervalId = null; // Interval ID for display updates
let unsubscribeFromGrillData = null; // Store the unsubscribe function

// --- Helper Functions ---

/** Calculates remaining time in milliseconds. */
function calculateRemainingMilliseconds() {
    if (!_timerIsActive || _timerEndTime === 0) return 0;
    const now = Date.now();
    const endTimeMs = _timerEndTime * 1000;
    if (_timerIsPaused) {
        const pausedTimeMs = _timerPausedTime * 1000;
        return _timerPausedTime !== 0 ? Math.max(0, endTimeMs - pausedTimeMs) : 0;
    } else {
        return Math.max(0, endTimeMs - now);
    }
}

/** Generates the display string based on status and time. */
function getTimerDisplayString(status, remainingMilliseconds) {
    if (status === 'expired') return 'ALARM';
    if (status === 'stopped') return '--:--:--';
    if (remainingMilliseconds <= 0) return '00:00:00';

    const totalSeconds = Math.ceil(remainingMilliseconds / 1000);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;

	// Write hour and minutes to the store
	timerStore.update(store => ({
		...store,
		hours: hours,
		minutes: minutes
	}))

    const displayHours = String(hours).padStart(2, '0');
    const displayMinutes = String(minutes).padStart(2, '0');
    const displaySeconds = String(seconds).padStart(2, '0');
    return `${displayHours}:${displayMinutes}:${displaySeconds}`;
}

// --- Core Timer Logic ---

/** Updates the timer display string locally (called by interval). */
function updateLocalTimerDisplay() {
    if (timerStatus === 'running') {
        const remainingMs = calculateRemainingMilliseconds();
        const newDisplayString = getTimerDisplayString('running', remainingMs);
        timerDisplay = newDisplayString; // Update internal tracker first
        timerStore.update(store => ({ ...store, display: newDisplayString }));

        if (remainingMs <= 0) {
            if (updateIntervalId) {
                clearInterval(updateIntervalId);
                updateIntervalId = null;
            }
        }
    } else {
        // Stop interval if status changed unexpectedly
        if (updateIntervalId) {
            clearInterval(updateIntervalId);
            updateIntervalId = null;
        }
    }
}

/** Updates state based on data from controlData store. */
function updateFromGrillData(grillData) {
    const timerInfo = grillData?.timer_info;
    let prevStatus = timerStatus;

    if (!timerInfo) {
        _timerIsActive = false; _timerIsPaused = false; _timerEndTime = 0;
        _timerPausedTime = 0; _timerIsExpired = false;
    } else {
        _timerIsActive = timerInfo.timer_active ?? false;
        _timerIsPaused = timerInfo.timer_paused ?? false;
        _timerEndTime = timerInfo.timer_end_time ?? 0;
        _timerPausedTime = timerInfo.timer_paused_time ?? 0;
        _timerIsExpired = timerInfo.timer_expired ?? false;
    }

    if (_timerIsExpired) timerStatus = 'expired';
    else if (!_timerIsActive) timerStatus = 'stopped';
    else if (_timerIsPaused) timerStatus = 'paused';
    else timerStatus = 'running';

    const remainingMs = calculateRemainingMilliseconds();
    timerDisplay = getTimerDisplayString(timerStatus, remainingMs);

    // Update the Svelte store
    timerStore.set({ status: timerStatus, display: timerDisplay });

    // Manage interval
    if (timerStatus === 'running') {
        if (!updateIntervalId) {
             // Update display immediately based on fresh calculation
            updateLocalTimerDisplay();
            updateIntervalId = setInterval(updateLocalTimerDisplay, 250);
        }
    } else {
        if (updateIntervalId) {
            clearInterval(updateIntervalId);
            updateIntervalId = null;
        }
        // Ensure final display update if status changed away from running
        if (prevStatus === 'running' && timerStatus !== 'running') {
             setTimeout(() => {
                 const finalRemainingMs = calculateRemainingMilliseconds();
                 const finalDisplay = getTimerDisplayString(timerStatus, finalRemainingMs);
                 timerStore.update(store => ({ ...store, display: finalDisplay }));
             }, 0);
        }
    }
}

// --- Control Functions (Exported) ---
// Uses postAppData from socketioStore
// !!! Verify action ('timer_action') and type ('pause', 'start', 'stop') with your backend !!!

/** Sends pause command. */
export function timerPause() {
    console.log("Sending timer pause command via postAppData...");
    postAppData('timer_action', 'pause_timer', {})
        .then(response => console.log('Timer pause ack:', response))
        .catch(error => console.error('Error sending timer pause:', error));
}

/** Sends unpause/resume command. */
export function timerUnpause() {
    console.log("Sending timer resume (start) command via postAppData...");
    postAppData('timer_action', 'start_timer', {})
        .then(response => console.log('Timer resume ack:', response))
        .catch(error => console.error('Error sending timer resume:', error));
}

/** Sends stop command. */
export function timerStop() {
    console.log("Sending timer stop command via postAppData...");
    postAppData('timer_action', 'stop_timer', {})
        .then(response => console.log('Timer stop ack:', response))
        .catch(error => console.error('Error sending timer stop:', error));
    if (updateIntervalId) clearInterval(updateIntervalId); updateIntervalId = null;
    timerStore.set({ status: 'stopped', display: '--:--:--' });
    timerStatus = 'stopped'; timerDisplay = '--:--:--';
}

/** Sends launch command. */
export function timerLaunch(hours, minutes, options = {}) {
    // Local variables for inputs with default values
    const localHours = parseInt(hours || 0, 10); // Default to 0 if blank
    const localMinutes = parseInt(minutes || 0, 10); // Default to 0 if blank
    const localShutdown = options.timer_shutdown || false; // Default to false if blank
    const localKeepWarm = options.timer_keep_warm || false; // Default to false if blank

    // Calculate total seconds
    const totalSeconds = (localHours * 3600) + (localMinutes * 60);
    if (totalSeconds <= 0) {
        console.error('Invalid timer duration: hours and minutes must result in a positive duration.');
        return;
    }

    // Create payload with correct keys for the API
    const payload = {
        timer_action: {
            hours_range: localHours,
            minutes_range: localMinutes,
            timer_shutdown: localShutdown,
            timer_keep_warm: localKeepWarm
        }
    };

    postAppData('timer_action', 'start_timer', payload)
        .then(() => timerStore.update(store => ({ ...store, status: 'running' })))
        .catch(error => {
            console.error('Failed to start timer:', error);
        });
}

// --- Initialization and Cleanup ---

/** Initializes the timer module: subscribes to controlData. */
export function initTimer() {
    console.log('Initializing timer (Store Mode)...');
    if (unsubscribeFromGrillData) return; // Prevent multiple initializations

    unsubscribeFromGrillData = controlData.subscribe(storeValue => {
        updateFromGrillData(storeValue);
    });
}

/** Cleans up the timer interval and store subscription. */
export function destroyTimer() {
    console.log('Destroying timer (Store Mode)...');
    if (updateIntervalId) clearInterval(updateIntervalId); updateIntervalId = null;
    if (unsubscribeFromGrillData) unsubscribeFromGrillData(); unsubscribeFromGrillData = null;
    timerStore.set({ status: 'stopped', display: '--:--:--' });
    timerStatus = 'stopped'; timerDisplay = '--:--:--';
}