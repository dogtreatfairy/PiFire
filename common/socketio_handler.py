# socketio_handler.py
# Handles SocketIO connections and data exchange for the PiFire grill controller.

import os
import time
import threading
import json
import logging 
import math 

from flask import request
from flask_socketio import SocketIO, emit
from threading import Lock

from .common import *

# --- Globals & Configuration ---
async_mode = None 
socketio = SocketIO(async_mode=async_mode) 

clients_lock = Lock()
thread = None 
clients = 0  
force_refresh = False 

logger = logging.getLogger(__name__)

EMIT_INTERVAL = 1  # Seconds

stop_emitter_event = threading.Event()

# --- Helper function to build the main/comprehensive dashboard data payload ---
def _build_main_dashboard_payload():
	"""
	Constructs the comprehensive data object intended for the main dashboard display.
	This object aggregates data from settings, control state, current status, pellets, and probes.
	"""
	settings = read_settings()
	control = read_control()  # Data from control:general (intended state, flags)
	current_hw_status = read_status()  # Data from control:status (actual hardware state, display mode)
	pelletdb = read_pellet_db()
	current_temps = read_current()  # Data from control:current (probe temps, target temps)

	# Timer Info Processing
	timer_notify_index = -1
	for index, notify_obj in enumerate(control.get('notify_data', [])):
		if isinstance(notify_obj, dict) and notify_obj.get('type') == 'timer':
			timer_notify_index = index
			break
	
	default_timer_notify_obj = {'shutdown': False, 'keep_warm': False, 'req': False} 
	timer_notify_data_obj = control.get('notify_data', [])[timer_notify_index] if timer_notify_index != -1 else default_timer_notify_obj
	
	timer_end_time = control.get('timer', {}).get('end', 0)
	timer_start_time = control.get('timer', {}).get('start', 0)
	timer_paused_at_time = control.get('timer', {}).get('paused', 0)

	timer_is_active = False
	if timer_start_time > 0 and timer_paused_at_time == 0 and timer_end_time > time.time(): 
		timer_is_active = True
	elif timer_start_time > 0 and timer_paused_at_time > 0: 
		timer_is_active = True 

	timer_info_block = {
		'timer_paused': bool(timer_paused_at_time),
		'timer_start_time': math.trunc(timer_start_time),
		'timer_end_time': math.trunc(timer_end_time),
		'timer_paused_time': math.trunc(timer_paused_at_time),
		'timer_active': timer_is_active,
		'timer_expired': bool(control.get('timer', {}).get('expired', False)),
		'timer_shutdown': bool(timer_notify_data_obj.get('shutdown', False)),
		'timer_keep_warm': bool(timer_notify_data_obj.get('keep_warm', False))
	}
	
	status_info_block = {
		'name': settings.get('globals', {}).get('grill_name', ''),
		'mode': control.get('mode', 'Stop'), 
		'display_mode': current_hw_status.get('mode', 'Stop'), 
		'outpins': current_hw_status.get('outpins', {}), 
		'status': control.get('status', ''), 
		's_plus': control.get('s_plus', False),
		'units': settings.get('globals', {}).get('units', 'F'),
		'start_time': current_hw_status.get('start_time', 0),
		'start_duration': current_hw_status.get('start_duration', 0),
		'shutdown_duration': current_hw_status.get('shutdown_duration', 0),
		'prime_duration': current_hw_status.get('prime_duration', 0),
		'prime_amount': current_hw_status.get('prime_amount', 0),
		'lid_open_detected': current_hw_status.get('lid_open_detected', False),
		'lid_open_endtime': current_hw_status.get('lid_open_endtime', 0),
		'p_mode': current_hw_status.get('p_mode', 0),
		'startup_timestamp': current_hw_status.get('startup_timestamp', 0),
		'recipe': current_hw_status.get('recipe', False),
		'recipe_paused': current_hw_status.get('recipe_paused', False),
		'hopper_level': pelletdb.get('current',{}).get('hopper_level', 0),
		# Include manual_output_states in the dashboard payload if UI needs to reflect desired manual states
		'manual_output_states': control.get('manual_output_states', {}), 
		'ui_hash': hash(json.dumps(settings.get('probe_settings', {}).get('probe_map', {}).get('probe_info', [])))
	}
	
	dashboard_payload = {
		'status': status_info_block,        
		'probes': current_temps,            
		'notify_data': control.get('notify_data', []), 
		'timer': timer_info_block,            
		'pwm_control': control.get('pwm_control', False), 
		'tuning_mode': control.get('tuning_mode', False),
		'next_mode': control.get('next_mode', 'Stop'),
		'current_control_mode': control.get('mode', 'Stop'), 
		'current_duty_cycle': control.get('duty_cycle', 100)
	}
	return dashboard_payload

