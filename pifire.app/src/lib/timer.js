import { writable, derived, get } from 'svelte/store';
import { 
    controlData,
    postData,
    startTimer as apiStartTimer,
    pauseTimer as apiPauseTimer,
    stopTimer as apiStopTimer,
    setTimerShutdown as apiSetTimerShutdown,
    setTimerKeepWarm as apiSetTimerKeepWarm
} from '$lib/stores/socketioStore';

const initialTimerState = {
    status: 'stopped',
    display: '--:--:--',
    hours: 0,                 
    minutes: 0,               
    seconds: 0,               
    isShutdownSet: false,
    isKeepWarmSet: false
};

export const timerStore = writable({ ...initialTimerState });

export const timerMode = derived(timerStore, $store => $store.status);

let backendTimerInfo = {
    timer_active: false,
    timer_paused: false,
    timer_expired: false,
    timer_end_time: 0,
    timer_paused_time: 0,
    timer_shutdown: false,
    timer_keep_warm: false
};

let displayUpdateInterval = null; 
let unsubscribeFromControlData = null;

function calculateRemainingMilliseconds() {
    if (!backendTimerInfo.timer_active || backendTimerInfo.timer_end_time === 0) {
        return 0;
    }
    const nowSeconds = Date.now() / 1000;
    let remainingSeconds;
    if (backendTimerInfo.timer_paused && backendTimerInfo.timer_paused_time > 0) {
        remainingSeconds = backendTimerInfo.timer_end_time - backendTimerInfo.timer_paused_time;
    } else {
        remainingSeconds = backendTimerInfo.timer_end_time - nowSeconds;
    }
    return Math.max(0, remainingSeconds * 1000);
}

function formatTimerDisplay(remainingMs, currentStatus) {
    if (currentStatus === 'expired') {
        return { display: 'ALARM', hours: 0, minutes: 0, seconds: 0 };
    }
    if (currentStatus === 'stopped' || !backendTimerInfo.timer_active) {
        return { display: '--:--:--', hours: 0, minutes: 0, seconds: 0 };
    }
    if (remainingMs <= 0 && currentStatus !== 'paused') {
        return { display: '00:00:00', hours: 0, minutes: 0, seconds: 0 };
    }
    const totalTotalSeconds = Math.ceil(remainingMs / 1000);
    const h = Math.floor(totalTotalSeconds / 3600);
    const m = Math.floor((totalTotalSeconds % 3600) / 60);
    const s = totalTotalSeconds % 60;
    return {
        display: `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`,
        hours: h,
        minutes: m,
        seconds: s
    };
}

function updateTimerStoreValues() {
    let newStatus = 'stopped';
    if (backendTimerInfo.timer_expired) {
        newStatus = 'expired';
    } else if (backendTimerInfo.timer_active) {
        newStatus = backendTimerInfo.timer_paused ? 'paused' : 'running';
    }

    const remainingMs = calculateRemainingMilliseconds();
    const displayParts = formatTimerDisplay(remainingMs, newStatus);

    timerStore.set({
        status: newStatus,
        display: displayParts.display,
        hours: displayParts.hours,
        minutes: displayParts.minutes,
        seconds: displayParts.seconds,
        isShutdownSet: backendTimerInfo.timer_active && backendTimerInfo.timer_shutdown,
        isKeepWarmSet: backendTimerInfo.timer_active && backendTimerInfo.timer_keep_warm
    });

    if (newStatus === 'running' && !displayUpdateInterval) {
        displayUpdateInterval = setInterval(updateTimerStoreValues, 250);
    } else if (newStatus !== 'running' && displayUpdateInterval) {
        clearInterval(displayUpdateInterval);
        displayUpdateInterval = null;
    }
}

function handleBackendUpdate(latestGrillData) {
    const newTimerInfo = latestGrillData?.timer;

    if (newTimerInfo && typeof newTimerInfo === 'object') {
        backendTimerInfo = {
            timer_active: newTimerInfo.timer_active ?? false,
            timer_paused: newTimerInfo.timer_paused ?? false,
            timer_expired: newTimerInfo.timer_expired ?? false,
            timer_end_time: newTimerInfo.timer_end_time ?? 0,
            timer_paused_time: newTimerInfo.timer_paused_time ?? 0,
            timer_shutdown: newTimerInfo.timer_shutdown ?? false,
            timer_keep_warm: newTimerInfo.timer_keep_warm ?? false
        };
    } else {
        backendTimerInfo = { 
            timer_active: false, timer_paused: false, timer_expired: false,
            timer_end_time: 0, timer_paused_time: 0,
            timer_shutdown: false, timer_keep_warm: false
        };
    }
    updateTimerStoreValues();
}

export async function startTimer(hours, minutes, options = {}) {
    const h = parseInt(String(hours || 0), 10);
    const m = parseInt(String(minutes || 0), 10);
    const shutdownOption = options.shutdown || false;
    const keepWarmOption = options.keepWarm || false;

    if (h < 0 || m < 0 || (h === 0 && m === 0)) {
        console.error("Timer.js: Timer duration must be positive.");
        timerStore.update(store => ({ ...store, status: 'error', display: "Invalid Duration" }));
        return Promise.reject(new Error("Invalid Duration"));
    }

    const durationSeconds = (h * 3600) + (m * 60);

    try {
        await apiStartTimer(durationSeconds);
        await apiSetTimerShutdown(shutdownOption);
        await apiSetTimerKeepWarm(keepWarmOption);
    } catch (error) {
        console.error('Timer.js: Error in startTimer sequence:', error);
        timerStore.update(store => ({...store, status: 'error', display: "Start Failed"}));
        throw error;
    }
}

export async function stopTimer() {
    try {
        await apiStopTimer()
    } catch (error) {
        console.error('Timer.js: Error sending stop timer command:', error);
        timerStore.update(store => ({...store, status: 'error', display: "Stop Failed"}));
        throw error;
    }
}

export async function pauseTimer() {
    try {
        await apiPauseTimer();
    } catch (error) {
        console.error('Timer.js: Error sending pause timer command:', error);
        timerStore.update(store => ({...store, status: 'error', display: "Pause Failed"}));
        throw error;
    }
}

export async function resumeTimer() {
    try {
        await postData('timer', { action: 'start' });
    } catch (error) {
        console.error('Timer.js: Error sending resume timer command:', error);
        timerStore.update(store => ({...store, status: 'error', display: "Resume Failed"}));
        throw error;
    }
}

export function initTimerModule() {
    if (unsubscribeFromControlData) {
        console.warn('Timer.js: Timer module already initialized.');
        return;
    }
    unsubscribeFromControlData = controlData.subscribe(handleBackendUpdate);
}

export function destroyTimerModule() {
    if (unsubscribeFromControlData) {
        unsubscribeFromControlData();
        unsubscribeFromControlData = null;
    }
    if (displayUpdateInterval) {
        clearInterval(displayUpdateInterval);
        displayUpdateInterval = null;
    }
    timerStore.set({ ...initialTimerState }); 
    backendTimerInfo = { 
        timer_active: false, timer_paused: false, timer_expired: false,
        timer_end_time: 0, timer_paused_time: 0,
        timer_shutdown: false, timer_keep_warm: false
    };
}