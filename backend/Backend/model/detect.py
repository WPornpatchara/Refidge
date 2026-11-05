import cv2
import time
import torch
import torch.nn as nn
import torchvision.transforms as transforms
from torchvision import models
from ultralytics import YOLO
from PIL import Image
import requests
from collections import defaultdict
import base64

# Fix for macOS OpenCV window display
cv2.startWindowThread()

# ======================
# CONFIG
# ======================

SNAPSHOT_URL = "http://localhost:8000/inventory/snapshot"

YOLO_MODEL_PATH   = "best.pt"      
RESNET_MODEL_PATH = "best_resnet_fruit.pth"

#CAMERA_INDEX      = 0 

PI_STREAM_URL     = "http://172.20.10.8:5000/video"

CONF_FIRST_PASS   = 0.5   
CONF_SECOND_PASS  = 0.5   
PADDING           = 50    

REQUEST_TIMEOUT   = 5
CAPTURE_INTERVAL  = 10

MISS_STREAK_THRESHOLD = 3

FRESHNESS_SCORE_TABLE = {
    "apple_fresh": [
        (0.95, 1.00, "Eat within 14 days"),
        (0.85, 0.94, "Eat within 3 days"),
    ],
    "banana_fresh": [
        (0.95, 1.00, "Eat within 7 days"),
        (0.70, 0.94, "Eat within 3 days"),
    ],
    "cucumber_fresh": [
        (0.95, 1.00, "Eat within 14 days"),
        (0.85, 0.94, "Eat within 7 days"),
    ],
    "tomato_fresh": [
        (0.90, 1.00, "Eat within 7 days"),
        (0.70, 0.89, "Eat within 3 days"),
    ],
    "mango_fresh": [
        (0.90, 1.00, "Eat within 30 days"),
        (0.80, 0.89, "Eat within 14 days"),
    ],
    "orange_fresh": [
        (0.95, 1.00, "Eat within 14 days"),
        (0.85, 0.94, "Eat within 7 days"),
    ],
    "carrot_fresh": [
        (0.95, 1.00, "Eat within 14 days"),
        (0.85, 0.94, "Eat within 7 days"),
    ],
    "bell pepper_fresh": [
        (0.95, 1.00, "Eat within 14 days"),
        (0.85, 0.94, "Eat within 7 days"),
    ],
    "guava_fresh": [
        (0.95, 1.00, "Eat within 14 days"),
        (0.85, 0.94, "Eat within 7 days"),
    ],
    "potato_fresh": [
        (0.95, 1.00, "Eat within 30 days"),
        (0.85, 0.94, "Eat within 14 days"),
    ],
    "default": [
        (0.95, 1.00, "Rotten"),
        (0.85, 0.94, "Eat within 14 days"),
        (0.70, 0.84, "Eat within 7 days"),
    ],
}

# ======================
# LOAD MODELS
# ======================

print("Loading YOLO...")
yolo_model = YOLO(YOLO_MODEL_PATH)

print("Loading ResNet...")
resnet = models.resnet18()
resnet.fc = nn.Linear(resnet.fc.in_features, 2)
checkpoint = torch.load(RESNET_MODEL_PATH, map_location="cpu")
resnet.load_state_dict(checkpoint["model_state"])
resnet.eval()

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

# ======================
# CAMERA Setup
# ======================

#cap = cv2.VideoCapture(CAMERA_INDEX)
cap = cv2.VideoCapture(PI_STREAM_URL)
if not cap.isOpened():
    raise Exception("Cannot open camera")

cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
cap.set(cv2.CAP_PROP_FPS, 30)

print("Fridge AI started. Press 'r' to capture manually, 'q' to quit.")
last_capture_time = time.time()

miss_streak: dict[str, int] = defaultdict(int)

# ======================
# HELPERS
# ======================

def encode_crop(crop_bgr):
    ret, buffer = cv2.imencode('.jpg', crop_bgr)
    if ret:
        return base64.b64encode(buffer).decode('utf-8')
    return None

def classify_freshness(crop_bgr) -> float:
    crop_rgb = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2RGB)
    pil_img  = Image.fromarray(crop_rgb)
    tensor   = transform(pil_img).unsqueeze(0)
    with torch.no_grad():
        output = resnet(tensor)
    avg_score = output.mean(dim=1)
    final_score = torch.clamp(avg_score, 0.0, 1.0).item()
    return final_score


def score_to_eat_label(name: str, score: float) -> tuple[str, str]:
    score = float(score)
    table = FRESHNESS_SCORE_TABLE.get(name, FRESHNESS_SCORE_TABLE["default"])
    for low, high, label in table:
        if low <= score <= high:
            freshness_key = "fresh" if score >= 0.70 else "not_fresh"
            return label, freshness_key
    return "Rotten", "not_fresh"


def iou(a, b) -> float:
    ix1 = max(a[0], b[0]); iy1 = max(a[1], b[1])
    ix2 = min(a[2], b[2]); iy2 = min(a[3], b[3])
    inter = max(0, ix2 - ix1) * max(0, iy2 - iy1)
    area_a = (a[2]-a[0]) * (a[3]-a[1])
    if area_a <= 0:
        return 0.0
    return inter / area_a