# --- Data Emission Functions ---
def emit_dashboard_data(sid=None):
	"""Emits the comprehensive dashboard data on 'dashboard_data' event."""
	try:
		data = _build_main_dashboard_payload()
		target_room = sid if sid else None
		socketio.emit('dashboard_data', data, room=target_room)
		logger.debug(f"Emitted 'dashboard_data' to {target_room if target_room else 'all'}")
	except Exception as e:
		logger.error(f"Error emitting dashboard_data: {e}", exc_info=True)

def emit_settings_data(sid=None):
	"""Emits settings data on 'settings_data' event."""
	try:
		data = read_settings()
		target_room = sid if sid else None
		socketio.emit('settings_data', data, room=target_room)
	except Exception as e:
		logger.error(f"Error emitting settings_data: {e}", exc_info=True)

def emit_pellet_data(sid=None):
	"""Emits pellet database on 'pellet_data' event."""
	try:
		data = read_pellet_db()
		target_room = sid if sid else None
		socketio.emit('pellet_data', data, room=target_room)
	except Exception as e:
		logger.error(f"Error emitting pellet_data: {e}", exc_info=True)

def emit_current_temps_data(sid=None): 
	"""Emits current temperature data (from control:current) on 'current_temps_data' event."""
	try:
		data = read_current() 
		target_room = sid if sid else None
		socketio.emit('current_temps_data', data, room=target_room)
	except Exception as e:
		logger.error(f"Error emitting current_temps_data: {e}", exc_info=True)

def emit_history_data(sid=None):
	"""Emits history data on 'history_data' event."""
	try:
		settings_data = read_settings() 
		num_points = settings_data.get('history_page', {}).get('datapoints', 60)
		data = read_history(num_items=num_points)
		target_room = sid if sid else None
		socketio.emit('history_data', data, room=target_room)
	except Exception as e:
		logger.error(f"Error emitting history_data: {e}", exc_info=True)

def emit_metrics_data(sid=None):
	"""Emits metrics data on 'metrics_data' event."""
	try:
		data = read_metrics(all=True) 
		target_room = sid if sid else None
		socketio.emit('metrics_data', data, room=target_room)
	except Exception as e:
		logger.error(f"Error emitting metrics_data: {e}", exc_info=True)

def emit_error_warning_data(sid=None):
	"""Emits errors and warnings on 'error_data' and 'warning_data' events."""
	try:
		errors_data = read_errors() 
		warnings_data = read_warnings() 
		target_room = sid if sid else None
		socketio.emit('error_data', errors_data, room=target_room)
		socketio.emit('warning_data', warnings_data, room=target_room)
	except Exception as e:
		logger.error(f"Error emitting error/warning data: {e}", exc_info=True)

def emit_all_data_on_connect(sid=None):
	"""Emits all necessary data when a client connects or requests a refresh."""
	logger.debug(f"Emitting all data categories on connect/refresh to SID: {sid}")
	emit_dashboard_data(sid)      
	emit_settings_data(sid)
	emit_pellet_data(sid)
	emit_current_temps_data(sid) 
	emit_history_data(sid) 
	emit_metrics_data(sid)
	emit_error_warning_data(sid)

def periodic_data_emitter():
	"""Background thread for periodic data emissions."""
	global clients, force_refresh 
	logger.info("Periodic data emitter thread started.")
	while not stop_emitter_event.is_set():
		with clients_lock:
			current_client_count = clients
			refresh_now = force_refresh
			if force_refresh:
				force_refresh = False 
		
		if refresh_now:
			logger.info("Force refresh triggered. Emitting all data to all clients.")
			emit_all_data_on_connect() 

		if current_client_count > 0:
			logger.debug(f"[{current_client_count} clients] - Emitting periodic 'dashboard_data'.")
			emit_dashboard_data() 
		else:
			logger.debug("No clients connected, skipping periodic emit.")
		
		stop_emitter_event.wait(EMIT_INTERVAL) 
	logger.info("Periodic data emitter thread stopped.")

