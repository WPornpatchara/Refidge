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

### 1. Start the Backend API
Navigate to the directory containing `main.py` and run the FastAPI server using `uvicorn`. The detection script expects the backend to be running on port `8000`.

```bash
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```
* You can view the API documentation by visiting: http://127.0.0.1:8000/docs
* Data is saved locally in `inventory_db.json` and `price_db.json`.

### 2. Start the AI Detection Script
Open a new terminal, navigate to the same directory, and run the detection script.

*(Note: If your Raspberry Pi camera stream is at a different IP, please update the `PI_STREAM_URL` inside `detect.py` before running.)*

```bash
python detect.py
```

### Controls for `detect.py`
* The camera processes a frame every 1 hour automatically.
* Press **`r`** on the video window to manually trigger a capture and update the backend immediately.
* Press **`q`** to quit the detection window.