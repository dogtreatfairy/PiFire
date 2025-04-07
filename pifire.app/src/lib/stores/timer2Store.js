// API Variables
let timerStart = 0;
let timerPaused = 0;
let timerEnd = 0;
let timerShutdown = false;
let timerKeepWarm = false;
// Other Variables
let timerStatus = $state('stopped');  // Timer status: stopped, running, paused, finished.
let timerFinishedFlag = false;

export async function timerUpdate () {
    try { 
        const response = await fetch('/api/get/timer', { method: 'GET' });
        if (!response.ok) {
            throw new Error(`Failed to fetch timer data: ${response.statusText}`);
        }
        
		// Add API Data to JSON Array
        const { data: apiTimerData } = await response.json();
		
		// Reset finished flag if a new timer is started
		if (apiTimerData.end !== timerEnd && apiTimerData.end !== 0) {
			timerFinishedFlag = false;
		}

		timerStart = apiTimerData.start;
		timerPaused = apiTimerData.paused;
		timerEnd = apiTimerData.end;
		timerShutdown = apiTimerData.shutdown;
		timerKeepWarm = apiTimerData.keep_warm;

		if (!timerFinishedFlag) {
			switch (true) {
				case timerEnd === 0:
					timerStatus = 'stopped';
					break;
				case timerEnd > 0 && timerPaused === 0:
					timerStatus = 'running';
					break;
				case timerEnd > 0 && timerPaused > 0:
					timerStatus ='paused';
					break;			
				default:
					timerStatus = 'unknown';
					break;
			} // Timer Finished defined in timerDisplay()
		}

        if(timerStatus === 'running'){
            timerDisplay();
        }
    } catch (error) {
        console.error('Error updating timer:', error);
    }
}

function timerDisplay() {
    // Calculate remaining seconds using timerEnd and current time
    const remainingSeconds = Math.floor(timerEnd - Date.now() / 1000);

    // Initialize the display value
    let display = "";

    if (remainingSeconds < 0) {
        timerStatus = 'finished';
		timerFinishedFlag = true;
        display = "ALARM";
    } else if (remainingSeconds === 0) {
        display = "--:--:--";
    } else {
        // Calculate hours, minutes, and seconds
        const hours = Math.floor(remainingSeconds / 3600);
        const minutes = Math.floor((remainingSeconds % 3600) / 60);
        const seconds = remainingSeconds % 60;

        // Format each component to always be two digits
        const tdHrs = String(hours).padStart(2, '0');
        const tdMins = String(minutes).padStart(2, '0');
        const tdSecs = String(seconds).padStart(2, '0');

        // Combine into hh:mm:ss format using template literals
        display = `${tdHrs}:${tdMins}:${tdSecs}`;
    }

    return display;
}

// Control functions
export async function timerPause() {
  try {
	const response = await fetch('/api/set/timer/pause', { method: 'POST' });
	if (!response.ok) throw new Error(`Pause failed: ${response.statusText}`);
	await timerUpdate(true);
  } catch (err) {
	console.error('Pause error:', err.message);
  }
}

export async function timerUnpause() {
  try {
	const response = await fetch('/api/set/timer/start', { method: 'POST' });
	if (!response.ok) throw new Error(`Unpause failed: ${response.statusText}`);
	await timerUpdate(true);
  } catch (err) {
	console.error('Unpause error:', err.message);
  }
}

export async function timerStop() {
  try {
	const response = await fetch('/api/set/timer/stop', { method: 'POST' });
	if (!response.ok) throw new Error(`Stop failed: ${response.statusText}`);
	// Remove timerFinhishedFlag so timerUpdate will set status to 'stopped'
	timerFinishedFlag = false;
	await timerUpdate(true);
  } catch (err) {
	console.error('Stop error:', err.message);
  }
}