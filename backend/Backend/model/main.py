from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime, timedelta

import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
from ultralytics import YOLO

import io
import os
import json
import logging
import time
import math
import base64

# ================= INIT =================
app = FastAPI(title="Fruit Detection API")

os.makedirs("static/images", exist_ok=True)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory="static"), name="static")

# ================= CONFIG =================
YOLO_MODEL_PATH         = "best.pt"
REG_MODEL_PATH          = "best_resnet_fruit.pth"
IMG_SIZE                = 224
CONF_THRESHOLD          = 0.85
COOLDOWN_SECONDS        = 20
BBOX_DISTANCE_THRESHOLD = 60
MISSING_THRESHOLD       = 3

PRICE_DB_FILE    = "price_db.json"
INVENTORY_FILE   = "inventory_db.json"

# ================= FRESHNESS TABLE =================

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
        (0.95, 1.00, "rotten"),
        (0.85, 0.94, "Eat within 14 days"),
        (0.70, 0.84, "Eat within 7 days"),
    ],
}

def score_to_eat_label(name: str, score: float) -> str:
    """Return eat_label based on raw score and food-specific rules."""
    score = float(score)
    table = FRESHNESS_SCORE_TABLE.get(name, FRESHNESS_SCORE_TABLE["default"])
    for low, high, label in table:
        if low <= score <= high:
            return label
    return "Rotten"

# ================= PERSISTENCE =================

