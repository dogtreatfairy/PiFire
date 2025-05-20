import time
import math
import json
import copy
import os
import datetime
import traceback
from flask import request
from flask_socketio import SocketIO
from threading import Lock
from common.common import *

socketio = SocketIO()
background_task_lock = Lock()
thread = None
clients = 0
force_refresh = False

# --- Existing connect, disconnect, get_dash_data, emit_dash_data functions remain unchanged ---
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
				settings = read_settings()
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
					'mode': control.get('mode', 'Stop'),
					'display_mode': status.get('mode', 'Stop'),
					'status': control.get('status', ''),
					's_plus': control.get('s_plus', False),
					'units': settings.get('globals', {}).get('units', 'F'),
					'name': settings.get('globals', {}).get('grill_name', ''),
					'start_time': status.get('start_time', 0),
					'start_duration': status.get('start_duration', 0),
					'shutdown_duration': status.get('shutdown_duration', 0),
					'prime_duration': status.get('prime_duration', 0),
					'prime_amount': status.get('prime_amount', 0),
					'lid_open_detected': status.get('lid_open_detected', False),
					'lid_open_endtime': status.get('lid_open_endtime', 0),
					'p_mode': status.get('p_mode', 0),
					'outpins': status.get('outpins', {}),
					'startup_timestamp': status.get('startup_timestamp', 0),
					'recipe': status.get('recipe', False),
					'recipe_paused': status.get('recipe_paused', False),
					'hopper_level': pelletdb.get('current',{}).get('hopper_level', 0),
				}
				
				current_data = {
					'status_data': status_data,
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
				traceback.print_exc()
				socketio.sleep(5)

	finally:
		print("Background task 'emit_dash_data' exiting loop.")
		with background_task_lock:
			print("Setting global thread variable back to None.")
			thread = None

# ==================================================
#  Handler for get_app_data (Unchanged as requested)
# ==================================================
@socketio.on('get_app_data')
def get_app_data(data):
	sid = request.sid
	action = data.get('action')

	print(f"Client {sid} requested 'get_app_data' with data: {data}")
	print(f"Extracted action={action}")

	if action == 'settings_data':
		try:
			settings = read_settings()
			return settings
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
			settings = read_settings()
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
				'mode': control.get('mode', 'Stop'),
				'display_mode': status.get('mode', 'Stop'),
				'status': control.get('status', ''),
				's_plus': control.get('s_plus', False),
				'units': settings.get('globals', {}).get('units', 'F'),
				'name': settings.get('globals', {}).get('grill_name', ''),
				'start_time': status.get('start_time', 0),
				'start_duration': status.get('start_duration', 0),
				'shutdown_duration': status.get('shutdown_duration', 0),
				'prime_duration': status.get('prime_duration', 0),
				'prime_amount': status.get('prime_amount', 0),
				'lid_open_detected': status.get('lid_open_detected', False),
				'lid_open_endtime': status.get('lid_open_endtime', 0),
				'p_mode': status.get('p_mode', 0),
				'outpins': status.get('outpins', {}),
				'startup_timestamp': status.get('startup_timestamp', 0),
				'recipe': status.get('recipe', False),
				'recipe_paused': status.get('recipe_paused', False),
				'hopper_level': pelletdb.get('current',{}).get('hopper_level', 0),
			}
			
			current_data = {
				'status_data': status_data,
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
			settings = read_settings()
			return {
				'uptime' : os.popen('uptime').readline(),
				'cpuinfo' : os.popen('cat /proc/cpuinfo').readlines(),
				'ifconfig' : os.popen('ifconfig').readlines(),
				'temp' : _check_cpu_temp(),
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
			control_data = read_control()
			return {'response': {'result': 'success', 'data': control_data}}
		except Exception as e:
			print(f"Error handling 'control_data': {e}")
			return {'response': {'result': 'error', 'message': str(e)}}
	else:
		print(f"ERROR: Invalid or missing action '{action}' in get_app_data request from {sid}")
		return {'response': {'result':'error', 'message':f"Error: Received request with invalid/missing action ('{action}')"}}

# ==================================================
#  Modernized Handler for post_app_data
# ==================================================
def deep_merge(source, destination):
	"""Deep merge two dictionaries, updating destination in place."""
	for key, value in source.items():
		if isinstance(value, dict) and key in destination and isinstance(destination[key], dict):
			deep_merge(value, destination[key])
		else:
			destination[key] = value
	return destination

def is_float(value):
	"""Check if a value can be converted to a float."""
	try:
		float(value)
		return True
	except (ValueError, TypeError):
		return False

@socketio.on('post_app_data')
def post_app_data(action, json_data=None, value=None):
	"""
	Modernized handler for machine control updates.
	- action: 'control', 'manual', 'settings', 'pellets', 'admin', 'units', 'remove', 'pellets_action', 'timer'
	- json_data: Dictionary for 'control', 'settings', 'pellets', or action-specific data
	- value: For 'manual', specifies the component value (e.g., True, False, or PWM number)
	"""
	sid = request.sid
	print(f"Client {sid} requested 'post_app_data' with action={action}, json_data={json_data}, value={value}")
	write_log(f"Client {sid} post_app_data: action={action}, json_data={json_data}, value={value}")

	if not action:
		print(f"ERROR: No action provided by {sid}")
		write_log(f"ERROR: No action provided by {sid}")
		return {'response': {'result': 'error', 'message': 'No action specified'}}

	request_data = {}
	if json_data is not None:
		try:
			if isinstance(json_data, str):
				request_data = json.loads(json_data)
			elif isinstance(json_data, dict):
				request_data = json_data
			else:
				raise ValueError("json_data must be a string or dictionary")
		except (json.JSONDecodeError, ValueError) as e:
			print(f"ERROR: Invalid JSON from {sid}: {e}")
			write_log(f"ERROR: Invalid JSON from {sid}: {e}")
			return {'response': {'result': 'error', 'message': f'Invalid JSON format: {e}'}}
	elif action in ['control', 'settings', 'pellets'] and value is None:
		print(f"WARNING: No json_data provided for {action} by {sid}")
		write_log(f"WARNING: No json_data for {action} by {sid}")
		return {'response': {'result': 'error', 'message': 'No data provided'}}

	# --- Core Data Updates ---
	if action in ['control', 'settings']:
		try:
			data_dict = None
			broadcast_event = None
			write_func = None

			if action == 'control':
				data_dict = read_control()
				broadcast_event = 'control_data'
				write_func = write_control
			elif action == 'settings':
				data_dict = read_settings()
				broadcast_event = 'settings_data'
				write_func = write_settings

			if not isinstance(data_dict, dict):
				print(f"ERROR: Invalid data for {action} from {sid}")
				write_log(f"ERROR: Invalid data for {action} from {sid}")
				return {'response': {'result': 'error', 'message': f'Failed to load {action} data'}}

			original_data = copy.deepcopy(data_dict)
			if request_data:
				deep_merge(request_data, data_dict)
			else:
				print(f"INFO: No changes for {action} by {sid} (empty request_data)")
				write_log(f"INFO: No changes for {action} by {sid}")
				return {'response': {'result': 'success', 'message': 'No changes applied'}}

			if original_data != data_dict:
				print(f"DEBUG: {action} data changed by {sid}")
				write_log(f"DEBUG: {action} data changed by {sid}")
				result = write_func(data_dict, origin='app-socketio') if action == 'control' else write_func(data_dict)
				if result is None or result is True:
					socketio.emit(broadcast_event, data_dict, room=request.namespace, skip_sid=sid)
					print(f"{action.capitalize()} updated by {sid}")
					write_log(f"{action.capitalize()} updated by {sid}")
					return {'response': {'result': 'success', 'message': f'{action.capitalize()} updated'}}
				else:
					print(f"ERROR: Failed to write {action} for {sid}")
					write_log(f"ERROR: Failed to write {action} for {sid}")
					return {'response': {'result': 'error', 'message': f'Failed to write {action}'}}
			else:
				print(f"INFO: No changes detected for {action} by {sid}")
				write_log(f"INFO: No changes detected for {action} by {sid}")
				return {'response': {'result': 'success', 'message': 'No changes applied'}}

		except Exception as e:
			print(f"ERROR updating {action} by {sid}: {e}")
			write_log(f"ERROR updating {action} by {sid}: {e}")
			traceback.print_exc()
			return {'response': {'result': 'error', 'message': f'Error updating {action}: {e}'}}

	elif action == 'manual':
		try:
			if not json_data or not isinstance(json_data, str):
				print(f"ERROR: Invalid component for manual action by {sid}")
				write_log(f"ERROR: Invalid component for manual action by {sid}")
				return {'response': {'result': 'error', 'message': 'Component must be specified as a string'}}

			component = json_data
			if component not in ['power', 'igniter', 'fan', 'auger', 'pwm']:
				print(f"ERROR: Invalid component '{component}' from {sid}")
				write_log(f"ERROR: Invalid component '{component}' from {sid}")
				return {'response': {'result': 'error', 'message': f'Invalid component: {component}'}} 

			control = read_control()
			settings = read_settings()
			if control.get('mode') != 'Manual' and not settings.get('safety', {}).get('allow_manual_changes', False):
				print(f"ERROR: Manual mode required for {sid}")
				write_log(f"ERROR: Manual mode required for {sid}")
				return {'response': {'result': 'error', 'message': 'System must be in Manual mode or allow_manual_changes enabled'}}

			control.setdefault('manual', {})
			control['manual']['change'] = component

			if component == 'pwm':
				if not is_float(value):
					print(f"ERROR: Invalid PWM value '{value}' from {sid}")
					write_log(f"ERROR: Invalid PWM value '{value}' from {sid}")
					return {'response': {'result': 'error', 'message': 'PWM value must be a number'}}
				value = int(float(value))
				if not (0 <= value <= 100):  # Keeping range check for safety
					print(f"ERROR: PWM value '{value}' out of range from {sid}")
					write_log(f"ERROR: PWM value '{value}' out of range from {sid}")
					return {'response': {'result': 'error', 'message': 'PWM value must be 0-100'}}
				control['manual']['output'] = True
				control['manual']['pwm'] = value
			else:
				# Handle toggle or boolean values
				if value == 'toggle':
					status = read_status()
					current_state = status['outpins'].get(component, False)
					value = not current_state
				elif value not in [True, False]:
					print(f"ERROR: Invalid value '{value}' for {component} from {sid}")
					write_log(f"ERROR: Invalid value '{value}' for {component} from {sid}")
					return {'response': {'result': 'error', 'message': f'Value for {component} must be True, False, or "toggle"'}}

				control['manual']['output'] = value
				if component == 'fan' and not value:
					control['manual']['pwm'] = 100  # Reset PWM when fan is off

			write_control(control, origin='app-socketio')
			socketio.emit('control_data', control, room=request.namespace, skip_sid=sid)
			print(f"Manual control updated by {sid}: {component}={value}")
			write_log(f"Manual control updated by {sid}: {component}={value}")
			return {'response': {'result': 'success', 'message': 'Manual control updated'}}

		except Exception as e:
			print(f"ERROR updating manual control by {sid}: {e}")
			write_log(f"ERROR updating manual control by {sid}: {e}")
			traceback.print_exc()
			return {'response': {'result': 'error', 'message': f'Error updating manual control: {e}'}}

	# --- Existing Actions (Minimally Changed) ---
	elif action == 'admin':
		try:
			admin_type = request_data.get('type')
			if admin_type == 'clear_history':
				write_log(f'Clearing History Log by {sid}')
				read_history(0, flushhistory=True)
				return {'response': {'result': 'success'}}
			elif admin_type == 'clear_events':
				write_log(f'Clearing Events Log by {sid}')
				if os.path.exists('/tmp/events.log'):
					os.remove('/tmp/events.log')
				return {'response': {'result': 'success'}}
			elif admin_type == 'reboot':
				write_log(f"Admin: Reboot by {sid}")
				os.system("sleep 3 && sudo reboot &")
				return {'response': {'result': 'success'}}
			elif admin_type == 'shutdown':
				write_log(f"Admin: Shutdown by {sid}")
				os.system("sleep 3 && sudo shutdown -h now &")
				return {'response': {'result': 'success'}}
			elif admin_type == 'restart':
				write_log(f"Admin: Restart Server by {sid}")
				restart_scripts()
				return {'response': {'result': 'success'}}
			else:
				return {'response': {'result': 'error', 'message': 'Invalid admin action'}}
		except Exception as e:
			print(f"ERROR in admin action by {sid}: {e}")
			write_log(f"ERROR in admin action by {sid}: {e}")
			return {'response': {'result': 'error', 'message': f'Admin error: {e}'}} 

	elif action == 'units':
		try:
			unit_type = request_data.get('type')
			settings = read_settings()
			if unit_type == 'f_units' and settings.get('globals', {}).get('units') == 'C':
				settings = convert_settings_units('F', settings)
				write_settings(settings)
				control = read_control()
				control['updated'] = True
				control['units_change'] = True
				write_control(control, origin='app-socketio')
				write_log(f"Units changed to Fahrenheit by {sid}")
				return {'response': {'result': 'success'}}
			elif unit_type == 'c_units' and settings.get('globals', {}).get('units') == 'F':
				settings = convert_settings_units('C', settings)
				write_settings(settings)
				control = read_control()
				control['updated'] = True
				control['units_change'] = True
				write_control(control, origin='app-socketio')
				write_log(f"Units changed to Celsius by {sid}")
				return {'response': {'result': 'success'}}
			else:
				return {'response': {'result': 'success', 'message': 'Units already set or invalid request'}}
		except Exception as e:
			print(f"ERROR changing units by {sid}: {e}")
			write_log(f"ERROR changing units by {sid}: {e}")
			return {'response': {'result': 'error', 'message': f'Error changing units: {e}'}} 

	elif action == 'remove':
		try:
			if request_data.get('type') == 'onesignal_device':
				device_id = request_data.get('onesignal_device', {}).get('onesignal_player_id')
				if device_id:
					settings = read_settings()
					if device_id in settings.get('onesignal', {}).get('devices', {}):
						settings['onesignal']['devices'].pop(device_id)
						write_settings(settings)
						write_log(f"Removed OneSignal device {device_id} by {sid}")
						return {'response': {'result': 'success'}}
					return {'response': {'result': 'error', 'message': 'Device not found'}}
				return {'response': {'result': 'error', 'message': 'Device not specified'}}
			return {'response': {'result': 'error', 'message': 'Invalid remove type'}}
		except Exception as e:
			print(f"ERROR removing item by {sid}: {e}")
			write_log(f"ERROR removing item by {sid}: {e}")
			return {'response': {'result': 'error', 'message': f'Error removing item: {e}'}} 

	elif action == 'pellets':
		try:
			pelletdb = read_pellet_db()
			pellet_type = request_data.get('type')
			if pellet_type == 'load_profile':
				profile = request_data.get('profile')
				if profile:
					pelletdb['current']['pelletid'] = profile
					now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
					pelletdb['current']['date_loaded'] = now
					pelletdb['current']['est_usage'] = 0
					pelletdb.setdefault('log', {})[now] = profile
					control = read_control()
					control['hopper_check'] = True
					write_control(control, origin='app-socketio')
					write_pellet_db(pelletdb)
					write_log(f"Loaded pellet profile {profile} by {sid}")
					return {'response': {'result': 'success'}}
				return {'response': {'result': 'error', 'message': 'Profile not specified'}}
			elif pellet_type == 'add_profile':
				brand = request_data.get('brand_name')
				wood = request_data.get('wood_type')
				rating = request_data.get('rating')
				comments = request_data.get('comments')
				add_and_load = request_data.get('add_and_load', False)
				if not all([brand, wood, rating is not None, comments is not None]):
					return {'response': {'result': 'error', 'message': 'Missing fields for add_profile'}}
				profile_id = ''.join(filter(str.isalnum, str(datetime.datetime.now())))
				pelletdb.setdefault('archive', {})[profile_id] = {'id': profile_id, 'brand': brand, 'wood': wood, 'rating': rating, 'comments': comments}
				if add_and_load:
					pelletdb['current']['pelletid'] = profile_id
					now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
					pelletdb['current']['date_loaded'] = now
					pelletdb['current']['est_usage'] = 0
					pelletdb.setdefault('log', {})[now] = profile_id
					control = read_control()
					control['hopper_check'] = True
					write_control(control, origin='app-socketio')
				write_pellet_db(pelletdb)
				write_log(f"Added pellet profile {profile_id} by {sid}, loaded={add_and_load}")
				return {'response': {'result': 'success'}}
			return {'response': {'result': 'error', 'message': 'Invalid pellets_action type'}}
		except Exception as e:
			print(f"ERROR in pellets_action by {sid}: {e}")
			write_log(f"ERROR in pellets_action by {sid}: {e}")
			return {'response': {'result': 'error', 'message': f'Pellets action error: {e}'}} 

	elif action == 'timer':
		try:
			control = read_control()
			if 'notify_data' not in control or not isinstance(control['notify_data'], list):
				control['notify_data'] = []
			timer_notify_index = -1
			for index, notify_obj in enumerate(control.get('notify_data', [])):
				if isinstance(notify_obj, dict) and notify_obj.get('type') == 'timer':
					timer_notify_index = index
					break
			timer_type = request_data.get('type')
			if timer_notify_index == -1 and timer_type != 'stop_timer':
				control['notify_data'].append({'type': 'timer', 'req': False, 'shutdown': False, 'keep_warm': False, 'name': 'Timer Notification'})
				timer_notify_index = len(control['notify_data']) - 1

			if timer_type == 'start_timer':
				control['notify_data'][timer_notify_index]['req'] = True
				if control.get('timer', {}).get('paused', 0) == 0:
					now = time.time()
					control.setdefault('timer', {})['start'] = now
					hours = request_data.get('hours_range', 0)
					minutes = request_data.get('minutes_range', 0)
					timer_shutdown = request_data.get('timer_shutdown', False)
					timer_keep_warm = request_data.get('timer_keep_warm', False)
					seconds = int(hours) * 3600 + int(minutes) * 60
					if seconds <= 0:
						return {'response': {'result': 'error', 'message': 'Invalid timer duration'}}
					control['timer']['end'] = now + seconds
					control['timer']['paused'] = 0
					control['timer']['expired'] = False
					control['notify_data'][timer_notify_index]['shutdown'] = timer_shutdown
					control['notify_data'][timer_notify_index]['keep_warm'] = timer_keep_warm
					end_time_str = datetime.datetime.fromtimestamp(control['timer']['end']).strftime('%Y-%m-%d %H:%M:%S')
					write_log(f'Timer started by {sid}. Ends at: {end_time_str}')
				else:
					now = time.time()
					time_left = control['timer']['end'] - control['timer']['paused']
					control['timer']['end'] = now + time_left
					control['timer']['paused'] = 0
					end_time_str = datetime.datetime.fromtimestamp(control['timer']['end']).strftime('%Y-%m-%d %H:%M:%S')
					write_log(f'Timer unpaused by {sid}. Ends at: {end_time_str}')
				write_control(control, origin='app-socketio')
				return {'response': {'result': 'success'}}
			elif timer_type == 'pause_timer':
				if timer_notify_index == -1 or control.get('timer', {}).get('paused', 0) != 0:
					return {'response': {'result': 'error', 'message': 'Timer not active or already paused'}}
				control['notify_data'][timer_notify_index]['req'] = False
				control['timer']['paused'] = time.time()
				write_log(f'Timer paused by {sid}')
				write_control(control, origin='app-socketio')
				return {'response': {'result': 'success'}}
			elif timer_type == 'stop_timer':
				if timer_notify_index != -1:
					control['notify_data'][timer_notify_index]['req'] = False
					control['notify_data'][timer_notify_index]['shutdown'] = False
					control['notify_data'][timer_notify_index]['keep_warm'] = False
				control.setdefault('timer', {})['start'] = 0
				control['timer']['end'] = 0
				control['timer']['paused'] = 0
				control['timer']['expired'] = False
				write_log(f'Timer stopped by {sid}')
				write_control(control, origin='app-socketio')
				return {'response': {'result': 'success'}}
			return {'response': {'result': 'error', 'message': 'Invalid timer action'}}
		except Exception as e:
			print(f"ERROR in timer action by {sid}: {e}")
			write_log(f"ERROR in timer action by {sid}: {e}")
			return {'response': {'result': 'error', 'message': f'Timer error: {e}'}} 

	else:
		print(f"ERROR: Invalid action '{action}' from {sid}")
		write_log(f"ERROR: Invalid action '{action}' from {sid}")
		return {'response': {'result': 'error', 'message': f'Invalid action: {action}'}}