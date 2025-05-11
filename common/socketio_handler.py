import time
import math
import json
import copy
from flask import request
from flask_socketio import SocketIO
from threading import Lock
from common import *

socketio = SocketIO()
background_task_lock = Lock()
thread = None
clients = 0
force_refresh = False

'''
==============================================================================
SocketIO Section
==============================================================================
'''
# --- Global Variables (as provided by user) ---
settings_file_path = 'settings.json' # Path to your main settings file

@socketio.on("connect")
def connect():
	global clients
	global thread
	global background_task_lock

	sid = request.sid
	print(f"Client connected: {sid}")
	clients += 1
	print(f"Total clients: {clients}")

	with background_task_lock:
		if thread is None:
			print(f"Background task is None. Starting new task (triggered by connect from {sid}).")
			thread = socketio.start_background_task(emit_dash_data)

@socketio.on("disconnect")
def disconnect():
	global clients
	sid = request.sid
	if clients > 0:
		clients -= 1
	print(f"Client disconnected: {sid}")
	print(f"Total clients: {clients}")

@socketio.on('get_dash_data')
def get_dash_data(data={}):
	global thread
	global force_refresh
	global background_task_lock

	force = data.get('force', False)
	sid = request.sid
	print(f"Received 'get_dash_data' from {sid} with force={force}")

	force_refresh = force

	with background_task_lock:
		if thread is None:
			print(f"Background task is None. Starting new task (triggered by get_dash_data from {sid}).")
			thread = socketio.start_background_task(emit_dash_data)

def emit_dash_data():
	global clients
	global force_refresh
	global thread
	global background_task_lock

	print("Background task 'emit_dash_data' started.")
	previous_data = None

	try:
		while (clients > 0):
			try:
				settings = read_settings()  # Add this read
				control = read_control()
				status = read_status()
				pelletdb = read_pellet_db()
				probe_info = read_current()
				
				timer_notify_index = -1  # Default index if no timer found

				# Find the timer notification object safely
				for index, notify_obj in enumerate(control.get('notify_data', [])):
					if isinstance(notify_obj, dict) and notify_obj.get('type') == 'timer':
						timer_notify_index = index
						break

				# Default timer info if index remains -1
				default_timer_notify = {'shutdown': False, 'keep_warm': False}
				timer_notify_data = control.get('notify_data', [])[timer_notify_index] if timer_notify_index != -1 else default_timer_notify

				timer_active_check = control.get('timer', {}).get('end', 0) - time.time() > 0
				timer_paused_check = bool(control.get('timer', {}).get('paused', 0))

				if timer_active_check or timer_paused_check:
					timer_info = {
						'timer_paused': timer_paused_check,
						'timer_start_time': math.trunc(control.get('timer', {}).get('start', 0)),
						'timer_end_time': math.trunc(control.get('timer', {}).get('end', 0)),
						'timer_paused_time': math.trunc(control.get('timer', {}).get('paused', 0)),
						'timer_active': True,
						'timer_expired': bool(control.get('timer', {}).get('expired', False)),
						'timer_shutdown': bool(timer_notify_data.get('shutdown', False)),
						'timer_keep_warm': bool(timer_notify_data.get('keep_warm', False))
					}
				else:
					timer_info = {
						'timer_paused': False,
						'timer_start_time': 0,
						'timer_end_time': 0,
						'timer_paused_time': 0,
						'timer_active': False,
						'timer_expired': bool(control.get('timer', {}).get('expired', False)),
						'timer_shutdown': bool(timer_notify_data.get('shutdown', False)),
						'timer_keep_warm': bool(timer_notify_data.get('keep_warm', False))
					}

				status_data = {
					'mode': control.get('mode', 'Stop'),  # From control
					'display_mode': status.get('mode', 'Stop'),  # From status
					'status': control.get('status', ''),  # From control
					's_plus': control.get('s_plus', False),  # From control
					'units': settings.get('globals', {}).get('units', 'F'),  # From settings
					'name': settings.get('globals', {}).get('grill_name', ''),  # From settings
					'start_time': status.get('start_time', 0),  # From status
					'start_duration': status.get('start_duration', 0),  # From status
					'shutdown_duration': status.get('shutdown_duration', 0),  # From status
					'prime_duration': status.get('prime_duration', 0),  # From status
					'prime_amount': status.get('prime_amount', 0),  # From status
					'lid_open_detected': status.get('lid_open_detected', False),  # From status
					'lid_open_endtime': status.get('lid_open_endtime', 0),  # From status
					'p_mode': status.get('p_mode', 0),  # From status
					'outpins': status.get('outpins', {}),  # From status
					'startup_timestamp': status.get('startup_timestamp', 0),  # From status
					'recipe': status.get('recipe', False),  # Added from status object
					'recipe_paused': status.get('recipe_paused', False),  # Added from status object
					'hopper_level': pelletdb.get('current',{}).get('hopper_level', 0),  # Added from pelletdb for consistency
				}
				
				current_data = {
					'status_data': status_data,  # Use the newly constructed payload
					'probe_info': probe_info,
					'notify_data': control.get('notify_data', []),
					'timer_info': timer_info,
					'pwm_control': control.get('pwm_control',{})
				}

				if force_refresh:
					print("Force refresh requested, emitting data to all clients.")
					socketio.emit('grill_control_data', current_data)
					force_refresh = False
					previous_data = current_data
				elif previous_data != current_data:
					print("Data changed, emitting data to all clients.")
					socketio.emit('grill_control_data', current_data)
					previous_data = current_data

				socketio.sleep(2)

			except Exception as e:
				print(f"ERROR in emit_dash_data inner loop: {e}")
				import traceback
				traceback.print_exc()  # Print full traceback for debugging
				socketio.sleep(5)  # Avoid busy-loop on error

	finally:
		print("Background task 'emit_dash_data' exiting loop.")
		with background_task_lock:
			print("Setting global thread variable back to None.")
			thread = None