def _load_price_db() -> dict:
    if os.path.exists(PRICE_DB_FILE):
        try:
            with open(PRICE_DB_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def _save_price_db(db: dict) -> None:
    try:
        with open(PRICE_DB_FILE, "w") as f:
            json.dump(db, f, ensure_ascii=False, indent=2)
    except Exception as e:
        logger.warning(f"Failed to save price_db: {e}")

def _load_inventory() -> list:
    if os.path.exists(INVENTORY_FILE):
        try:
            with open(INVENTORY_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return []

def _save_inventory() -> None:
    try:
        with open(INVENTORY_FILE, "w") as f:
            json.dump(inventory_storage, f, ensure_ascii=False, indent=2, default=str)
    except Exception as e:
        logger.warning(f"Failed to save inventory: {e}")

price_db: dict          = _load_price_db()
inventory_storage: list = _load_inventory()
last_detection          = {"class": None, "time": 0, "center": None}

logger.info(f"Loaded price_db: {len(price_db)} entries")
logger.info(f"Loaded inventory: {len(inventory_storage)} items")

# ── migrate ────────────────────────────────────────────────────────────────────
_migrated = 0
for _item in inventory_storage:
    changed = False

    if "used_quantity" not in _item:
        _item["used_quantity"] = 0.0
        changed = True
    if "initial_quantity" not in _item:
        _item["initial_quantity"] = round(
            _item.get("quantity", 0.0) + _item.get("used_quantity", 0.0), 4
        )
        changed = True

    _qty     = _item.get("quantity", 0.0)
    _used    = _item.get("used_quantity", 0.0)
    _initial = _item.get("initial_quantity", 0.0)
    _min_initial = round(_qty + _used, 4)
    if _initial < _min_initial:
        logger.info(
            f"[REPAIR] {_item.get('name')} "
            f"initial_quantity {_initial} → {_min_initial} "
            f"(qty={_qty} used={_used})"
        )
        _item["initial_quantity"] = _min_initial
        changed = True

    if changed:
        _migrated += 1

if _migrated:
    _save_inventory()
    logger.info(f"Migrated/repaired {_migrated} items")

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
logger.info(f"Using device: {DEVICE}")

# ================= MODEL LOAD =================
if not os.path.exists(YOLO_MODEL_PATH):
    raise FileNotFoundError(f"{YOLO_MODEL_PATH} not found")
if not os.path.exists(REG_MODEL_PATH):
    raise FileNotFoundError(f"{REG_MODEL_PATH} not found")

logger.info("Loading YOLO...")
yolo = YOLO(YOLO_MODEL_PATH)

logger.info("Loading ResNet...")
reg_model = models.resnet18(weights=None)
reg_model.fc = nn.Linear(512, 2)
ckpt = torch.load(REG_MODEL_PATH, map_location=DEVICE)
state_dict = ckpt["model_state"] if isinstance(ckpt, dict) and "model_state" in ckpt else ckpt
reg_model.load_state_dict(state_dict)
reg_model.to(DEVICE)
reg_model.eval()
logger.info("Models loaded successfully")

transform = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

# ================= PYDANTIC MODELS =================

class InventoryCreate(BaseModel):
    name: str
    quantity: float
    initial_quantity: Optional[float] = None
    used_quantity: Optional[float] = None
    unit: Optional[str] = None
    freshness: Optional[str] = None
    price: Optional[float] = None
    expiry_date: Optional[str] = None
    purchase_date: Optional[str] = None
    location: Optional[str] = None
    image_url: Optional[str] = None

class InventoryItem(BaseModel):
    id: str
    name: str
    quantity: float
    initial_quantity: float = 0.0
    used_quantity: float    = 0.0
    unit: str
    freshness: Optional[str] = None
    freshness_label: Optional[str] = None
    price: Optional[float] = None
    expiry_date: Optional[str] = None
    purchase_date: Optional[str] = None
    source: str
    location: str
    status: str
    removed_date: Optional[str] = None
    missing_count: int = 0
    image_url: Optional[str] = None
    freshness_score: Optional[float] = None  
    center_x: Optional[float] = None         
    center_y: Optional[float] = None         

class SnapshotItem(BaseModel):
    name: str
    quantity: float
    freshness: str
    freshness_score: Optional[float] = None
    freshness_label: Optional[str] = None
    center_x: Optional[float] = None
    center_y: Optional[float] = None
    image_base64: Optional[str] = None

class SnapshotPayload(BaseModel):
    items: List[SnapshotItem]
    snapshot_time: Optional[float] = None

# ================= HELPERS =================

EXPIRY_DAYS: dict[str, tuple[int, int]] = {
    "pork":        (2, 1),
    "beef":        (2, 1),
    "fish":        (1, 1),
    "bell pepper": (7, 3),
    "carrot":      (14, 5),
    "cucumber":    (7, 3),
    "tomato":      (5, 2),
    "potato":      (21, 7),
    "apple":       (14, 3),
    "banana":      (5,  2),
    "orange":      (14, 5),
    "guava":       (5,  2),
    "mango":       (5,  2),
    "default":     (5,  2),
}

def auto_expiry(freshness: str, name: str = "") -> str:
    key = _clean_name(name) if name else "default"
    fresh_days, rotten_days = EXPIRY_DAYS.get(key, EXPIRY_DAYS["default"])
    days = fresh_days if freshness == "fresh" else rotten_days
    return (datetime.now() + timedelta(days=days)).strftime("%Y-%m-%d")

def _clean_name(name: str) -> str:
    name = name.lower().strip()
    name = name.replace("_not_fresh", "").replace("_fresh", "")
    return name.strip("_")

def _is_expired(item: dict) -> bool:
    exp = item.get("expiry_date")
    if not exp:
        return False
    try:
        return datetime.strptime(exp[:10], "%Y-%m-%d").date() < datetime.now().date()
    except ValueError:
        return False

def _get_last_known_price(name: str) -> Optional[float]:
    key = name.lower().strip()
    if key in price_db:
        return price_db[key]
    for item in reversed(inventory_storage):
        if item["name"].lower() == key and item.get("price") is not None:
            return item["price"]
    return None

def _remember_price(name: str, price: Optional[float]) -> None:
    if price is None or price <= 0:
        return
    price_db[name.lower().strip()] = price
    _save_price_db(price_db)

def _active_auto_items() -> list[dict]:
    return [i for i in inventory_storage
            if i.get("source") == "auto" and i.get("status") == "inFridge"]

def _new_item_base(
    name: str, quantity: float, unit: str, freshness: str,
    price: Optional[float], expiry_date: Optional[str],
    source: str, location: str,
    purchase_date: Optional[str] = None,
    freshness_label: Optional[str] = None,
    image_url: Optional[str] = None,
    freshness_score: Optional[float] = None,
    center_x: Optional[float] = None,
    center_y: Optional[float] = None,
) -> dict:
    if not purchase_date:
        purchase_date = datetime.now().isoformat()

    return {
        "id":               str(uuid4()),
        "name":             name,
        "quantity":         quantity,
        "initial_quantity": quantity,
        "used_quantity":    0.0,
        "purchase_date":    purchase_date,
        "unit":             unit,
        "freshness":        freshness,
        "freshness_label": freshness_label,
        "price":            price,
        "expiry_date":      expiry_date,
        "source":           source,
        "location":         location,
        "status":           "inFridge",
        "removed_date":     None,
        "missing_count":    0,
        "image_url":        image_url,
        "freshness_score":  freshness_score,
        "center_x":         center_x,
        "center_y":         center_y,
    }

# ================= HEALTH =================

@app.get("/")
def health():
    return {"status": "API running", "device": DEVICE}

# ================= INVENTORY =================

@app.get("/inventory")
def get_inventory(include_removed: bool = False):
    if include_removed:
        items = inventory_storage
    else:
        items = [i for i in inventory_storage if i.get("status") == "inFridge"]
    
    return {"total_items": len(items), "items": items}


@app.post("/inventory", response_model=InventoryItem)
def add_inventory(item: InventoryCreate):
    new_item = _new_item_base(
        name          = item.name,
        quantity      = item.quantity,
        unit          = item.unit or "piece",
        freshness     = item.freshness or "fresh",
        price         = item.price,
        expiry_date   = item.expiry_date,
        purchase_date = item.purchase_date,
        source        = "manual",
        location      = item.location or "in_fridge",
        image_url     = item.image_url,
    )
    inventory_storage.append(new_item)
    _remember_price(item.name, item.price)
    _save_inventory()
    return new_item


@app.post("/inventory/from-pi")
def add_from_pi(item: InventoryCreate):
    for existing in inventory_storage:
        if (existing["name"] == item.name
                and existing["freshness"] == item.freshness
                and existing.get("source") == "auto"
                and existing.get("status") == "inFridge"):
            existing["quantity"]         += item.quantity
            existing["initial_quantity"] += item.quantity
            if item.image_url:
                existing["image_url"] = item.image_url
            return {"status": "updated"}

    new_item = _new_item_base(
        name        = _clean_name(item.name),
        quantity    = item.quantity,
        unit        = item.unit or "piece",
        freshness   = item.freshness or "fresh",
        price       = item.price if item.price is not None else _get_last_known_price(item.name),
        expiry_date = item.expiry_date or auto_expiry(item.freshness or "fresh", item.name),
        source      = "auto",
        location    = item.location,
        image_url   = item.image_url,
    )
    inventory_storage.append(new_item)
    return {"status": "created"}


# ── USE (manual) ──────────────────────────────────────────────────────────────
@app.post("/inventory/{item_id}/use")
def use_inventory(item_id: str, qty: float = 1.0):
    for item in inventory_storage:
        if item["id"] != item_id:
            continue
        if item.get("status") != "inFridge":
            raise HTTPException(status_code=400, detail="Item is not in fridge")
        if qty <= 0:
            raise HTTPException(status_code=400, detail="qty must be > 0")
        if qty > item["quantity"]:
            raise HTTPException(
                status_code=400,
                detail=f"qty ({qty}) exceeds remaining stock ({item['quantity']})"
            )

        item["quantity"]      = round(item["quantity"]      - qty, 4)
        item["used_quantity"] = round(item.get("used_quantity", 0.0) + qty, 4)

        if item["quantity"] <= 0:
            item["quantity"]     = 0.0
            item["status"]       = "used"
            item["removed_date"] = datetime.now().isoformat()
            logger.info(f"[USED-ALL] {item['name']} fully consumed")
        else:
            logger.info(
                f"[USED-PARTIAL] {item['name']} "
                f"used={item['used_quantity']} remaining={item['quantity']}"
            )

        _save_inventory()
        return {
            "status":           item["status"],
            "remaining":        item["quantity"],
            "used_quantity":    item["used_quantity"],
            "initial_quantity": item["initial_quantity"],
        }

    raise HTTPException(status_code=404, detail="Item not found")


# ── SNAPSHOT ──────────────────────────────────────────────────────────────────
def save_base64_image(b64_str: str, name: str) -> str:
    try:
        img_data = base64.b64decode(b64_str)
        filename = f"{_clean_name(name)}_{uuid4().hex[:8]}.jpg"
        filepath = os.path.join("static", "images", filename)
        with open(filepath, "wb") as f:
            f.write(img_data)
        return f"/static/images/{filename}"
    except Exception as e:
        logger.error(f"Failed to save image: {e}")
        return None

@app.post("/inventory/snapshot")
def process_snapshot(payload: SnapshotPayload):
    now_str = datetime.now().isoformat()
    
    # 1) เตรียมข้อมูล Detected Pool (1 ชิ้น = 1 Item)
    detected_pool = []
    for det in payload.items:
        img_url = None
        if det.image_base64:
            img_url = save_base64_image(det.image_base64, _clean_name(det.name))
        
        qty = int(det.quantity) if det.quantity >= 1 else 1
        for _ in range(qty):
            detected_pool.append({
                "name": _clean_name(det.name),
                "freshness": det.freshness,
                "freshness_score": getattr(det, 'freshness_score', None),
                "freshness_label": getattr(det, 'freshness_label', None),
                "center_x": getattr(det, 'center_x', None),
                "center_y": getattr(det, 'center_y', None),
                "image_url": img_url
            })

    matched_existing_ids = set()
    matched_det_indices = set()

    # 2) Hungarian Matching (Greedy Cost Function)
    def do_match(candidates, strict=False):
        pairs = []
        for i, det in enumerate(detected_pool):
            if i in matched_det_indices: continue
            for cand in candidates:
                if cand["id"] in matched_existing_ids: continue
                if cand["name"] != det["name"]: continue
                if strict and cand.get("freshness") != det["freshness"]: continue
                
                cx1, cy1 = cand.get("center_x"), cand.get("center_y")
                cx2, cy2 = det.get("center_x"), det.get("center_y")
                
                if cx1 is not None and cy1 is not None and cx2 is not None and cy2 is not None:
                    dist = math.sqrt((cx1 - cx2)**2 + (cy1 - cy2)**2)
                else:
                    dist = 500  
                
                s1 = cand.get("freshness_score")
                s2 = det.get("freshness_score")
                score_diff = abs(s1 - s2) if (s1 is not None and s2 is not None) else 0.5
                
                cost = dist + (score_diff * 500)
                pairs.append((cost, i, cand))
                
        pairs.sort(key=lambda x: x[0])
        
        for cost, det_idx, cand in pairs:
            if det_idx not in matched_det_indices and cand["id"] not in matched_existing_ids:
                matched_det_indices.add(det_idx)
                matched_existing_ids.add(cand["id"])
                
                det = detected_pool[det_idx]
                
                if cand["status"] != "inFridge":
                    logger.info(f"[RESURRECTED] {cand['name']} → inFridge")
                    cand["status"] = "inFridge"
                    cand["removed_date"] = None
                    recover_qty = min(1.0, cand.get("used_quantity", 0.0))
                    cand["used_quantity"] = round(cand.get("used_quantity", 0.0) - recover_qty, 4)
                    cand["quantity"] = 1.0
                else:
                    if cand.get("quantity", 0) != 1.0:
                        cand["quantity"] = 1.0
                        cand["initial_quantity"] = 1.0
                        cand["used_quantity"] = 0.0

                cand["freshness"] = det["freshness"]
                cand["freshness_score"] = det["freshness_score"]
                cand["center_x"] = det["center_x"]
                cand["center_y"] = det["center_y"]
                cand["missing_count"] = 0
                
                if det["freshness_label"]:
                    cand["freshness_label"] = det["freshness_label"]
                if det["image_url"]:
                    cand["image_url"] = det["image_url"]
                    
                cand["expiry_date"] = auto_expiry(det["freshness"], cand["name"])

    in_fridge_candidates = [i for i in inventory_storage if i.get("source") == "auto" and i.get("status") == "inFridge"]
    resurrection_cutoff = datetime.now() - timedelta(hours=MISSING_THRESHOLD + 1)
    resurrection_candidates = [
        i for i in inventory_storage 
        if i.get("source") == "auto" and i.get("status") in ("used", "wasted") and i.get("removed_date") and datetime.fromisoformat(i["removed_date"]) > resurrection_cutoff
    ]
    
    do_match(in_fridge_candidates, strict=True)
    do_match(in_fridge_candidates, strict=False)
    do_match(resurrection_candidates, strict=True)
    do_match(resurrection_candidates, strict=False)
    
    # 3) จัดการชิ้นที่หาคู่ไม่เจอ (โดนหยิบออกไป)
    newly_used = []
    newly_wasted = []
    for existing in _active_auto_items():
        if existing["id"] in matched_existing_ids:
            continue
        existing["missing_count"] = existing.get("missing_count", 0) + 1
        streak = existing["missing_count"]
        
        if streak >= MISSING_THRESHOLD:
            if _is_expired(existing):
                existing["status"] = "wasted"
                newly_wasted.append(existing["name"])
            else:
                existing["status"] = "used"
                existing["used_quantity"] = round(existing.get("used_quantity", 0.0) + existing.get("quantity", 1.0), 4)
                newly_used.append(existing["name"])
            
            existing["quantity"] = 0.0
            existing["removed_date"] = now_str
            
    # 4) สร้าง Item ใหม่สำหรับชิ้นที่ไม่เคยมีในระบบ
    added = []
    for i, det in enumerate(detected_pool):
        if i not in matched_det_indices:
            new_item = _new_item_base(
                name=det["name"],
                quantity=1.0,
                unit="piece",
                freshness=det["freshness"],
                freshness_label=det["freshness_label"],
                price=_get_last_known_price(det["name"]),
                expiry_date=auto_expiry(det["freshness"], det["name"]),
                source="auto",
                location="in_fridge",
                image_url=det["image_url"],
                freshness_score=det["freshness_score"],
                center_x=det["center_x"],
                center_y=det["center_y"]
            )
            inventory_storage.append(new_item)
            added.append(det["name"])
            
    _save_inventory()
    
    return {
        "added": added,
        "updated": [i["name"] for i in inventory_storage if i["id"] in matched_existing_ids],
        "used": newly_used,
        "wasted": newly_wasted,
        "still_missing": [
            {"name": i["name"], "streak": i["missing_count"], "threshold": MISSING_THRESHOLD}
            for i in _active_auto_items() if i.get("missing_count", 0) > 0
        ]
    }


@app.delete("/inventory/auto")
def clear_auto_inventory():
    global inventory_storage
    inventory_storage = [i for i in inventory_storage if i.get("source") != "auto"]
    _save_inventory()
    return {"message": "Auto inventory cleared"}


@app.put("/inventory/{item_id}", response_model=InventoryItem)
def update_inventory(item_id: str, updated: InventoryCreate):
    for item in inventory_storage:
        if item["id"] == item_id:
            item["name"]          = updated.name
            item["quantity"]      = updated.quantity
            item["unit"]          = updated.unit or item.get("unit", "piece")
            item["freshness"]     = updated.freshness or item["freshness"]
            item["price"]         = updated.price
            item["expiry_date"]   = updated.expiry_date
            item["purchase_date"] = updated.purchase_date or item.get("purchase_date")
            item["location"]      = updated.location or item.get("location")

            if hasattr(updated, "image_url") and updated.image_url is not None:
                item["image_url"] = updated.image_url

            if updated.initial_quantity is not None:
                item["initial_quantity"] = updated.initial_quantity

            if updated.used_quantity is not None:
                item["used_quantity"] = updated.used_quantity

            _remember_price(updated.name, updated.price)
            _save_inventory()
            return item
    raise HTTPException(status_code=404, detail="Item not found")


@app.delete("/inventory/{item_id}")
def delete_inventory(item_id: str):
    for item in inventory_storage:
        if item["id"] == item_id:
            remaining = item.get("quantity", 0.0)
            if _is_expired(item):
                item["status"] = "wasted"
            else:
                item["status"] = "wasted"
            item["quantity"]     = 0.0
            item["removed_date"] = datetime.now().isoformat()
            _save_inventory()
            return {"message": f"Item marked as {item['status']}"}
    raise HTTPException(status_code=404, detail="Item not found")


@app.delete("/inventory/{item_id}/hard")
def hard_delete_inventory(item_id: str):
    global inventory_storage
    before = len(inventory_storage)
    inventory_storage = [i for i in inventory_storage if i["id"] != item_id]
    if len(inventory_storage) == before:
        raise HTTPException(status_code=404, detail="Item not found")
    _save_inventory()
    logger.info(f"[HARD DELETE] {item_id}")
    return {"message": "Item permanently deleted"}


# ================= PREDICT =================

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    contents = await file.read()
    try:
        img = Image.open(io.BytesIO(contents)).convert("RGB")
    except:
        raise HTTPException(status_code=400, detail="Invalid image")
    result = run_inference(img)
    if result["count"] > 0:
        handle_inventory_logic(result["detections"][0])
    return result


def handle_inventory_logic(detection):
    global last_detection
    detected_class  = detection["class"]
    freshness       = detection["freshness"]
    freshness_label = detection.get("freshness_label")
    bbox            = detection["bbox"]
    center_x        = (bbox[0] + bbox[2]) / 2
    center_y        = (bbox[1] + bbox[3]) / 2
    current_time    = time.time()

    is_same_object = False
    if last_detection["center"] is not None:
        prev_x, prev_y = last_detection["center"]
        distance = math.sqrt((center_x - prev_x)**2 + (center_y - prev_y)**2)
        if (detected_class == last_detection["class"]
                and distance < BBOX_DISTANCE_THRESHOLD
                and current_time - last_detection["time"] < COOLDOWN_SECONDS):
            is_same_object = True

    if is_same_object:
        logger.info("Duplicate object skipped")
        return

    for item in inventory_storage:
        if (item["name"] == detected_class
                and item["freshness"] == freshness
                and item.get("status") == "inFridge"):
            item["quantity"]         += 1
            item["initial_quantity"] += 1
            if freshness_label:
                item["freshness_label"] = freshness_label
            break
    else:
        new_item = _new_item_base(
            name            = detected_class,
            quantity        = 1,
            unit            = "piece",
            freshness       = freshness,
            freshness_label = freshness_label,
            price           = None,
            expiry_date     = auto_expiry(freshness, detected_class),
            source          = "auto",
            location        = "in_fridge",
        )
        inventory_storage.append(new_item)

    last_detection = {
        "class": detected_class, "time": current_time,
        "center": (center_x, center_y)
    }
    logger.info(f"Added: {detected_class} ({freshness}) label={freshness_label}")


# ================= INFERENCE =================

def run_inference(img):
    detections = []
    try:
        with torch.no_grad():
            results   = yolo(img)
            boxes     = results[0].boxes
            names     = results[0].names
            if boxes is None or len(boxes) == 0:
                return {"count": 0, "detections": []}
            best_box  = max(boxes, key=lambda b: float(b.conf[0].item()))
            best_conf = float(best_box.conf[0].item())
            if best_conf < CONF_THRESHOLD:
                return {"count": 0, "detections": []}
            x1, y1, x2, y2 = map(int, best_box.xyxy[0].cpu().numpy())
            cls_id    = int(best_box.cls[0].item())
            raw_name  = names[cls_id]
            base_name = raw_name.replace("_fresh", "").replace("_not_fresh", "")
            crop      = img.crop((x1, y1, x2, y2))
            tensor    = transform(crop).unsqueeze(0).to(DEVICE)
            output    = reg_model(tensor)
            probs     = torch.softmax(output, dim=1)
            score     = float(probs[0][1].item())
            is_fresh  = score > 0.5
            freshness = "fresh" if is_fresh else "not_fresh"

            table_key       = f"{base_name}_fresh" if is_fresh else "default"
            freshness_label = score_to_eat_label(table_key, score)

            detections.append({
                "class":           base_name,
                "confidence":      round(best_conf, 3),
                "freshness_score": round(score, 3),
                "freshness":       freshness,
                "freshness_label": freshness_label,
                "bbox":            [x1, y1, x2, y2]
            })
    except Exception as e:
        logger.error(f"Inference error: {e}")
        raise HTTPException(status_code=500, detail="Model inference failed")
    return {"count": len(detections), "detections": detections}
