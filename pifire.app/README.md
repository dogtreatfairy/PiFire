## SocketIO Action Tree

### 1. Connection Events

#### `connect`
- **Action**: Increments the `clients` counter.
- **Data**: None.
- **Notes**: Triggered automatically when a client connects.

#### `disconnect`
- **Action**: Decrements the `clients` counter.
- **Data**: None.
- **Notes**: Triggered automatically when a client disconnects.

---

### 2. Data Fetching Events

#### `get_dash_data`
- **Action**: Starts the `emit_dash_data` background task if not already running.
- **Data**:
  - `force` (optional, boolean): Forces a refresh of the dashboard data.
- **Server Response**:
  - Emits `grill_control_data` with:
    - `probe_info`: Current probe data.
    - `notify_data`: Notification data.
    - `timer_info`: Timer details.
    - `current_mode`: Current grill mode.
    - `smoke_plus`: Smoke+ status.
    - `pwm_control`: PWM control status.
    - `hopper_level`: Current hopper level.

#### `get_app_data`
- **Action**: Fetches specific application data based on the `action` parameter.
- **Data**:
  - `action` (string): Specifies the type of data to fetch.
    - **`settings_data`**:
      - **Response**: Returns the `settings` object.
    - **`pellets_data`**:
      - **Response**: Returns the pellet database.
    - **`events_data`**:
      - **Response**:
        - `events_list`: A trimmed list of recent events (up to 60).
    - **`info_data`**:
      - **Response**:
        - `uptime`: System uptime.
        - `cpuinfo`: CPU information.
        - `ifconfig`: Network interface configuration.
        - `temp`: CPU temperature.
        - `outpins`: Output pins configuration.
        - `inpins`: Input pins configuration.
        - `dev_pins`: Device pins configuration.
        - `server_version`: Server version.
        - `server_build`: Server build number.
    - **`manual_data`**:
      - **Response**:
        - `manual`: Manual mode data.
        - `mode`: Current grill mode.
- **Server Response**:
  - Returns the requested data as a JSON object.

---

### 3. Data Update Events

#### `post_app_data`
- **Action**: Updates application data based on the `action` and `type` parameters.
- **Data**:
  - `action` (string): Specifies the type of update.
    - **`update_action`**:
      - `type` (string): Specifies the data type to update.
        - **`settings`**:
          - Updates the `settings` object.
        - **`control`**:
          - Updates the `control` object.
    - **`admin_action`**:
      - `type` (string): Specifies the admin action to perform.
        - **`clear_history`**: Clears the history log.
        - **`clear_events`**: Clears the events log.
        - **`clear_pelletdb`**: Clears the pellet database.
        - **`clear_pelletdb_log`**: Clears the pellet database log.
        - **`factory_defaults`**: Resets settings, control, and history to factory defaults.
        - **`reboot`**: Reboots the system.
        - **`shutdown`**: Shuts down the system.
        - **`restart`**: Restarts the server.
    - **`units_action`**:
      - `type` (string): Specifies the unit conversion.
        - **`f_units`**: Converts settings to Fahrenheit.
        - **`c_units`**: Converts settings to Celsius.
    - **`remove_action`**:
      - `type` (string): Specifies the item to remove.
        - **`onesignal_device`**: Removes a OneSignal device.
    - **`pellets_action`**:
      - `type` (string): Specifies the pellet-related action.
        - **`load_profile`**: Loads a pellet profile.
        - **`hopper_check`**: Triggers a hopper check.
        - **`edit_brands`**: Edits pellet brands.
        - **`edit_woods`**: Edits pellet wood types.
        - **`add_profile`**: Adds a new pellet profile.
        - **`edit_profile`**: Edits an existing pellet profile.
        - **`delete_profile`**: Deletes a pellet profile.
        - **`delete_log`**: Deletes a pellet log entry.
    - **`timer_action`**:
      - `type` (string): Specifies the timer action.
        - **`start_timer`**: Starts a timer.
        - **`pause_timer`**: Pauses the timer.
        - **`stop_timer`**: Stops the timer.