# ==================================================
#  Handler for get_app_data (Handles multiple actions)
# ==================================================
@socketio.on('get_app_data')
def get_app_data(data):
	sid = request.sid
	action = data.get('action')

	print(f"Client {sid} requested 'get_app_data' with data: {data}")
	print(f"Extracted action={action}")

	if action == 'settings_data':
		try:
			# Read the *entire* settings file, which now includes UI settings under webui.dash
			settings = read_settings()
			return settings  # Return the whole object
		except Exception as e:
			print(f"ERROR reading settings: {e}")
			return {'response': {'result':'error', 'message':f'Error: Server error reading settings: {e}'}}
	elif action == 'pellets_data':
		try:
			return read_pellet_db()
		except Exception as e:
			print(f"ERROR reading pellet DB: {e}")
			return {'response': {'result':'error', 'message':f'Error: Server error reading pellet DB: {e}'}}
	elif action == 'status_data':
		try:
			status_data = read_status()
			return status_data
		except Exception as e:
			print(f"ERROR reading status data: {e}")
			return {'response': {'result':'error', 'message':f'Error: Server error reading status data: {e}'}}
	elif action == 'grill_control_data':
		try:
			# Reusing logic from emit_dash_data to construct the response
			settings = read_settings()  # Add this read
			control = read_control()
			status = read_status()
			pelletdb = read_pellet_db()
			probe_info = read_current()

			timer_notify_index = -1
			for index, notify_obj in enumerate(control.get('notify_data', [])):
				if isinstance(notify_obj, dict) and notify_obj.get('type') == 'timer':
					timer_notify_index = index
					break
			default_timer_notify = {'shutdown': False, 'keep_warm': False}
			timer_notify_data = control.get('notify_data', [])[timer_notify_index] if timer_notify_index != -1 else default_timer_notify
			timer_active_check = control.get('timer', {}).get('end', 0) - time.time() > 0
			timer_paused_check = bool(control.get('timer', {}).get('paused', 0))
			if timer_active_check or timer_paused_check:
				timer_info = {
					'timer_paused': timer_paused_check,
					'timer_start_time': math.trunc(control.get('timer', {}).get('start', 0)),
					'timer_end_time': math.trunc(control.get('timer', {}).get('end', 0)),
					'timer_paused_time': math.trunc(control.get('timer', {}).get('paused', 0)),
					'timer_active': True,
					'timer_expired': bool(control.get('timer', {}).get('expired', False)),
					'timer_shutdown': bool(timer_notify_data.get('shutdown', False)),
					'timer_keep_warm': bool(timer_notify_data.get('keep_warm', False))
				}
			else:
				timer_info = {
					'timer_paused': False,
					'timer_start_time': 0,
					'timer_end_time': 0,
					'timer_paused_time': 0,
					'timer_active': False,
					'timer_expired': bool(control.get('timer', {}).get('expired', False)),
					'timer_shutdown': bool(timer_notify_data.get('shutdown', False)),
					'timer_keep_warm': bool(timer_notify_data.get('keep_warm', False))
				}
		
			status_data = {
				'mode': control.get('mode', 'Stop'),  # From control
				'display_mode': status.get('mode', 'Stop'),  # From status
				'status': control.get('status', ''),  # From control
				's_plus': control.get('s_plus', False),  # From control
				'units': settings.get('globals', {}).get('units', 'F'),  # From settings
				'name': settings.get('globals', {}).get('grill_name', ''),  # From settings
				'start_time': status.get('start_time', 0),  # From status
				'start_duration': status.get('start_duration', 0),  # From status
				'shutdown_duration': status.get('shutdown_duration', 0),  # From status
				'prime_duration': status.get('prime_duration', 0),  # From status
				'prime_amount': status.get('prime_amount', 0),  # From status
				'lid_open_detected': status.get('lid_open_detected', False),  # From status
				'lid_open_endtime': status.get('lid_open_endtime', 0),  # From status
				'p_mode': status.get('p_mode', 0),  # From status
				'outpins': status.get('outpins', {}),  # From status
				'startup_timestamp': status.get('startup_timestamp', 0),  # From status
				'recipe': status.get('recipe', False),  # Added from status object
				'recipe_paused': status.get('recipe_paused', False),  # Added from status object
				'hopper_level': pelletdb.get('current',{}).get('hopper_level', 0),  # Added from pelletdb for consistency
			}
			
			current_data = {
				'status_data': status_data,  # Use the newly constructed payload
				'probe_info': probe_info,
				'notify_data': control.get('notify_data', []),
				'timer_info': timer_info,
				'pwm_control': control.get('pwm_control',{})
			}
			return current_data
		except Exception as e:
			print(f"ERROR reading grill control data: {e}")
			return {'response': {'result':'error', 'message':f'Error: Server error reading grill control data: {e}'}}
	elif action == 'events_data':
		try:
			event_list, num_events = read_events()
			events_trim = []
			for x in range(min(num_events, 60)):
				events_trim.append(event_list[x])
			return { 'events_list' : events_trim }
		except Exception as e:
			print(f"ERROR reading events: {e}")
			return {'response': {'result':'error', 'message':f'Error: Server error reading events: {e}'}}
	elif action == 'info_data':
		try:
			settings = read_settings()  # Load fresh settings
			return {
				'uptime' : os.popen('uptime').readline(),
				'cpuinfo' : os.popen('cat /proc/cpuinfo').readlines(),
				'ifconfig' : os.popen('ifconfig').readlines(),
				'temp' : _check_cpu_temp(),  # Ensure this function exists
				'outpins' : settings.get('outpins',{}),
				'inpins' : settings.get('inpins',{}),
				'dev_pins' : settings.get('dev_pins',{}),
				'server_version' : settings.get('versions',{}).get('server','N/A'),
				'server_build' : settings.get('versions',{}).get('build','N/A')
			}
		except Exception as e:
			print(f"ERROR gathering info_data: {e}")
			return {'response': {'result':'error', 'message':f'Error: Server error gathering info data: {e}'}}
	elif action == 'manual_data':
		try:
			control = read_control()
			return {
				'manual' : control.get('manual', False),
				'mode' : control.get('mode', 'Stop')
			}
		except Exception as e:
			print(f"ERROR reading control for manual data: {e}")
			return {'response': {'result':'error', 'message':f'Error: Server error reading control data: {e}'}}
	elif action == 'control_data':
		try:
			control_data = read_control()  # Assuming read_control() fetches the control data
			return {'response': {'result': 'success', 'data': control_data}}
		except Exception as e:
			print(f"Error handling 'control_data': {e}")
			return {'response': {'result': 'error', 'message': str(e)}}
	else:
		print(f"ERROR: Invalid or missing action '{action}' in get_app_data request from {sid}")
		return {'response': {'result':'error', 'message':f"Error: Received request with invalid/missing action ('{action}')"}}