# ##########################################################################
# --- SOCKETIO EVENT HANDLERS (Connect, Disconnect, Initial Data) ---
# ##########################################################################
@socketio.on('connect')
def handle_connect():
	global clients, thread 
	with clients_lock:
		clients += 1
	logger.info(f"Client connected: {request.sid}. Total clients: {clients}")
	if clients == 1 and (thread is None or not thread.is_alive()):
		logger.info("First client connected, starting periodic data emitter thread.")
		stop_emitter_event.clear()
		thread = threading.Thread(target=periodic_data_emitter, daemon=True)
		thread.start()
	emit_all_data_on_connect(sid=request.sid)

@socketio.on('disconnect')
def handle_disconnect():
	global clients
	with clients_lock:
		if clients > 0: clients -= 1
	logger.info(f"Client disconnected: {request.sid}. Total clients: {clients}")

@socketio.on('request_initial_data') 
def handle_request_initial_data():
	logger.info(f"Client {request.sid} explicitly requested initial data.")
	emit_all_data_on_connect(sid=request.sid)

# ##########################################################################
# --- GET DATA HANDLER ---
# ##########################################################################
@socketio.on('get_data')
def handle_get_data(data): 
	sid = request.sid
	action = data.get('action')
	logger.info(f"Client {sid} requested 'get_data' with action: {action}")

	if not action:
		logger.warning(f"Client {sid} sent 'get_data' without an action.")
		return {'error': 'No action specified.'}
	try:
		if action == 'control': 
			return _build_main_dashboard_payload()
		elif action == 'settings':
			return read_settings()
		elif action == 'pellets':
			return read_pellet_db()
		elif action == 'current_temps': 
			return read_current()
		elif action == 'history':
			settings = read_settings()
			num_points = settings.get('history_page', {}).get('datapoints', 60)
			return read_history(num_items=num_points)
		elif action == 'metrics':
			return read_metrics(all=True)
		elif action == 'errors':
			return read_errors()
		elif action == 'warnings':
			return read_warnings() 
		else:
			logger.warning(f"Unknown action '{action}' in 'get_data' from {sid}.")
			return {'error': f"Unknown action: {action}"}
	except Exception as e:
		logger.error(f"Error processing 'get_data' action '{action}' for {sid}: {e}", exc_info=True)
		return {'error': f"Server error processing action '{action}': {str(e)}"}

