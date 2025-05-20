import { writable, get } from 'svelte/store';
import { io } from 'socket.io-client';

export const isConnected = writable(false);
export const socketStatus = writable('Disconnected');
export const serverAddress = writable('http://localhost'); 
export const serverPort = writable('8000'); 

export const controlData = writable({}); 
export const settingsData = writable({});
export const pelletsData = writable({});
export const currentTempsData = writable({});
export const historyData = writable([]);
export const metricsData = writable([]);
export const errorData = writable([]);
export const warningData = writable([]);
export const uiSettings = writable({}); 

let socket = null;

function _attachListeners(currentSocket) {
	currentSocket.on('connect', () => {
		const address = `${get(serverAddress)}:${get(serverPort)}`;
		isConnected.set(true);
		socketStatus.set('Connected');
		currentSocket.emit('request_initial_data'); 
	});

	currentSocket.on('disconnect', (reason) => {
		isConnected.set(false);
		socketStatus.set('Disconnected');
		uiSettings.set({});
		controlData.set({});
	});

	currentSocket.on('connect_error', (error) => {
		console.error('Socket connection error:', error.message);
		isConnected.set(false);
		socketStatus.set('Error');
		uiSettings.set({});
		controlData.set({});
	});

	currentSocket.on('dashboard_data', (data) => {
		controlData.set(data || {}); 
	});

	currentSocket.on('settings_data', (fullSettings) => {
		settingsData.set(fullSettings || {});
		const dashSettings = fullSettings?.webui?.dash || {};
		uiSettings.set(dashSettings);
	});

	currentSocket.on('pellet_data', (data) => {
		pelletsData.set(data || {});
	});

	currentSocket.on('current_temps_data', (data) => {
		currentTempsData.set(data || {});
	});

	currentSocket.on('history_data', (data) => {
		historyData.set(data || []);
	});

	currentSocket.on('metrics_data', (data) => {
		metricsData.set(data || []);
	});

	currentSocket.on('error_data', (data) => {
		errorData.set(data || []);
	});

	currentSocket.on('warning_data', (data) => {
		warningData.set(data || []);
	});

	currentSocket.on('post_response', (response) => {
	});
}

function _removeListeners(currentSocket) {
	currentSocket.off('connect');
	currentSocket.off('disconnect');
	currentSocket.off('connect_error');
	currentSocket.off('dashboard_data'); 
	currentSocket.off('settings_data');
	currentSocket.off('pellet_data'); 
	currentSocket.off('current_temps_data');
	currentSocket.off('history_data');
	currentSocket.off('metrics_data');
	currentSocket.off('error_data');
	currentSocket.off('warning_data');
	currentSocket.off('post_response');
}

function _connectInternal() {
	if (socket && (socket.connected || socket.connecting)) {
		return;
	}
	if (socket) {
		_removeListeners(socket);
		socket.disconnect();
		socket = null;
	}
	const address = `${get(serverAddress)}:${get(serverPort)}`;
	socketStatus.set('Connecting');
	uiSettings.set({});
	controlData.set({});
	socket = io(address, { reconnection: true });
	_attachListeners(socket);
}

export function initializeSocket() {
	if (typeof window !== 'undefined') {
		const savedAddress = localStorage.getItem('serverAddress');
		const savedPort = localStorage.getItem('serverPort');
		if (savedAddress) serverAddress.set(savedAddress);
		if (savedPort) serverPort.set(savedPort);
		_connectInternal();
	} else {
		console.warn("Socket initialization skipped: Not in browser.");
	}
}

export function disconnectSocket() {
	if (socket) {
		_removeListeners(socket);
		socket.disconnect();
		socket = null;
		isConnected.set(false);
		socketStatus.set('Disconnected');
		uiSettings.set({});
		controlData.set({});
	}
}

export function switchServer(newAddress, newPort = get(serverPort)) {
	disconnectSocket(); 
	settingsData.set({}); pelletsData.set({}); controlData.set({}); 
	currentTempsData.set({}); historyData.set([]); metricsData.set([]);
	errorData.set([]); warningData.set([]); uiSettings.set({});
	serverAddress.set(newAddress); serverPort.set(newPort);
	if (typeof window !== 'undefined') {
		localStorage.setItem('serverAddress', newAddress);
		localStorage.setItem('serverPort', newPort);
	}
	setTimeout(_connectInternal, 250);
}