def detect_frame(frame) -> list[dict]:
    h, w = frame.shape[:2]
    all_boxes  = []
    seen_areas = []

    first_results = yolo_model(frame, conf=CONF_FIRST_PASS, verbose=False)

    for box in first_results[0].boxes:
        x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())

        cx1 = max(0, x1 - PADDING)
        cy1 = max(0, y1 - PADDING)
        cx2 = min(w, x2 + PADDING)
        cy2 = min(h, y2 + PADDING)
        crop_region = frame[cy1:cy2, cx1:cx2]

        second_results = yolo_model(crop_region, conf=CONF_SECOND_PASS, verbose=False)

        for b in second_results[0].boxes:
            bx1 = int(b.xyxy[0][0]) + cx1
            by1 = int(b.xyxy[0][1]) + cy1
            bx2 = int(b.xyxy[0][2]) + cx1
            by2 = int(b.xyxy[0][3]) + cy1
            b_label = yolo_model.names[int(b.cls[0])].lower()
            b_conf  = float(b.conf[0])

            if any(iou((bx1, by1, bx2, by2), prev) > 0.5 for prev in seen_areas):
                continue

            crop_box = frame[by1:by2, bx1:bx2]
            if crop_box.size > 0:
                all_boxes.append({
                    "label": b_label, "conf": b_conf,
                    "x1": bx1, "y1": by1, "x2": bx2, "y2": by2,
                    "crop": crop_box,
                })
                seen_areas.append((bx1, by1, bx2, by2))

    if not all_boxes:
        for box in first_results[0].boxes:
            x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
            label    = yolo_model.names[int(box.cls[0])].lower()
            crop_box = frame[y1:y2, x1:x2]
            if crop_box.size > 0:
                all_boxes.append({
                    "label": label, "conf": float(box.conf[0]),
                    "x1": x1, "y1": y1, "x2": x2, "y2": y2,
                    "crop": crop_box,
                })

    return all_boxes


# ======================
# MAIN LOOP
# ======================

while True:
    ret, frame = cap.read()
    if not ret:
        continue

    cv2.imshow("Fridge AI", frame)
    time.sleep(0.01)  
    key          = cv2.waitKey(1) & 0xFF
    current_time = time.time()

    if key == ord("q"):
        break

    is_manual = (key == ord("r"))
    is_timer  = (current_time - last_capture_time >= CAPTURE_INTERVAL)

    if not (is_manual or is_timer):
        continue

    print(f"\n[INFO] Trigger: {'Manual' if is_manual else 'Timer (1h)'}")
    if is_timer:
        last_capture_time = current_time

    detected_boxes = detect_frame(frame)
    annotated      = frame.copy()

    detected_items = []
    detected_names = set()

    for b in detected_boxes:
        label = b["label"]
        score = classify_freshness(b["crop"])
        freshness_label, freshness_key = score_to_eat_label(label, score)

        cx = (b["x1"] + b["x2"]) / 2.0
        cy = (b["y1"] + b["y2"]) / 2.0

        # ส่งแยกทีละชิ้นเลย (1 Box = 1 Item)
        detected_items.append({
            "name": label,
            "quantity": 1.0, 
            "freshness": freshness_key,
            "freshness_score": round(score, 3),
            "freshness_label": freshness_label,
            "center_x": round(cx, 2),
            "center_y": round(cy, 2),
            "image_base64": encode_crop(b["crop"])
        })
        detected_names.add(label)

        color = (0, 255, 0) if freshness_key == "fresh" else (0, 0, 255)
        cv2.rectangle(annotated, (b["x1"], b["y1"]), (b["x2"], b["y2"]), color, 2)
        cv2.putText(annotated,
            f"{label}: {freshness_label} ({score:.2f})",
            (b["x1"], b["y1"] - 10),
            cv2.FONT_HERSHEY_SIMPLEX, 0.55, color, 2)

    all_known = set(miss_streak.keys()) | detected_names
    for name in all_known:
        if name in detected_names:
            miss_streak[name] = 0          
        else:
            miss_streak[name] += 1         

    pending = {k: v for k, v in miss_streak.items() if 0 < v < MISS_STREAK_THRESHOLD}
    print(f"[INFO] Detected: {detected_names or '(nothing)'}")
    print(f"[INFO] Pending (not yet confirmed used): {pending}")

    try:
        response = requests.post(
            SNAPSHOT_URL,
            json={
                "items":           detected_items,
                "miss_streak":     dict(miss_streak),
                "miss_threshold":  MISS_STREAK_THRESHOLD,
                "snapshot_time":   time.time(),
            },
            timeout=REQUEST_TIMEOUT,
        )
        if response.status_code == 200:
            r = response.json()
            print(f"✅ Snapshot OK")
            print(f"   added:   {r.get('added',   [])}")
            print(f"   updated: {r.get('updated', [])}")
            print(f"   pending: {r.get('still_missing', [])}  ← หายแต่ยังไม่ถึง threshold")
            print(f"   used:    {r.get('used',    [])}")
            print(f"   wasted:  {r.get('wasted',  [])}")
        else:
            print(f"❌ Backend {response.status_code}: {response.text}")

    except Exception as e:
        print(f"❌ Request failed: {e}")

    cv2.putText(annotated,
        f"Detected: {len(detected_boxes)} boxes / {len(detected_names)} types",
        (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 200, 0), 2)
    cv2.imshow("Fridge AI", annotated)

    if is_manual:
        print("Press any key to resume...")
        cv2.waitKey(0)
    else:
        cv2.waitKey(2000)

cap.release()
cv2.destroyAllWindows()