# ##########################################################################
# --- POST DATA HANDLER ---
# ##########################################################################
@socketio.on('post_data')
def handle_post_data(message):
	sid = request.sid
	category = message.get('category')
	data_payload = message.get('data')
	logger.info(f"Received post_data from {sid} for category '{category}': {data_payload}")

	if not category or not isinstance(data_payload, dict):
		emit('post_response', {'status': 'error', 'message': 'Invalid message format.'}, room=sid); return
	try:
		if category == 'control':
			control_data = read_control() 
			settings_data = read_settings() 
			action_processed = False
			control_data['updated'] = True
			command_type = None
			if 'psp' in data_payload:
				if is_float(str(data_payload.get('psp'))):
					control_data['mode'] = data_payload.get('mode', 'Hold') 
					control_data['primary_setpoint'] = int(float(data_payload.get('psp'))) if settings_data['globals']['units'] == 'F' else float(data_payload.get('psp'))
					action_processed = True
				else: emit('post_response', {'status': 'error', 'message': 'PSP must be a number.'}, room=sid); return
			elif 'mode' in data_payload: 
				new_mode = data_payload.get('mode')
				if new_mode == 'Prime':
					if 'prime_amount' in data_payload:
						try: control_data['prime_amount'] = int(data_payload.get('prime_amount'))
						except (ValueError, TypeError): emit('post_response', {'status': 'error', 'message': 'Invalid prime_amount.'}, room=sid); return
						control_data['next_mode'] = data_payload.get('next_mode', 'Stop') 
				if new_mode in MODE_MAP.values(): control_data['mode'] = new_mode; action_processed = True
				else: emit('post_response', {'status': 'error', 'message': f"Invalid mode: {new_mode}."}, room=sid); return
			elif 'pmode' in data_payload:
				if str(data_payload.get('pmode')).isdigit() and 0 <= int(data_payload.get('pmode')) < 10:
					settings_data['cycle_data']['PMode'] = int(data_payload.get('pmode')); write_settings(settings_data)
					control_data['settings_update'] = True; action_processed = True
				else: emit('post_response', {'status': 'error', 'message': 'PMode out of range or invalid.'}, room=sid); return
			elif 'splus' in data_payload:
				if isinstance(data_payload.get('splus'), bool): control_data['s_plus'] = data_payload.get('splus'); action_processed = True
				else: emit('post_response', {'status': 'error', 'message': 'splus must be true/false.'}, room=sid); return
			elif 'lid_open_toggle' in data_payload: control_data['lid_open_toggle'] = True; action_processed = True
			elif 'pwm_control' in data_payload: 
				if isinstance(data_payload.get('pwm_control'), bool): control_data['pwm_control'] = data_payload.get('pwm_control'); action_processed = True
				else: emit('post_response', {'status': 'error', 'message': 'pwm_control must be true/false.'}, room=sid); return
			elif 'duty_cycle' in data_payload: 
				if is_float(str(data_payload.get('duty_cycle'))):
					val = int(float(data_payload.get('duty_cycle')))
					if settings_data.get('pwm', {}).get('min_duty_cycle', 0) <= val <= settings_data.get('pwm', {}).get('max_duty_cycle', 100):
						control_data['duty_cycle'] = val; action_processed = True
					else: emit('post_response', {'status': 'error', 'message': 'Duty cycle out of range.'}, room=sid); return
				else: emit('post_response', {'status': 'error', 'message': 'Duty cycle must be a number.'}, room=sid); return
			elif 'tuning_mode' in data_payload:
				# ... (existing tuning_mode logic) ...
				if isinstance(data_payload.get('tuning_mode'), bool): control_data['tuning_mode'] = data_payload.get('tuning_mode'); action_processed = True
				else: emit('post_response', {'status': 'error', 'message': 'tuning_mode must be true/false.'}, room=sid); return
			
			if action_processed:
				origin_action = list(data_payload.keys())[0]
				write_control(control_data, origin=f'socketio_control_{origin_action}', direct_write=True)
				emit('post_response', {'status': 'success', 'message': 'Control command processed.'}, room=sid)
				emit_dashboard_data() 
				if 'pmode' in data_payload: emit_settings_data()
			elif not command_type :
				emit('post_response', {'status': 'error', 'message': "Invalid control payload: No recognized action."}, room=sid)
		#Manual Mode
		elif category == 'manual':
			control = read_control()
			manual_action = data_payload.get('action')
			manual_value = data_payload.get('value')

			if control['mode'] == 'Manual' or control['mode'] == 'Monitor' or settings['safety']['allow_manual_changes']:
				control['manual']['change'] = manual_action
				if manual_value == 'toggle':
					status = read_status()
					if status['outpins'][manual_action]:
						manual_value = 'false'
					else:
						manual_value = 'true'
				if manual_value == 'true':
					control['manual']['output'] = True
				else:
					control['manual']['output'] = False
				
				if control['manual']['change'] in ['power', 'igniter', 'fan', 'auger', 'pwm']:
					write_control(control, direct_write=False, origin='unknown')

		elif category == 'timer':
			timer_action = data_payload.get('action')
			control_data = read_control() # Reread control to ensure latest state for timer ops
			
			# Initialize timer structures if not present
			if 'notify_data' not in control_data: control_data['notify_data'] = default_notify(read_settings()) 
			if 'timer' not in control_data: control_data['timer'] = default_control()['timer']
			if 'expired' not in control_data['timer']: control_data['timer']['expired'] = False
			
			timer_notify_index = next((i for i, obj in enumerate(control_data.get('notify_data',[])) if obj.get('type') == 'timer'), -1)
			if timer_notify_index == -1: 
				control_data['notify_data'].append({'label': 'Timer', 'type': 'timer', 'req': False, 'shutdown': False, 'keep_warm': False})
				timer_notify_index = len(control_data['notify_data']) -1
			
			now = time.time(); timer_updated = False; emit_msg = "No timer action."
			
			if timer_action == 'start':
				if 'duration' in data_payload: 
					seconds = int(data_payload.get('duration', 0)) # Allow 0 duration to effectively stop/clear
					if seconds < 0: seconds = 0 # Prevent negative duration

					control_data['notify_data'][timer_notify_index]['req'] = True if seconds > 0 else False
					control_data['timer']['expired'] = False 
					control_data['timer']['start'] = now if seconds > 0 else 0
					control_data['timer']['end'] = (now + seconds) if seconds > 0 else 0
					control_data['timer']['paused'] = 0 
					
					# Apply shutdown/keep_warm options if sent with 'start'
					# These keys ('timer_shutdown', 'timer_keep_warm') come from timer.js's startTimer payload
					if 'timer_shutdown' in data_payload:
						is_shutdown = bool(data_payload.get('timer_shutdown'))
						control_data['notify_data'][timer_notify_index]['shutdown'] = is_shutdown
						if is_shutdown: control_data['notify_data'][timer_notify_index]['keep_warm'] = False # Mutually exclusive
					if 'timer_keep_warm' in data_payload and not control_data['notify_data'][timer_notify_index]['shutdown']:
						control_data['notify_data'][timer_notify_index]['keep_warm'] = bool(data_payload.get('timer_keep_warm'))
					
					emit_msg = 'Timer started.' if seconds > 0 else 'Timer cleared (0s duration).'
				else: # Resume
					if control_data['timer'].get('start', 0) != 0 and control_data['timer'].get('paused', 0) != 0:
						control_data['notify_data'][timer_notify_index]['req'] = True
						control_data['timer']['expired'] = False 
						control_data['timer']['end'] = (control_data['timer']['end'] - control_data['timer']['paused']) + now 
						control_data['timer']['paused'] = 0 
						emit_msg = 'Timer resumed.'
					else:
						emit_msg = 'Timer not paused or not started; cannot resume.'
				timer_updated = True
			elif timer_action == 'pause':
				if control_data['timer'].get('start', 0) != 0 and control_data['timer'].get('paused', 0) == 0 and not control_data['timer']['expired']:
					control_data['notify_data'][timer_notify_index]['req'] = False
					control_data['timer']['paused'] = now
					timer_updated = True; emit_msg = 'Timer paused.'
				elif control_data['timer']['expired']:
					emit_msg = 'Timer already expired; cannot pause.'
				else: # Already paused or not started
					emit_msg = 'Timer already paused or not started.'
			elif timer_action == 'stop':
				control_data['notify_data'][timer_notify_index].update({'req': False, 'shutdown': False, 'keep_warm': False})
				control_data['timer'].update({'start': 0, 'end': 0, 'paused': 0, 'expired': False}); 
				timer_updated = True; emit_msg = 'Timer stopped.'
			elif timer_action in ['set_shutdown', 'set_keep_warm']:
				key = 'shutdown' if timer_action == 'set_shutdown' else 'keep_warm'
				value = bool(data_payload.get('value', False))
				control_data['notify_data'][timer_notify_index][key] = value
				if value: # Ensure mutual exclusivity
					other_key = 'keep_warm' if key == 'shutdown' else 'shutdown'
					control_data['notify_data'][timer_notify_index][other_key] = False
				timer_updated = True; emit_msg = f"Timer {key} notification set to {value}."
			else: 
				emit('post_response', {'status': 'error', 'message': f"Unknown timer action: {timer_action}"}, room=sid); return 
			
			if timer_updated:
				write_control(control_data, origin='socketio_timer_v3', direct_write=True)
				emit('post_response', {'status': 'success', 'message': emit_msg}, room=sid)
				emit_dashboard_data()
			else: 
				emit('post_response', {'status': 'info', 'message': emit_msg}, room=sid)

		elif category == 'settings':
			settings_data = read_settings()
			updated_settings = deep_update(settings_data, data_payload)
			write_settings(updated_settings) 
			control_data = read_control()
			control_data['settings_update'] = True; control_data['updated'] = True 
			write_control(control_data, origin='socketio_settings', direct_write=True) 
			emit('post_response', {'status': 'success', 'message': 'Settings updated.'}, room=sid)
			emit_settings_data(); emit_dashboard_data()
		elif category == 'pellets':
			emit('post_response', {'status': 'info', 'message': 'Pellets category not yet implemented.'}, room=sid)
		elif category == 'admin':
			emit('post_response', {'status': 'info', 'message': 'Admin category not yet implemented.'}, room=sid)
		else:
			emit('post_response', {'status': 'error', 'message': f"Unknown category: {category}"}, room=sid)
	except Exception as e:
		logger.error(f"Error processing post_data for category '{category}' from {sid}: {e}", exc_info=True)
		emit('post_response', {'status': 'error', 'message': f"An internal error occurred: {str(e)}"}, room=sid)