export function emitEvent(eventName, data = {}) {
	if (socket && socket.connected) socket.emit(eventName, data);
	else console.error(`Socket not connected. Cannot emit '${eventName}'.`);
}

function _emitWithAck(eventName, data, timeoutMs = 5000) {
	return new Promise((resolve, reject) => {
		if (!socket || !socket.connected) return reject(new Error('Socket not connected.'));
		let timedOut = false;
		const timer = setTimeout(() => { timedOut = true; reject(new Error(`Timeout: ${eventName}`)); }, timeoutMs);
		socket.emit(eventName, data, (response) => {
			clearTimeout(timer);
			if (timedOut) return; 
			if (response && response.error) reject(new Error(response.error));
			else resolve(response);
		});
	});
}

export async function postData(category, dataPayload, timeoutMs = 5000) {
	if (!category || typeof dataPayload !== 'object') return Promise.reject(new Error("postData: category & dataPayload (object) required."));
	const message = { category, data: dataPayload };
	return _emitWithAck('post_data', message, timeoutMs);
}

export async function setMode(modeName, data = {}) { 
    const payload = { mode: modeName, ...data };
    return postData('control', payload);
}

export async function setPMode(pmodeValue) {
	if (typeof pmodeValue !== 'number' || pmodeValue < 0 || pmodeValue > 9) return Promise.reject(new Error("Invalid PMode."));
	return postData('control', { pmode: pmodeValue });
}

export async function setSmokePlus(enable) {
	return postData('control', { splus: enable });
}

export async function toggleLidOpen() {
	return postData('control', { lid_open_toggle: true });
}

export async function setPWMControl(enable) {
	return postData('control', { pwm_control: enable });
}

export async function setDutyCycle(dutyCycleValue) {
	if (typeof dutyCycleValue !== 'number' || dutyCycleValue < 0 || dutyCycleValue > 100) return Promise.reject(new Error("Invalid Duty Cycle."));
	return postData('control', { duty_cycle: dutyCycleValue });
}

export async function setTuningMode(enable) {
	return postData('control', { tuning_mode: enable });
}

export async function setManual(component, value) {
	return postData('control', { command_type: 'manual', action: component, value: value });
}

export async function startTimer(durationSeconds) {
	return postData('timer', { action: 'start', duration: durationSeconds });
}
export async function pauseTimer() { return postData('timer', { action: 'pause' }); }
export async function stopTimer() { return postData('timer', { action: 'stop' }); }
export async function setTimerShutdown(enable) { return postData('timer', { action: 'set_shutdown', value: enable }); }
export async function setTimerKeepWarm(enable) { return postData('timer', { action: 'set_keep_warm', value: enable }); }

export async function saveCardOrder(cardOrderArray) {
	return postData('settings', { webui: { dash: { cardOrder: cardOrderArray } } });
}

export async function requestControlData() { 
	try {
		const response = await _emitWithAck('get_data', { action: 'control' });
		controlData.set(response || {});
		return response;
	} catch (error) {
		console.error("Failed to request main control/dashboard data:", error);
		controlData.set({}); throw error;
	}
}

export async function requestSettingsData() {
	try {
		const response = await _emitWithAck('get_data', { action: 'settings' });
		settingsData.set(response || {});
		uiSettings.set(response?.webui?.dash || {});
		return response;
	} catch (error) {
		console.error("Failed to request settings data:", error);
		settingsData.set({}); uiSettings.set({}); throw error;
	}
}

export async function requestPelletsDbData() { 
	try {
		const response = await _emitWithAck('get_data', { action: 'pellets' });
		pelletsData.set(response || {});
		return response;
	} catch (error) {
		console.error("Failed to request pellets DB data:", error);
		pelletsData.set({}); throw error;
	}
}

export async function requestCurrentTemps() { 
	try {
		const response = await _emitWithAck('get_data', { action: 'current_temps' });
		currentTempsData.set(response || {}); 
		return response;
	} catch (error) {
		console.error("Failed to request current temps data:", error);
		currentTempsData.set({}); throw error;
	}
}