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
import collections
import numpy as np
from sklearn.linear_model import LinearRegression
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
        self.original_set_point = 0

        self.center = config['center']
        self.anti_windup = config['anti_windup']

        self.derv = 0.0
        self.inter = 0.0
        self.inter_max = abs(self.center / self.ki)

        self.prediction_window = config['prediction_window']
        self.prediction_deadzone = config['prediction_deadzone']
        self.temperature_history = collections.deque(maxlen=int(self.prediction_window / 25))
        self.time_history = collections.deque(maxlen=int(self.prediction_window / 25))
        self.regression_model = LinearRegression()

        self.last = 150

        self.set_target(0.0)

    def _calculate_gains(self, pb, ti, td):
        self.kp = -1 / pb
        self.ki = self.kp / ti
        self.kd = self.kp * td

    def update(self, current):

        # P
        error = current - self.set_point
        self.p = self.kp * error + self.center # p = 1 for pb / 2 under set_point, p = 0 for pb / 2 over set_point

        # I
        dt = time.time() - self.last_update
        self.inter += error * dt
        self.inter = max(self.inter, -self.inter_max)
        self.inter = min(self.inter, self.inter_max)
        self.i = self.ki * self.inter

        # Anti-windup: Don't accumulate if we're at the output limits
        if self.u >= self.anti_windup and error > 0:
            self.inter -= error * dt
        if self.u <= 0 and error < 0:
            self.inter -= error * dt

        # D with low-pass filter
        alpha = 0.1  # Filter parameter, adjust as needed
        self.derv = alpha * self.derv + (1 - alpha) * ((current - self.last) / dt)
        self.d = self.kd * self.derv

        # PID
        self.u = self.p + self.i + self.d
        self.u = max(0, min(self.u, 1))  # Ensure u is within [0, 1]

        # Update for next cycle
        self.error = error
        self.last = current
        self.last_update = time.time()

        # Add the current temperature and time to the history
        self.temperature_history.append(current)
        self.time_history.append(time.time())

        # If we have enough data, fit the regression model and make a prediction
        if len(self.temperature_history) == self.temperature_history.maxlen:
            # If the current temperature is within the deadzone, skip the prediction
            if abs(current - self.set_point) > self.prediction_deadzone:
                X = np.array(self.time_history).reshape(-1, 1)
                y = np.array(self.temperature_history)
                self.regression_model.fit(X, y)
                predicted_temperature = self.regression_model.predict([[time.time() + self.prediction_window]])

                # If the predicted temperature exceeds the set point, reduce u
                if predicted_temperature > self.set_point:
                    overshoot = predicted_temperature - self.set_point
                    self.u -= overshoot / self.set_point

        # Ensure u is within [0, 1]
        self.u = max(0, min(self.u, 1))

        return self.u

    def set_target(self, set_point):
        self.set_point = set_point
        self.error = 0.0
        self.inter = 0.0
        self.derv = 0.0
        self.last_update = time.time()

    def set_gains(self, pb, ti, td):
        self._calculate_gains(pb, ti, td)
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