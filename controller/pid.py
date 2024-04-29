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
      "center": 0.5,
	  "set_point_weighing": true,
	  "beta" : 1.0,
	  "gamma" : 0.0
   }

*****************************************
'''

'''
Imported Libraries
'''
import time
from controller.base import ControllerBase 

'''
Class Definition
'''
class Controller(ControllerBase):
	def __init__(self, config, units, cycle_data):
		super().__init__(config, units, cycle_data)

		self._calculate_gains(config['PB'], config['Ti'], config['Td'])

		self.p = 0.0
		self.i = 0.0
		self.d = 0.0
		self.u = 0

		self.last_update = time.time()
		self.error = 0.0
		self.set_point = 0

		self.center = config['center']
		self.set_point_weighing = config['set_point_weighing']
		self.beta = config['beta']
		self.gamma = config['gamma']

		self.derv = 0.0
		self.inter = 0.0
		self.inter_max = abs(self.center / self.ki)

		self.last = 150

		self.set_target(0.0)

	def _calculate_gains(self, pb, ti, td):
		self.kp = -1 / pb
		self.ki = self.kp / ti
		self.kd = self.kp * td

	def update(self, current):
		# P
		error = current - self.set_point
		if self.set_point_weighing:
			self.p = self.kp * (self.beta * (current - self.set_point)) + self.center
		else:
			self.p = self.kp * error + self.center
	
		# I
		dt = time.time() - self.last_update
		self.inter += error * dt
		self.inter = max(self.inter, -self.inter_max)
		self.inter = min(self.inter, self.inter_max)
	
		if self.set_point_weighing:
			self.i = self.ki * (self.gamma * (current - self.set_point))
		else:
			self.i = self.ki * self.inter
	
		# D
		self.derv = (current - self.last) / dt
		self.d = self.kd * self.derv
	
		# PID
		self.u = self.p + self.i + self.d
	
		# Update for next cycle
		self.error = error
		self.last = current
		self.last_update = time.time()
	
		return self.u

	def set_target(self, set_point):
		self.set_point = set_point
		self.error = 0.0
		self.inter = 0.0
		self.derv = 0.0
		self.last_update = time.time()

	def set_gains(self, pb, ti, td):
		self._calculate_gains(pb,ti,td)
		self.inter_max = abs(self.center / self.ki)

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