# ==================================================
#  Handler for post_app_data (Handles multiple actions/types)
# ==================================================
def deep_merge(source, destination):
	for key, value in source.items():
		if isinstance(value, dict) and key in destination and isinstance(destination[key], dict):
			deep_merge(value, destination[key])
		else:
			destination[key] = value
	return destination

@socketio.on('post_app_data')
def post_app_data(action=None, type=None, json_data=None):
	"""
	Handle post_app_data event for settings, control, pellets, timer, and admin actions.
	Expects action, type, and json_data (for update_action).
	"""
	sid = request.sid
	print(f"Client {sid} requested 'post_app_data' action={action} type={type}")

	request_data = {}
	if json_data is not None:
		try:
			request_data = json.loads(json_data)
		except json.JSONDecodeError as e:
			print(f"ERROR: Invalid JSON received from {sid}: {e}")
			return {'response': {'result': 'error', 'message': f'Error: Invalid JSON format - {e}'}}
	else:
		if action not in ['timer', 'admin']: # Some actions like timer/admin might not require json_data
			print(f"Warning: post_app_data from {sid} received no json_data for action={action}, type={type}.")
			# Depending on the action/type, this might be an error or expected.
			# For 'update_action', it is generally an error if no data is provided to update.
			if action == 'update_action':
				return {'response': {'result': 'error', 'message': 'No data provided for update_action'}}

	# --- Action Handling ---
	if action == 'update_action':
		if type in ['settings', 'control', 'pellets']:
			try:
				data_dict = None
				broadcast_event = None
				write_func = None

				# Select read/write functions and broadcast event based on type
				if type == 'settings':
					data_dict = read_settings()
					broadcast_event = 'settings_data'
					write_func = write_settings
				elif type == 'control':
					data_dict = read_control()
					broadcast_event = 'control_data'
					write_func = write_control
				elif type == 'pellets':
					data_dict = read_pellet_db()
					broadcast_event = 'pellets_data'
					write_func = write_pellet_db

				if not isinstance(data_dict, dict):
					print(f"ERROR: read function for {type} did not return a dictionary. Got: {type(data_dict)}")
					return {'response': {'result': 'error', 'message': f'Error: Failed to load {type} data'}}

				# Create a deep copy for change detection
				original_data = copy.deepcopy(data_dict)

				# Merge the incoming data
				if request_data:
					print(f"Deep merging {type} updates from {sid}: {request_data}")
					deep_merge(request_data, data_dict)
				else:
					# This case should ideally be handled by the initial json_data check for update_action
					print(f"No data to merge for {type} update by {sid} (request_data is empty).")
					return {'response': {'result': 'success', 'message': 'No changes applied as no data was provided in request_data'}}

				# Check if data changed
				if original_data != data_dict:
					print(f"DEBUG: Data for '{type}' has changed. Attempting write by {sid}.")
					
					raw_write_result = None  # Variable to store the direct return from write_func
					
					# Call the appropriate write function
					if type == 'control':
						print(f"DEBUG: Calling write_control with origin='app-socketio' for SID {sid}")
						raw_write_result = write_func(data_dict, origin='app-socketio')
					else:  # This covers 'settings' and 'pellets'
						print(f"DEBUG: Calling {write_func.__name__} without explicit origin for SID {sid}")
						raw_write_result = write_func(data_dict)

					# Determine actual success based on type and raw_write_result
					operation_deemed_successful = False
					if type in ['settings', 'control']:
						# For 'settings' and 'control', treat None (implicit success) or True (explicit success) as success
						if raw_write_result is None or raw_write_result is True:
							operation_deemed_successful = True
							if raw_write_result is None:
								print(f"INFO: {write_func.__name__} for type '{type}' returned None, interpreted as success by handler.")
						# Otherwise (e.g., if False is returned), it's a failure
					elif raw_write_result is True:
						# For other types (e.g., 'pellets'), require an explicit True for success
						operation_deemed_successful = True
					# If raw_write_result is False for any type, operation_deemed_successful remains False.

					if operation_deemed_successful:
						print(f"{type.capitalize()} updated successfully by {sid}")
						socketio.emit(broadcast_event, data_dict, room=request.namespace, skip_sid=sid)
						return {'response': {'result': 'success', 'message': f'{type.capitalize()} updated'}}
					else:
						print(f"ERROR writing updated {type} by {sid} using {write_func.__name__}. "
								f"Write function returned: '{raw_write_result}'. Operation deemed failed by handler.")
						if type == 'control':
							print(f"DEBUG (on error): write_control was called with data: {data_dict} and origin='app-socketio'")
						else:
							print(f"DEBUG (on error): {write_func.__name__} was called with data: {data_dict}")
						return {'response': {'result': 'error', 'message': f'Error: Failed to write {type} on server'}}
				else:
					print(f"No {type} changes detected after merge for update by {sid}. Original: {original_data}, New: {data_dict}")
					return {'response': {'result': 'success', 'message': 'No changes applied as data was identical'}}

			except Exception as e:
				import traceback
				print(f"ERROR updating {type} by {sid}: {e}")
				traceback.print_exc()
				return {'response': {'result': 'error', 'message': f'Error updating {type}: {str(e)}'}}
		else:
			print(f"ERROR: Invalid type '{type}' for update_action from {sid}")
			return {'response': {'result': 'error', 'message': 'Invalid type for update_action'}}
	elif action == 'admin_action':
		print(f"Admin action '{type}' requested by {sid}")
		if type == 'clear_history':
			try:
				write_log(f'Clearing History Log (requested by {sid}).')
				read_history(0, flushhistory=True)
				return {'response': {'result':'success'}}
			except Exception as e:
				print(f"ERROR clearing history: {e}")
				return {'response': {'result':'error', 'message': f'Error clearing history: {str(e)}'}}
		elif type == 'clear_events':
			try:
				write_log(f'Clearing Events Log (requested by {sid}).')
				if os.path.exists('/tmp/events.log'):
					os.remove('/tmp/events.log')
				else:
					print("Event log file /tmp/events.log not found, nothing to remove.")
				return {'response': {'result':'success'}}
			except Exception as e:
				print(f"ERROR clearing events: {e}")
				return {'response': {'result':'error', 'message': f'Error clearing events: {str(e)}'}}
		elif type == 'reboot':
			try:
				write_log(f"Admin: Reboot (requested by {sid})")
				os.system("sleep 3 && sudo reboot &")
				return {'response': {'result':'success'}}
			except Exception as e:
				print(f"ERROR executing reboot: {e}")
				return {'response': {'result':'error', 'message':f'Error executing reboot: {str(e)}'}}
		elif type == 'shutdown':
			try:
				write_log(f"Admin: Shutdown (requested by {sid})")
				os.system("sleep 3 && sudo shutdown -h now &")
				return {'response': {'result':'success'}}
			except Exception as e:
				print(f"ERROR executing shutdown: {e}")
				return {'response': {'result':'error', 'message':f'Error executing shutdown: {str(e)}'}}
		elif type == 'restart':
			try:
				write_log(f"Admin: Restart Server (requested by {sid})")
				restart_scripts()  # Ensure this function exists and works
				return {'response': {'result':'success'}}
			except Exception as e:
				print(f"ERROR executing restart: {e}")
				return {'response': {'result':'error', 'message':f'Error executing restart: {str(e)}'}}
		else:
			return {'response': {'result':'error', 'message':'Error: Received request without valid type for admin_action'}}
	elif action == 'units_action':
		print(f"Units action '{type}' requested by {sid}")
		try:
			settings = read_settings()  # Load fresh settings
			if type == 'f_units' and settings.get('globals', {}).get('units') == 'C':
				settings = convert_settings_units('F', settings)
				write_settings(settings)
				control = read_control()
				control['updated'] = True
				control['units_change'] = True
				write_control(control, origin='app-socketio')
				write_log("Changed units to Fahrenheit")
				return {'response': {'result':'success'}}
			elif type == 'c_units' and settings.get('globals', {}).get('units') == 'F':
				settings = convert_settings_units('C', settings)
				write_settings(settings)
				control = read_control()
				control['updated'] = True
				control['units_change'] = True
				write_control(control, origin='app-socketio')
				write_log("Changed units to Celsius")
				return {'response': {'result':'success'}}
			else:
				current_units = settings.get('globals', {}).get('units', 'N/A')
				print(f"Units change requested ({type}) but current units are {current_units}. No change needed or invalid request.")
				return {'response': {'result':'success', 'message': 'Units already set or invalid request'}}
		except Exception as e:
			print(f"ERROR changing units: {e}")
			traceback.print_exc()
			return {'response': {'result':'error', 'message':f'Error changing units: {str(e)}'}}
	elif action == 'remove_action':
		print(f"Remove action '{type}' requested by {sid}")
		try:
			if type == 'onesignal_device':
				device_id = request_data.get('onesignal_device', {}).get('onesignal_player_id')
				if device_id:
					settings = read_settings()  # Load fresh settings
					if device_id in settings.get('onesignal', {}).get('devices', {}):
						settings['onesignal']['devices'].pop(device_id)
						write_settings(settings)
						print(f"Removed onesignal device {device_id}")
						return {'response': {'result':'success'}}
					else:
						return {'response': {'result':'error', 'message':'Error: Device not found in settings'}}
				else:
					return {'response': {'result':'error', 'message':'Error: Device not specified in request'}}
			else:
				return {'response': {'result':'error', 'message':'Error: Remove type not found'}}
		except Exception as e:
			print(f"ERROR removing item ({type}): {e}")
			traceback.print_exc()
			return {'response': {'result':'error', 'message':f'Error removing item: {str(e)}'}}
	elif action == 'pellets_action':
		print(f"Pellets action '{type}' requested by {sid}")
		try:
			pelletdb = read_pellet_db()
			if type == 'load_profile':
				profile = request_data.get('pellets_action', {}).get('profile')
				if profile:
					pelletdb['current']['pelletid'] = profile
					now_dt = datetime.datetime.now()
					now = now_dt.strftime("%Y-%m-%d %H:%M:%S")
					pelletdb['current']['date_loaded'] = now
					pelletdb['current']['est_usage'] = 0  # Reset usage on load
					pelletdb.setdefault('log', {})[now] = profile
					control = read_control()
					control['hopper_check'] = True  # Trigger check
					write_control(control, origin='app-socketio')
					write_pellet_db(pelletdb)
					print(f"Loaded pellet profile {profile}")
					return {'response': {'result':'success'}}
				else:
					return {'response': {'result':'error', 'message':'Error: Profile not included in request'}}
			elif type == 'add_profile':
				brand = request_data.get('pellets_action', {}).get('brand_name')
				wood = request_data.get('pellets_action', {}).get('wood_type')
				rating = request_data.get('pellets_action', {}).get('rating')
				comments = request_data.get('pellets_action', {}).get('comments')
				add_and_load = request_data.get('pellets_action', {}).get('add_and_load', False)

				if not all([brand, wood, rating is not None, comments is not None]):
					return {'response': {'result':'error', 'message':'Error: Missing fields for add_profile'}}

				profile_id = ''.join(filter(str.isalnum, str(datetime.datetime.now())))
				pelletdb.setdefault('archive', {})[profile_id] = { 'id' : profile_id, 'brand' : brand, 'wood' : wood, 'rating' : rating, 'comments' : comments }

				if add_and_load:
					pelletdb['current']['pelletid'] = profile_id
					now_dt = datetime.datetime.now()
					now = now_dt.strftime("%Y-%m-%d %H:%M:%S")
					pelletdb['current']['date_loaded'] = now
					pelletdb['current']['est_usage'] = 0  # Reset usage
					pelletdb.setdefault('log', {})[now] = profile_id
					control = read_control()
					control['hopper_check'] = True  # Trigger check
					write_control(control, origin='app-socketio')

				write_pellet_db(pelletdb)
				print(f"Added pellet profile {profile_id}. Loaded={add_and_load}")
				return {'response': {'result':'success'}}
			else:
				return {'response': {'result':'error', 'message':'Error: Received request without valid type for pellets_action'}}
		except Exception as e:
			print(f"ERROR during pellets_action ({type}): {e}")
			traceback.print_exc()
			return {'response': {'result':'error', 'message':f'Error during pellets action: {str(e)}'}}
	elif action == 'timer_action':
		print(f"Timer action '{type}' requested by {sid}")
		try:
			control = read_control()
			timer_notify_index = -1
			# Ensure notify_data exists and is a list
			if 'notify_data' not in control or not isinstance(control['notify_data'], list):
				control['notify_data'] = [] # Initialize if not present or wrong type

			for index, notify_obj in enumerate(control.get('notify_data', [])):
				if isinstance(notify_obj, dict) and notify_obj.get('type') == 'timer':
					timer_notify_index = index
					break
			
			# If timer config doesn't exist in notify_data, create it
			if timer_notify_index == -1 and type != 'stop_timer': # Don't create if trying to stop a non-existent timer
				control['notify_data'].append({
					'type': 'timer',
					'req': False,
					'shutdown': False,
					'keep_warm': False,
					'name': 'Timer Notification' # Default name
				})
				timer_notify_index = len(control['notify_data']) - 1
				print(f"DEBUG: Created new timer notification config at index {timer_notify_index}")


			if type == 'start_timer':
				if timer_notify_index == -1: # Should have been created above, but as a safeguard
					print(f"ERROR: Timer notification config still not found for {sid} after attempting creation.")
					return {'response': {'result':'error', 'message':'Error: Timer notification config could not be initialized'}}

				control['notify_data'][timer_notify_index]['req'] = True
				if control.get('timer',{}).get('paused', 0) == 0:  # Start new timer
					now = time.time()
					control.setdefault('timer', {})['start'] = now
					hours = request_data.get('timer_action', {}).get('hours_range', 0)
					minutes = request_data.get('timer_action', {}).get('minutes_range', 0)
					timer_shutdown = request_data.get('timer_action', {}).get('timer_shutdown', False)
					timer_keep_warm = request_data.get('timer_action', {}).get('timer_keep_warm', False)

					if hours is None or minutes is None: # Should be caught by client, but good to check
						return {'response': {'result':'error', 'message':'Error: Timer duration not specified'}}

					seconds = int(hours) * 3600 + int(minutes) * 60
					if seconds <= 0:
						return {'response': {'result':'error', 'message':'Error: Invalid timer duration'}}

					control['timer']['end'] = now + seconds
					control['timer']['paused'] = 0  # Ensure not paused
					control['timer']['expired'] = False  # Ensure not expired
					control['notify_data'][timer_notify_index]['shutdown'] = timer_shutdown
					control['notify_data'][timer_notify_index]['keep_warm'] = timer_keep_warm
					end_time_str = datetime.datetime.fromtimestamp(control['timer']['end']).strftime('%Y-%m-%d %H:%M:%S')
					write_log(f'Timer started by {sid}. Ends at: {end_time_str}')
				else:  # Resuming from pause
					now = time.time()
					time_left_when_paused = control['timer']['end'] - control['timer']['paused']
					control['timer']['end'] = now + time_left_when_paused
					control['timer']['paused'] = 0  # Unpause
					end_time_str = datetime.datetime.fromtimestamp(control['timer']['end']).strftime('%Y-%m-%d %H:%M:%S')
					write_log(f'Timer unpaused by {sid}. Ends at: {end_time_str}')

				write_control(control, origin='app-socketio')
				return {'response': {'result':'success'}}
			elif type == 'pause_timer':
				if timer_notify_index == -1:
					return {'response': {'result':'error', 'message':'Error: Timer not configured to be paused.'}}
				if control.get('timer',{}).get('end', 0) > time.time() and control.get('timer',{}).get('paused', 0) == 0:
					control['notify_data'][timer_notify_index]['req'] = False
					now = time.time()
					control['timer']['paused'] = now
					write_log(f'Timer paused by {sid}.')
					write_control(control, origin='app-socketio')
					return {'response': {'result':'success'}}
				else:
					return {'response': {'result':'error', 'message':'Error: Timer not active or already paused'}}
			elif type == 'stop_timer':
				if timer_notify_index != -1: # Only modify if timer config exists
					control['notify_data'][timer_notify_index]['req'] = False
					control['notify_data'][timer_notify_index]['shutdown'] = False
					control['notify_data'][timer_notify_index]['keep_warm'] = False
				
				control.setdefault('timer', {})['start'] = 0
				control['timer']['end'] = 0
				control['timer']['paused'] = 0
				control['timer']['expired'] = False  # Reset expired flag
				write_log(f'Timer stopped by {sid}.')
				write_control(control, origin='app-socketio')
				return {'response': {'result':'success'}}
			else:
				return {'response': {'result':'error', 'message':'Error: Received request without valid type for timer_action'}}
		except Exception as e:
			print(f"ERROR during timer_action ({type}) by {sid}: {e}")
			traceback.print_exc()
			return {'response': {'result':'error', 'message':f'Error during timer action: {str(e)}'}}
	else:
		print(f"Error: Received request from {sid} without valid action. Action: '{action}', Type: '{type}'")
		return {'response': {'result':'error', 'message':'Error: Received request without valid action'}}

'''
==============================================================================
Main Program Start
==============================================================================
'''
settings = read_settings(init=True)

if __name__ == '__main__':
	if is_real_hardware():
		socketio.run(app, host='0.0.0.0')
	else:
		socketio.run(app, host='0.0.0.0', debug=True)
