#!/usr/bin/env python3

'''
*****************************************
 PiFire PID Controller
*****************************************

 Description: This object calculates PID control outputs to maintain grill temperature
 in a pellet grill. It includes anti-windup clamping to prevent integral windup when
 the output is saturated. Output is not clamped here, as it is handled elsewhere.
 See: https://info.erdosmiller.com/blog/pid-anti-windup-techniques

 Originally developed by GitHub user DBorello for PiSmoker (https://github.com/DBorello/PiSmoker),
 modified by GitHub user markalston, and further refined here.

 Implements a PID controller using proportional band in standard form:
   u = Kp * (e(t) + (1/Ti) * INT + Td * de/dt)
 Where:
  - PB  = Proportional Band (°F)
  - Kp  = Proportional Gain = -1/PB
  - Ti  = Integral Time Constant (seconds)
  - Td  = Derivative Time Constant (seconds)
  - e(t)= Error = Current Temp - Setpoint
  - INT = Cumulative integral of error
  - de  = Change in error
  - dt  = Change in time
  - u   = Controller output (unclamped, typically 0 to 1 elsewhere)

 Configuration Defaults:
  "config": {
      "PB": 30.0,
      "Td": 20.0,
      "Ti": 120.0
  }

*****************************************
'''

# Imported Libraries
import time
import logging
from common import create_logger
from controller.base import ControllerBase

# Logger Setup
log_level = logging.DEBUG
eventLogger = create_logger('events', filename='/tmp/events.log', messageformat='%(asctime)s [%(levelname)s] %(message)s', level=log_level)

# Class Definition
class Controller(ControllerBase):
	def __init__(self, config: dict, cycle_data: dict):
		"""Initialize the PID controller with configuration and cycle data.

		Args:
			config: Dictionary with PB, Ti, Td values.
			cycle_data: Dictionary with u_min, u_max, and other cycle parameters.
		"""
		super().__init__(config, cycle_data)

		self._calculate_gains(config['PB'], config['Ti'], config['Td'])

		self.pb = config['PB']
		self.p = 0.0
		self.i = 0.0
		self.d = 0.0
		self.u = 0.0
		self.u_min = cycle_data['u_min']
		self.u_max = cycle_data['u_max']

		self.last_update = None
		self.error = 0.0
		self.error_last = 0.0
		self.set_point = 0.0
		self.integral = 0.0
		self.derivative = 0.0

		self.set_target(0.0)

	def _calculate_gains(self, pb: float, ti: float, td: float) -> None:
		"""Calculate PID gains based on proportional band and time constants.

		Args:
			pb: Proportional band (°F).
			ti: Integral time constant (seconds).
			td: Derivative time constant (seconds).
		"""
		if pb == 0:
			self.kp = 0.0
		else:
			self.kp = -1.0 / pb
		if ti == 0:
			self.ki = 0.0
		else:
			self.ki = self.kp / ti
		self.kd = self.kp * td
		eventLogger.debug(f'Kp: {self.kp}, Ki: {self.ki}, Kd: {self.kd}')

	def update(self, current: float) -> float:
		"""Compute the PID control output based on the current temperature.

		Args:
			current: Current temperature reading (°F).
		Returns:
			Control output `u` (unclamped).
		"""
		# Calculate time delta
		now = time.monotonic()
		dt = now - self.last_update if self.last_update is not None else 0.0

		# Proportional term
		self.error = current - self.set_point
		self.p = self.kp * self.error

		# Integral term
		self.integral += self.error * dt
		self.i = self.ki * self.integral

		# Derivative term
		self.derivative = (self.error - self.error_last) / dt if dt > 0 else 0.0
		self.d = self.kd * self.derivative

		# Total output
		self.u = self.p + self.i + self.d

		# Anti-windup: Clamp integral when output is saturated and error increases saturation
		if (self.u > self.u_max and self.error < 0) or (self.u < self.u_min and self.error > 0):
			self.integral -= self.error * dt
			clamping_log = "true"
			eventLogger.debug('Clamping integrator.')
		else:
			clamping_log = "false"
			eventLogger.debug('Not clamping integrator.')

		eventLogger.debug(f'PID Update - error: {self.error}, p: {self.p}, i: {self.i}, d: {self.d}, u: {self.u}, clamping: {clamping_log}')

		# Update state
		self.error_last = self.error
		self.last_update = now

		return self.u

	def set_target(self, set_point: float) -> None:
		"""Set the target temperature and reset integral and derivative terms.

		Args:
			set_point: Desired temperature setpoint (°F).
		"""
		self.set_point = set_point
		self.error = 0.0
		self.integral = 0.0
		self.derivative = 0.0
		self.last_update = time.monotonic()

	def set_gains(self, pb: float, ti: float, td: float) -> None:
		"""Update PID gains with new PB, Ti, and Td values.

		Args:
			pb: Proportional band (°F).
			ti: Integral time constant (seconds).
			td: Derivative time constant (seconds).
		"""
		self._calculate_gains(pb, ti, td)

	def get_k(self) -> tuple[float, float, float]:
		"""Return current PID gains.

		Returns:
			Tuple of (Kp, Ki, Kd).
		"""
		return self.kp, self.ki, self.kd

	def supported_functions(self) -> list[str]:
		"""Return a list of supported method names.

		Returns:
			List of method names available in this controller.
		"""
		return ['update', 'set_target', 'get_config', 'set_gains', 'get_k']