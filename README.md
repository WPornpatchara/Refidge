# Refidge

# Smart Fridge Inventory AI

This project consists of a FastAPI backend for managing fridge inventory and a computer vision detection script that monitors items using YOLO and ResNet models.

## Features

- **FastAPI Backend (`main.py`)**: Manages inventory, handles manual/automatic item additions, and tracks usage, freshness, and expiry.
- **AI Detection (`detect.py`)**: Connects to a video stream, uses YOLOv8 for object detection, and ResNet18 for freshness classification (Fresh vs. Rotten).
- **Auto-Sync**: The detection script takes hourly snapshots (or on-demand) and synchronizes the physical state of the fridge with the backend JSON database.

## Prerequisites

Ensure you have Python 3.8+ installed. You will also need the trained model files placed in the `model/` directory:

- `best.pt` (YOLO model weights)
- `best_resnet_fruit.pth` (ResNet model weights)

Install the required dependencies:

```bash
pip install fastapi uvicorn pydantic torch torchvision ultralytics opencv-python pillow requests python-multipart
```

## How to Run

### 1. Connect to Raspberry Pi Camera

The Raspberry Pi provides the camera video stream used by the AI detection script.

- Connect both the Raspberry Pi and your computer to the same Wi-Fi network or mobile hotspot.
- Open Terminal or PowerShell and connect to the Raspberry Pi via SSH:

```bash
ssh <username>@172.20.10.8
```

- Enter the Raspberry Pi password when prompted.
- Verify the connection and IP address:

```bash
hostname
hostname -I
```

- Ensure the Raspberry Pi camera is connected and its video streaming service is running.

The camera stream URL is configured in `detect.py`:

```python
PI_STREAM_URL = "http://172.20.10.8:5000/video"
```

If the Raspberry Pi IP address changes, update the `PI_STREAM_URL` accordingly.

### 2. Start the Backend API

Navigate to the directory containing `main.py` and run the FastAPI server using `uvicorn`. The detection script expects the backend to be running on port `8000`.

```bash
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

- API documentation: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- Data is saved locally in `inventory_db.json` and `price_db.json`.

### 3. Start the AI Detection Script

Open a new terminal, navigate to the same directory, and run:

```bash
python detect.py
```

Make sure the Raspberry Pi camera stream and Backend API are running before starting the detection script.

**Note:** If your Raspberry Pi camera stream uses a different IP address or port, update the `PI_STREAM_URL` inside `detect.py` before running.

## Controls for `detect.py`

- The camera processes a frame every 1 hour automatically.
- Press **`r`** on the video window to manually trigger a capture and update the backend immediately.
- Press **`q`** to quit the detection window.

## Troubleshooting

| Problem | Solution |
|---|---|
| SSH connection failed | Check the Wi-Fi connection, Raspberry Pi IP address, and SSH service. |
| Camera stream unavailable | Check the camera connection and ensure the streaming service is running. |
| Backend connection failed | Ensure the FastAPI server is running on port `8000`. |
| Model file not found | Verify that `best.pt` and `best_resnet_fruit.pth` are in the correct directory. |

## Shutdown

1. Press `q` to close the AI detection window.
2. Press `Ctrl + C` to stop the Backend API.
3. If connected to Raspberry Pi via SSH, run:

```bash
exit
```
## Frontend (Flutter Application)

The frontend is developed using Flutter and Dart. It provides the user interface for managing fridge inventory, monitoring food freshness and expiry dates, and viewing expense summaries.

### Prerequisites

Before you begin, ensure you have the following installed:

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android Studio or Visual Studio Code
- A working Android emulator or a connected physical device

### How to Run

Follow these steps to run the application on your local machine:

**1. Navigate to the Frontend directory**

```bash
cd Frontend
```

**2. Install dependencies**

```bash
flutter pub get
```

**3. Configure Backend API Connection**

Make sure the Backend API is running before launching the application.

Update the API base URL in the Flutter project to match your backend server address.

For Android Emulator, use:

```text
http://10.0.2.2:8000
```

For a physical device, use your computer's local IP address:

```text
http://<YOUR_COMPUTER_IP>:8000
```

Ensure that the computer and mobile device are connected to the same network. The backend must also be configured to accept external connections when using a physical device.

**4. Run the application**

```bash
flutter run
```

### Main Features

- **Inventory Management:** View, add, edit, and manage food inventory.
- **Food Freshness Monitoring:** Display food freshness and expiry information.
- **Expense Summary:** Track and visualize food expenses.
- **Notifications:** Receive alerts for food items approaching their expiry dates.
