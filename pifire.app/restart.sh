#!/bin/bash

# Stop nginx
echo "Stopping nginx..."
sudo systemctl stop nginx

# Stop supervisor
echo "Stopping supervisor..."
sudo systemctl stop supervisor

# Wait for 3 seconds
echo "Waiting for 3 seconds..."
sleep 3

# Start nginx
echo "Starting nginx..."
sudo systemctl start nginx

# Start supervisor
echo "Starting supervisor..."
sudo systemctl start supervisor

echo "Done!"
