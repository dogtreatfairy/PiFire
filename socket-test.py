import socketio
import time
import json

sio = socketio.Client()

@sio.event
def connect():
    print("Connected to the server!")
    # Request initial data
    sio.emit('get_dash_data', {'force': True})

@sio.event
def disconnect():
    print("Disconnected from the server!")

@sio.on('grill_control_data')
def handle_grill_control_data(data):
    print("Received grill_control_data:")
    print(json.dumps(data, indent=2))

def main():
    server_url = "http://localhost:8000"
    while True:
        try:
            print(f"Connecting to {server_url}...")
            sio.connect(server_url)
            sio.wait()
        except Exception as e:
            print(f"Disconnected. Reconnecting in 5 seconds... {e}")
            time.sleep(5)

if __name__ == "__main__":
    main()