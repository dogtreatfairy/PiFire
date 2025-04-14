#!/usr/bin/env python3

'''
*****************************************
 PiFire PID Controller
*****************************************

 Description: This object will be used to calculate PID for maintaining
 temperature in the grill.  This controller adds basic clamping to prevent windup.
 When the output is saturated (either below 0 or above 1) then we do not increase the integral output.
 https://info.erdosmiller.com/blog/pid-anti-windup-techniques

 This controller was originally developed by GitHub user DBorello as part of his excellent
 PiSmoker project: https://github.com/DBorello/PiSmoker and modified by GitHub user markalston.

 PID controller based on proportional band in standard PID form https://en.wikipedia.org/wiki/PID_controller#Ideal_versus_standard_PID_form
   u   = Kp (e(t)+ 1/Ti INT + Td de/dt) = controller output
  PB   = Proportional Band
  Kp   = Proportional Gain = 1/PB
  Ti   = Integration Time constant
  Td   = Derivative Time Constant
  de   = Change in Error
  dt   = Change in Time
  INT  = Historic cumulative value of errors
  e(t) = Current Error = Set Point - Current Temp

  
  Configuration Defaults: 
  "config": {
      "PB": 30.0,
      "Td": 20.0,
      "Ti": 120.0
   }

*****************************************
'''

'''
Imported Libraries
'''
import time
import logging
from common import create_logger
from controller.base import ControllerBase 
log_level = logging.DEBUG
eventLogger = create_logger('events', filename='/tmp/events.log', messageformat='%(asctime)s [%(levelname)s] %(message)s', level=log_level)

'''
Class Definition
'''
class Controller(ControllerBase):
	def __init__(self, config, units, cycle_data):
		super().__init__(config, units, cycle_data)

		eventLogger.info('Clamping PID Controller Loaded')

		self.pb = config['PB']
		self.ti = config['Ti']
		self.td = config['Td']

		self._calculate_gains(self.pb, self.ti, self.td)

		self.p = 0.0
		self.i = 0.0
		self.d = 0.0
		self.u = 0

		self.last_update = time.monotonic()
		self.error = 0.0
		self.error_last = 0.0
		self.set_point = 0

		self.derv = 0.0
		self.inter = 0.0
		
		self.set_target(0.0)

	def _calculate_gains(self, pb, ti, td):
		if pb == 0:
			self.kp = 0
		else:
			self.kp = -1 / pb
		if ti == 0:
			self.ki = 0
		else:
			self.ki = self.kp / ti
		self.kd = self.kp * td
		eventLogger.info('kp: ' + str(self.kp) + ', ki: ' + str(self.ki) + ', kd: ' + str(self.kd))

	def update(self, current, config):
		# Check if config is provided and if PID parameters have changed
		if config and (
			config['PB'] != self.pb or 
			config['Ti'] != self.ti or 
			config['Td'] != self.td
		):
			self._calculate_gains(config['PB'], config['Ti'], config['Td'])
			self.pb = config['PB']
			self.ti = config['Ti']
			self.td = config['Td']

			eventLogger.info('PID Tuning Values Changed - Recalculating Gains - PB: ' + str(self.pb) + ', Ti: ' + str(self.ti) + ', Td: ' + str(self.td))

			# Recalculate gains if PB, Ti, or Td have changed
			self._calculate_gains(self.pb, self.ti, self.td)
		
		dt = time.monotonic() - self.last_update # Time monotonic is used to prevent time drift from system clock.
		error = current - self.set_point
		
		# P
		self.p = self.kp * error
		
		# I
		self.inter += error * dt
		self.i = self.ki * self.inter
		
		# D (on error)
		self.derv = (error - self.error_last) / dt
		self.d = self.kd * self.derv
		
		# Compute unclamped output
		self.u = self.p + self.i + self.d
		
		# Back-calculation anti-windup
		# Here we subtracted the clamped output from the unclamped output to get the saturation error. 
		# We then add the saturation error to the integral term.  This is a simple way to prevent windup.
		u_clamped = max(0, min(1, self.u))
		if self.ki != 0:
			self.inter += (u_clamped - self.u) / self.ki
			self.i = self.ki * self.inter
		
		self.error_last = error
		self.last_update = time.monotonic()
		return self.u

	def set_target(self, set_point):
		self.set_point = set_point
		self.error = 0.0
		self.inter = 0.0
		self.derv = 0.0
		self.last_update = time.monotonic()

	def set_gains(self, pb, ti, td):
		self._calculate_gains(pb,ti,td)


	def get_k(self):
		return self.kp, self.ki, self.kd
	
	def supported_functions(self):
		function_list = [
			'update', 
	        'set_target', 
	        'get_config', 
			'set_gains', 
			'get_k'
        ]
		return function_list