- **Server Response**:
  - Returns a success or error message.

---

### 4. Real-Time Data Emission

#### `emit_dash_data` (Background Task)
- **Action**: Periodically emits `grill_control_data` to all connected clients.
- **Data**:
  - `probe_info`: Current probe data.
  - `notify_data`: Notification data.
  - `timer_info`: Timer details.
  - `current_mode`: Current grill mode.
  - `smoke_plus`: Smoke+ status.
  - `pwm_control`: PWM control status.
  - `hopper_level`: Current hopper level.
- **Notes**:
  - Runs as a background task while there are connected clients.
  - Emits data only when it changes or when `force_refresh` is set to `True`.

---

### How to Use This Action Tree
- Use the **Connection Events** to track when clients connect or disconnect.
- Use the **Data Fetching Events** to request specific data from the server.
- Use the **Data Update Events** to modify server-side data or perform admin actions.
- Use the **Real-Time Data Emission** to listen for updates pushed by the server.

---

## Accessing Data via Socket.IO

### Prerequisites
Ensure that your PiFire server is running and accessible on the default port (e.g., `http://localhost:8000`).

### Steps to Access Data

1. **Connect to the Server**:
   - Use a WebSocket client (e.g., `socket.io-client` in JavaScript or Python's `socketio` library) to connect to the server.
   - Example connection URL: `http://localhost:8000`.

2. **Listen for Events**:
   - The following events are available to fetch data:
     - `grill_control_data`: Provides real-time grill control data, including probe information, timer details, and hopper level.
     - `settings_data`: Returns the current settings.
     - `pellets_data`: Returns pellet database information.
     - `events_data`: Returns a list of recent events.
     - `info_data`: Provides system information such as uptime, CPU info, and network configuration.
     - `manual_data`: Returns manual mode data.

3. **Emit Events to Fetch Data**:
   - Use the following events to request specific data:
     - `get_dash_data`: Starts the background task to emit `grill_control_data`.
       - Example payload: `{ "force": true }`
     - `get_app_data`: Fetches specific application data based on the `action` parameter.
       - Example payloads:
         - `{ "action": "settings_data" }`
         - `{ "action": "pellets_data" }`
         - `{ "action": "events_data" }`
         - `{ "action": "info_data" }`
         - `{ "action": "manual_data" }`

4. **Example JavaScript Client**:
   ```javascript
   import { io } from 'socket.io-client';

   const socket = io('http://localhost:8000');

   socket.on('connect', () => {
       console.log('Connected to the server!');
       socket.emit('get_dash_data', { force: true });
   });

   socket.on('grill_control_data', (data) => {
       console.log('Received grill_control_data:', data);
   });

   socket.on('disconnect', () => {
       console.log('Disconnected from the server!');
   });
   ```

---

### Accessing Specific Data from Emitted Events

To access specific data from the emitted events in your Svelte application, follow these steps:

1. **Connect to the Socket.IO Server**:
   - Use the `connectSocket` function from your `apiDataStore.js` to establish a connection to the server.

2. **Listen for the Desired Event**:
   - The `grill_control_data` event contains various pieces of data, including `timer_info`.

3. **Access Specific Data**:
   - Use the `subscribe` method of the Svelte store to access the data.
   - For example, to access the `timer_paused` value from `timer_info`, you can do the following:

   ```svelte
   <script>
       import { grillControlDataStore } from '$lib/stores/apiDataStore';

       let timerPaused;

       // Subscribe to the grillControlDataStore to get updates
       $: grillControlDataStore.subscribe((data) => {
           if (data && data.timer_info) {
               timerPaused = data.timer_info.timer_paused;
           }
       });
   </script>

   <div>
       <p>Timer Paused: {timerPaused ? 'Yes' : 'No'}</p>
   </div>
   ```

4. **Notes**:
   - Ensure that the `grill_control_data` event is being emitted by the server and that the `connectSocket` function is called during the initialization of your app.
   - The `grillControlDataStore` is updated whenever new data is received from the `grill_control_data` event.