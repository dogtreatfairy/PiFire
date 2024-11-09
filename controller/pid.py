#!/usr/bin/env python3

'''
*****************************************
 PiFire PID Controller
*****************************************

 Description: This object will be used to calculate PID for maintaining
 temperature in the grill.

 This software was developed by GitHub user DBorello as part of his excellent
 PiSmoker project: https://github.com/DBorello/PiSmoker

 Adapted for PiFire

 PID controller based on proportional band in standard PID form https://en.wikipedia.org/wiki/PID_controller#Ideal_versus_standard_PID_form
   u = Kp (e(t)+ 1/Ti INT + Td de/dt)
  PB = Proportional Band
  Ti = Goal of eliminating in Ti seconds
  Td = Predicts error value at Td in seconds
  
  Configuration Defaults: 
  "config": {
      "PB": 60.0,
      "Td": 45.0,
      "Ti": 180.0,
      "center": 0.5
   }

*****************************************
'''

'''
Imported Libraries
'''
import time
import logging
from controller.base import ControllerBase 
from common import *  # Common Module for WebUI and Control Program

'''
Class Definition
'''
class Controller(ControllerBase):
	def __init__(self, config, units, cycle_data):
		super().__init__(config, units, cycle_data)
		
		self.eventLogger = create_logger('events', filename='/tmp/events.log', messageformat='%(asctime)s [%(levelname)s] %(message)s', level=logging.INFO)
		
		self._calculate_gains(config['PB'], config['Ti'], config['Td'])

		self.p = 0.0
		self.i = 0.0
		self.d = 0.0
		self.u = 0

		self.last_update = time.time()
		self.error = 0.0
		self.set_point = 0

		self.center = 0.5
		
		self.max_rate_of_change = config['max_rate_of_change']
		
		self.derate_window = config['derate_window']
		self.user_derate_multiplier = config['derate_multiplier']
		self.derate_multiplier = self.user_derate_multiplier
		self.derate = False
		self.derate_start_time = None
		self.rerate_increment = config['rerate_increment']
		
		self.stable_time = config['stable_time']
		self.stable_window = config['stable_window']

		self.derv = 0.0
		self.inter = 0.0

		self.last = 150

		self.set_target(0.0)
		self.new_target = False
		self.within_range_start = None

	def _calculate_gains(self, pb, ti, td):
		self.kp = -1 / pb
		self.ki = self.kp / ti
		self.kd = self.kp * td

	def update(self, current):
		self.center = (self.set_point * 0.0012)  # Dynamically set self.center depending on current temperature.
    
		# P
		error = current - self.set_point
		self.p = self.kp * error + self.center  # p = 1 for pb / 2 under set_point, p = 0 for pb / 2 over set_point

		# I
		dt = time.time() - self.last_update

		self.inter += error * dt
		self.inter = max(self.inter, -self.center)
		self.inter = min(self.inter, self.center)
		self.i = self.ki * self.inter

		# D
		self.derv = (current - self.last) / dt  # Rate of change in Degrees per second
		self.d = self.kd * self.derv

		# PID
		self.u = self.p + self.i + self.d
	
		self.eventLogger.info(f"-- PID Values --")
		self.eventLogger.info(f"C:  {self.center}")
		self.eventLogger.info(f"P:  {self.p}")
		self.eventLogger.info(f"I:  {self.i}")
		self.eventLogger.info(f"D:  {self.d}")
		self.eventLogger.info(f"U:  {self.u}")

		# If rate of change is too high within derate window during a set point change, derate output
		if self.new_target and abs(error) <= self.derate_window and self.derv >= self.max_rate_of_change and error < 0:
			self.derate = True
			self.derate_start_time = time.time()
			self.derate_multiplier = self.user_derate_multiplier
	
		# If derate is true, derate the output by the derate multiplier
		if self.derate:
			self.u = self.u * self.derate_multiplier
			self.eventLogger.info(f"Derate - ON - M: {self.derate_multiplier}")
	
			# Gradually increase the derate multiplier until it reaches 1, only if rate of change is below max
			if self.derv < self.max_rate_of_change:
				if self.derate_multiplier < 1:
					self.derate_multiplier += self.rerate_increment
					self.derate_multiplier = min(self.derate_multiplier, 1)  # Ensure it does not exceed 1
	
			# If derate multiplier reaches 1, reset derate flag
		if self.derate_multiplier == 1:
			self.derate = False
			self.derate_start_time = None
			self.eventLogger.info("Derate - OFF")
	
			# Reset the derate multiplier if the rate of change exceeds the max rate of change
			if self.derv >= self.max_rate_of_change:
				self.derate_multiplier = self.user_derate_multiplier
	
		# If outside stable window (high) consider this an overshoot and minimize output
		if (current - self.set_point) >= self.stable_window:
			self.u = 0.0
			self.eventLogger.info("Overshoot Detected, minimizing output")
		
		# Reset integral term when current temperature first reaches or exceeds set point after a set point change
		if self.new_target and current >= self.set_point:
			self.inter = 0.0
			self.new_target = False
	
		# Update for next cycle
		self.error = error
		self.last = current
		self.last_update = time.time()
	
		self.eventLogger.info(f"U Final: {self.u}")
	
		return self.u
	
	def set_target(self, set_point):
		self.set_point = set_point
		self.error = 0.0
		self.inter = 0.0
		self.derv = 0.0
		self.last_update = time.time()
		self.new_target = True
		self.derate = False
		self.derate_multiplier = self.user_derate_multiplier
		self.eventLogger.info(f"New Set Point: {self.set_point    ")
    
	def set_gains(self, pb, ti, td):
		self._calculate_gains(pb,ti,td)

	def get_k(self):
		return self.kp, self.ki, self.kd
	
	def supported_functions(self):
		function_list = [
			'upda        ', 
	        'se        target', 
	        'get_config', 
			'set_ga        s', 
			'get_k'
        ]
		return function_list