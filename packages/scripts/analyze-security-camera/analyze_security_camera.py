#!/usr/bin/env python3
"""
analyze-security-camera
=======================

Analyse a single security-camera clip and emit a JSON record describing every
person / cyclist / vehicle seen, including a measured average speed.

How the speed is measured
-------------------------
Two "gates" (lines in the image) are drawn through the base of each mailbox.
The real-world distance between them is known (laser-measured, 28.8 ft).

    average_speed = baseline_ft / (t_gate_b - t_gate_a)

Because only *time* is measured, no pixels-per-foot scale is ever needed, so
lens perspective and foreshortening cannot bias the result. The gates are aimed
at a shared cross-road vanishing point, which makes them parallel on the ground
plane -- so the 28.8 ft holds for either lane, not just at the shoulder.

The camera drifts slightly between clips, so each clip's static background is
registered against a stored reference frame and the gates are warped to match.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
from pathlib import Path

import cv2
import numpy as np

TOOL_VERSION = "0.2.0"
SCHEMA_VERSION = 2

FT_S_TO_MPH = 0.681818181818
FT_S_TO_KPH = 1.09728

# COCO ids we care about.
CLASS_MAP = {0: "person", 1: "bicycle", 2: "car", 3: "motorcycle", 5: "bus", 7: "truck"}
KIND_MAP = {
    "person": "pedestrian",
    "bicycle": "cyclist",
    "car": "vehicle",
    "motorcycle": "vehicle",
    "bus": "vehicle",
    "truck": "vehicle",
}

COLOR_NAMES = [
    "black", "white", "silver", "gray", "red", "orange",
    "yellow", "green", "blue", "purple", "pink", "brown",
]


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


# --------------------------------------------------------------------------
# Source metadata
# --------------------------------------------------------------------------

def parse_source_meta(path: Path) -> dict:
    """Pull camera name + recording timestamp out of e.g.
    Driveway_00_20260905080552.mp4"""
    meta = {"camera": None, "recorded_at": None}
    stem = path.stem
    m = re.search(r"(\d{14})", stem)
    if m:
        try:
            meta["recorded_at"] = dt.datetime.strptime(m.group(1), "%Y%m%d%H%M%S").isoformat()
        except ValueError:
            pass
    lead = stem.split("_")[0]
    if lead:
        meta["camera"] = lead.lower()
    return meta


# --------------------------------------------------------------------------
# Calibration / geometry
# --------------------------------------------------------------------------

def load_calibration(path: Path) -> dict:
    with open(path) as fh:
        return json.load(fh)


def median_background(video: Path, size: tuple[int, int], samples: int = 9) -> np.ndarray | None:
    """Median of N evenly spaced frames -> static background, moving cars removed."""
    cap = cv2.VideoCapture(str(video))
    if not cap.isOpened():
        return None
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    frames = []
    if total > 0:
        idxs = np.linspace(0, max(total - 1, 0), num=min(samples, max(total, 1)), dtype=int)
        for i in idxs:
            cap.set(cv2.CAP_PROP_POS_FRAMES, int(i))
            ok, fr = cap.read()
            if ok:
                frames.append(cv2.resize(fr, size, interpolation=cv2.INTER_AREA))
    else:
        while len(frames) < samples:
            ok, fr = cap.read()
            if not ok:
                break
            frames.append(cv2.resize(fr, size, interpolation=cv2.INTER_AREA))
    cap.release()
    if not frames:
        return None
    return np.median(np.stack(frames), axis=0).astype(np.uint8)


def estimate_alignment(ref_bgr: np.ndarray, cur_bgr: np.ndarray) -> tuple[np.ndarray, dict]:
    """Similarity transform mapping reference-frame coords -> this clip's coords."""
    identity = np.array([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0]], dtype=np.float64)
    info = {"applied": False, "method": "orb+ransac_affine", "inliers": 0, "translation_px": [0.0, 0.0]}

    ref_g = cv2.cvtColor(ref_bgr, cv2.COLOR_BGR2GRAY)
    cur_g = cv2.cvtColor(cur_bgr, cv2.COLOR_BGR2GRAY)

    orb = cv2.ORB_create(nfeatures=4000)
    k1, d1 = orb.detectAndCompute(ref_g, None)
    k2, d2 = orb.detectAndCompute(cur_g, None)
    if d1 is None or d2 is None or len(k1) < 20 or len(k2) < 20:
        info["reason"] = "insufficient_features"
        return identity, info

    bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
    matches = sorted(bf.match(d1, d2), key=lambda m: m.distance)[:800]
    if len(matches) < 20:
        info["reason"] = "insufficient_matches"
        return identity, info

    src = np.float32([k1[m.queryIdx].pt for m in matches]).reshape(-1, 1, 2)
    dst = np.float32([k2[m.trainIdx].pt for m in matches]).reshape(-1, 1, 2)

    M, inl = cv2.estimateAffinePartial2D(src, dst, method=cv2.RANSAC, ransacReprojThreshold=3.0)
    if M is None or inl is None or int(inl.sum()) < 20:
        info["reason"] = "ransac_failed"
        return identity, info

    scale = float(np.hypot(M[0, 0], M[1, 0]))
    shift = float(np.hypot(M[0, 2], M[1, 2]))
    # Sanity guard: the camera nudges, it does not teleport.
    if not (0.9 < scale < 1.1) or shift > 400.0:
        info["reason"] = f"implausible_transform(scale={scale:.3f},shift={shift:.1f})"
        return identity, info

    info.update(
        applied=True,
        inliers=int(inl.sum()),
        translation_px=[round(float(M[0, 2]), 2), round(float(M[1, 2]), 2)],
        scale=round(scale, 4),
    )
    return M.astype(np.float64), info


def transform_pts(pts, M: np.ndarray, sx: float, sy: float) -> list[list[float]]:
    """Reference-space points -> aligned, native-resolution points."""
    arr = np.array(pts, dtype=np.float64).reshape(-1, 1, 2)
    arr = cv2.transform(arr, M).reshape(-1, 2)
    arr[:, 0] *= sx
    arr[:, 1] *= sy
    return arr.tolist()


def signed_distance(pt, line) -> float:
    (x1, y1), (x2, y2) = line
    dx, dy = x2 - x1, y2 - y1
    n = float(np.hypot(dx, dy)) or 1.0
    return ((pt[0] - x1) * dy - (pt[1] - y1) * dx) / n


def segment_param(pt, line) -> float:
    """Where the point projects along the gate segment (0..1 = within it)."""
    (x1, y1), (x2, y2) = line
    dx, dy = x2 - x1, y2 - y1
    denom = dx * dx + dy * dy
    if denom <= 0:
        return 0.0
    return ((pt[0] - x1) * dx + (pt[1] - y1) * dy) / denom


def find_crossing(track: list[dict], line, tol: float = 0.25):
    """First signed-distance sign change, with sub-frame linear interpolation."""
    for prev, cur in zip(track, track[1:]):
        a = signed_distance(prev["pt"], line)
        b = signed_distance(cur["pt"], line)
        if a == 0.0 and b == 0.0:
            continue
        if (a < 0) == (b < 0):
            continue
        frac = a / (a - b) if (a - b) != 0 else 0.0
        frac = min(max(frac, 0.0), 1.0)
        t = prev["t"] + frac * (cur["t"] - prev["t"])
        px = prev["pt"][0] + frac * (cur["pt"][0] - prev["pt"][0])
        py = prev["pt"][1] + frac * (cur["pt"][1] - prev["pt"][1])
        u = segment_param((px, py), line)
        if not (-tol <= u <= 1.0 + tol):
            continue  # crossed the infinite line, but off the end of the gate
        return {"t": float(t), "point": [float(px), float(py)], "u": float(u)}
    return None


def point_in_poly(pt, poly) -> bool:
    if not poly:
        return False
    c = np.array(poly, dtype=np.float32).reshape(-1, 1, 2)
    return cv2.pointPolygonTest(c, (float(pt[0]), float(pt[1])), False) >= 0


def build_ground_homography(calib: dict, M: np.ndarray, sx: float, sy: float):
    """Build an image-pixel -> ground-feet homography for the aligned clip."""
    plane = calib.get("ground_plane")
    if not plane or not plane.get("enabled", False):
        return None, {"available": False, "reason": "disabled_pending_marker_photo"}
    points = plane.get("points", []) if plane else []
    if len(points) < 4:
        return None, {"available": False, "reason": "fewer_than_four_ground_control_points"}

    image = transform_pts([p["pixel"] for p in points], M, sx, sy)
    world = [p["world_ft"] for p in points]
    H, _ = cv2.findHomography(
        np.asarray(image, dtype=np.float64),
        np.asarray(world, dtype=np.float64),
        method=0,
    )
    if H is None or not np.isfinite(H).all():
        return None, {"available": False, "reason": "homography_solution_failed"}

    projected = cv2.perspectiveTransform(
        np.asarray(image, dtype=np.float64).reshape(-1, 1, 2), H
    ).reshape(-1, 2)
    errors = np.linalg.norm(projected - np.asarray(world), axis=1)
    info = {
        "available": True,
        "quality": plane.get("quality", "unknown"),
        "quality_note": plane.get("quality_note"),
        "control_points": len(points),
        "reprojection_rmse_ft": round(float(np.sqrt(np.mean(errors ** 2))), 4),
        "points": [
            {
                "name": p["name"],
                "source": p.get("source"),
                "world_ft": p["world_ft"],
            }
            for p in points
        ],
    }
    return H, info


def line_intersection(a, b):
    """Intersection of two finite-point-defined infinite lines."""
    p1 = np.array([a[0][0], a[0][1], 1.0], dtype=np.float64)
    p2 = np.array([a[1][0], a[1][1], 1.0], dtype=np.float64)
    q1 = np.array([b[0][0], b[0][1], 1.0], dtype=np.float64)
    q2 = np.array([b[1][0], b[1][1], 1.0], dtype=np.float64)
    hit = np.cross(np.cross(p1, p2), np.cross(q1, q2))
    if abs(hit[2]) < 1e-9:
        return None
    return hit[:2] / hit[2]


def projective_track_coordinates(track: list[dict], gate_a, gate_b, road_vp, baseline_ft: float):
    """Map a vehicle track to feet along the road using a cross-ratio.

    The fitted trajectory intersects the two mailbox gates at known world
    coordinates 0 and baseline_ft. Its third reference is the road vanishing
    point, whose world coordinate is infinity. Those three references uniquely
    map every point on the trajectory from image position to road distance.
    """
    image = np.asarray([p["pt"] for p in track], dtype=np.float64)
    if len(image) < 6:
        return None, "projective_track_too_short"

    fit = cv2.fitLine(image.astype(np.float32), cv2.DIST_L2, 0, 0.01, 0.01).reshape(-1)
    direction = np.asarray([float(fit[0]), float(fit[1])], dtype=np.float64)
    origin = np.asarray([float(fit[2]), float(fit[3])], dtype=np.float64)
    track_line = [origin - direction * 10000.0, origin + direction * 10000.0]

    pa = line_intersection(track_line, gate_a)
    pb = line_intersection(track_line, gate_b)
    if pa is None or pb is None:
        return None, "projective_gate_intersection_failed"

    # Scalar image coordinate along the fitted trajectory. Projecting the
    # calibrated VP onto that trajectory tolerates a few pixels of line-fit and
    # calibration error while preserving the correct projective coordinate.
    scalar = lambda p: float(np.dot(np.asarray(p, dtype=np.float64) - origin, direction))
    sa, sb, sv = scalar(pa), scalar(pb), scalar(road_vp)
    if abs(sb - sa) < 1e-6:
        return None, "projective_gate_intersection_failed"

    scale = baseline_ft * (sv - sb) / (sb - sa)
    result = []
    for p in track:
        sp = scalar(p["pt"])
        denom = sv - sp
        if abs(denom) < 1e-6:
            continue
        x = scale * (sp - sa) / denom
        if np.isfinite(x) and abs(x) < 1000.0:
            result.append({"t": float(p["t"]), "x": float(x)})
    return result, None


def cross_ratio_track_speed(track: list[dict], gate_a, gate_b, road_vp,
                            baseline_ft: float, calibration_quality: str):
    projected, failure = projective_track_coordinates(
        track, gate_a, gate_b, road_vp, baseline_ft
    )
    if projected is None:
        return None, failure

    t = np.asarray([p["t"] for p in projected], dtype=np.float64)
    x = np.asarray([p["x"] for p in projected], dtype=np.float64)
    if float(t[-1] - t[0]) < 0.3:
        return None, "projective_track_too_short"
    fit = robust_line_fit(t, x)
    if fit is None:
        return None, "projective_fit_failed"
    velocity, _offset, mask, rmse, r2 = fit
    used_t = t[mask]
    duration = float(used_t[-1] - used_t[0])
    distance_ft = abs(velocity) * duration
    mph = abs(velocity) * FT_S_TO_MPH

    if distance_ft < 5.0:
        return None, "projective_distance_too_short"
    if not (1.0 <= mph <= 120.0):
        return None, "projective_speed_implausible"
    if r2 < 0.65:
        return None, "projective_fit_unstable"

    if calibration_quality != "measured":
        confidence = "provisional"
    elif r2 >= 0.95 and rmse <= 1.0 and int(mask.sum()) >= 12:
        confidence = "high"
    elif r2 >= 0.85 and rmse <= 2.0:
        confidence = "medium"
    else:
        confidence = "low"

    speed = {
        "ft_per_s": round(abs(velocity), 2),
        "mph": round(mph, 1),
        "kph": round(abs(velocity) * FT_S_TO_KPH, 1),
        "method": "projective_track_fit",
        "distance_ft": round(distance_ft, 2),
        "duration_s": round(duration, 4),
        "frames_used": int(mask.sum()),
        "frames_rejected": int(len(t) - mask.sum()),
        "fit_rmse_ft": round(rmse, 3),
        "fit_r_squared": round(r2, 4),
        "calibration_quality": calibration_quality,
        "confidence": confidence,
    }
    return (speed, "right" if velocity > 0 else "left"), None


def map_track_to_ground(track: list[dict], H: np.ndarray) -> list[dict]:
    image = np.asarray([p["pt"] for p in track], dtype=np.float64).reshape(-1, 1, 2)
    world = cv2.perspectiveTransform(image, H).reshape(-1, 2)
    result = []
    for p, xy in zip(track, world):
        if np.isfinite(xy).all() and -100.0 <= xy[1] <= 100.0:
            result.append({"t": float(p["t"]), "x": float(xy[0]), "y": float(xy[1])})
    return result


def robust_line_fit(t: np.ndarray, values: np.ndarray):
    """Iteratively reject tracker jumps and fit value = slope*t + intercept."""
    mask = np.ones(len(t), dtype=bool)
    for _ in range(4):
        if int(mask.sum()) < 5:
            return None
        slope, intercept = np.polyfit(t[mask], values[mask], 1)
        residual = values - (slope * t + intercept)
        med = float(np.median(residual[mask]))
        mad = float(np.median(np.abs(residual[mask] - med)))
        limit = max(0.75, 3.5 * 1.4826 * mad)
        new_mask = np.abs(residual - med) <= limit
        if np.array_equal(mask, new_mask):
            break
        mask = new_mask

    slope, intercept = np.polyfit(t[mask], values[mask], 1)
    fitted = slope * t[mask] + intercept
    residual = values[mask] - fitted
    rmse = float(np.sqrt(np.mean(residual ** 2)))
    total = float(np.sum((values[mask] - np.mean(values[mask])) ** 2))
    r2 = 1.0 - float(np.sum(residual ** 2)) / total if total > 1e-9 else 0.0
    return float(slope), float(intercept), mask, rmse, r2


def projective_track_speed(track: list[dict], H: np.ndarray, calibration_quality: str):
    """Measure speed from every available track point after mapping it to feet."""
    ground = map_track_to_ground(track, H)
    if len(ground) < 6:
        return None, "projective_track_too_short"

    t = np.asarray([p["t"] for p in ground], dtype=np.float64)
    x = np.asarray([p["x"] for p in ground], dtype=np.float64)
    y = np.asarray([p["y"] for p in ground], dtype=np.float64)
    duration = float(t[-1] - t[0])
    if duration < 0.3:
        return None, "projective_track_too_short"

    xfit = robust_line_fit(t, x)
    if xfit is None:
        return None, "projective_fit_failed"
    vx, _x0, mask, x_rmse, x_r2 = xfit

    # Report lateral stability as an audit metric. We do not include lateral
    # movement in road speed: X is explicitly the direction along the street.
    yfit = robust_line_fit(t[mask], y[mask])
    vy = yfit[0] if yfit else 0.0
    y_rmse = yfit[3] if yfit else 0.0

    used_t = t[mask]
    distance_ft = abs(vx) * float(used_t[-1] - used_t[0])
    mph = abs(vx) * FT_S_TO_MPH
    if distance_ft < 5.0:
        return None, "projective_distance_too_short"
    if not (1.0 <= mph <= 120.0):
        return None, "projective_speed_implausible"
    if x_r2 < 0.65:
        return None, "projective_fit_unstable"

    if calibration_quality != "measured":
        confidence = "provisional"
    elif x_r2 >= 0.95 and x_rmse <= 1.0 and int(mask.sum()) >= 12:
        confidence = "high"
    elif x_r2 >= 0.85 and x_rmse <= 2.0:
        confidence = "medium"
    else:
        confidence = "low"

    speed = {
        "ft_per_s": round(abs(vx), 2),
        "mph": round(mph, 1),
        "kph": round(abs(vx) * FT_S_TO_KPH, 1),
        "method": "projective_track_fit",
        "distance_ft": round(distance_ft, 2),
        "duration_s": round(float(used_t[-1] - used_t[0]), 4),
        "frames_used": int(mask.sum()),
        "frames_rejected": int(len(t) - mask.sum()),
        "fit_rmse_ft": round(x_rmse, 3),
        "fit_r_squared": round(x_r2, 4),
        "lateral_velocity_ft_s": round(float(vy), 3),
        "lateral_rmse_ft": round(float(y_rmse), 3),
        "calibration_quality": calibration_quality,
        "confidence": confidence,
    }
    direction = "right" if vx > 0 else "left"
    return (speed, direction), None


# --------------------------------------------------------------------------
# Colour
# --------------------------------------------------------------------------

def color_codes(bgr: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    h = hsv[..., 0].astype(np.int16).ravel()
    s = hsv[..., 1].astype(np.int16).ravel()
    v = hsv[..., 2].astype(np.int16).ravel()
    codes = np.select(
        [
            v < 55,                                    # black
            (s < 45) & (v >= 190),                     # white
            (s < 45) & (v >= 120),                     # silver
            (s < 45),                                  # gray
            (h >= 8) & (h < 33) & (v < 130),           # brown / tan
            (h < 8) | (h >= 172),                      # red
            (h >= 8) & (h < 20),                       # orange
            (h >= 20) & (h < 33),                      # yellow
            (h >= 33) & (h < 78),                      # green
            (h >= 78) & (h < 131),                     # blue
            (h >= 131) & (h < 155),                    # purple
            (h >= 155) & (h < 172),                    # pink
        ],
        [0, 1, 2, 3, 11, 4, 5, 6, 7, 8, 9, 10],
        default=3,
    )
    return codes, bgr.reshape(-1, 3)


def crop_body(frame: np.ndarray, box) -> np.ndarray | None:
    """Central patch of the bbox -- skips roof edge, windows, wheels, ground shadow."""
    x1, y1, x2, y2 = box
    w, h = x2 - x1, y2 - y1
    if w < 12 or h < 12:
        return None
    cx1 = int(round(x1 + 0.20 * w)); cx2 = int(round(x2 - 0.20 * w))
    cy1 = int(round(y1 + 0.30 * h)); cy2 = int(round(y2 - 0.25 * h))
    H, W = frame.shape[:2]
    cx1 = max(0, min(cx1, W - 1)); cx2 = max(cx1 + 1, min(cx2, W))
    cy1 = max(0, min(cy1, H - 1)); cy2 = max(cy1 + 1, min(cy2, H))
    patch = frame[cy1:cy2, cx1:cx2]
    if patch.size == 0:
        return None
    return cv2.resize(patch, (48, 48), interpolation=cv2.INTER_AREA)


def summarise_color(samples: list[np.ndarray]) -> dict | None:
    if not samples:
        return None
    all_codes, all_px = [], []
    for patch in samples:
        c, px = color_codes(patch)
        all_codes.append(c)
        all_px.append(px)
    codes = np.concatenate(all_codes)
    px = np.concatenate(all_px)
    if codes.size == 0:
        return None
    counts = np.bincount(codes, minlength=len(COLOR_NAMES))
    win = int(np.argmax(counts))
    share = float(counts[win]) / float(codes.size)
    sel = px[codes == win]
    bgr = np.median(sel, axis=0) if sel.size else np.zeros(3)
    return {
        "name": COLOR_NAMES[win],
        "rgb": [int(bgr[2]), int(bgr[1]), int(bgr[0])],
        "confidence": round(share, 3),
    }


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

def draw_overlay(img: np.ndarray, gates: dict, landmarks: dict, road: list, thickness: int = 3):
    out = img.copy()
    if road:
        cv2.polylines(out, [np.array(road, np.int32)], True, (0, 200, 255), thickness)
    for key, color in (("a", (0, 255, 0)), ("b", (255, 128, 0))):
        g = gates[key]
        p1 = tuple(int(v) for v in g["line"][0])
        p2 = tuple(int(v) for v in g["line"][1])
        cv2.line(out, p1, p2, color, thickness + 1)
        cv2.putText(out, f"gate {key.upper()}: {g['name']}", (p1[0] + 8, p1[1] + 26),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2, cv2.LINE_AA)
    for name, pt in landmarks.items():
        p = (int(pt[0]), int(pt[1]))
        cv2.drawMarker(out, p, (0, 0, 255), cv2.MARKER_CROSS, 28, thickness)
        cv2.putText(out, name, (p[0] + 10, p[1] - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2, cv2.LINE_AA)
    return out


# --------------------------------------------------------------------------
# Snapshots ("evidence" crops)
# --------------------------------------------------------------------------

def snapshot_score(box, conf: float, W: int, H: int) -> float:
    """Prefer big, confident, fully-in-frame detections.

    Bigger box == closer to the camera == more readable detail. Boxes clipped by
    the frame edge are heavily penalised: a half-a-car crop is useless as evidence.
    """
    x1, y1, x2, y2 = box
    area = max(0.0, x2 - x1) * max(0.0, y2 - y1)
    pad = 4.0
    clipped = x1 <= pad or y1 <= pad or x2 >= W - pad or y2 >= H - pad
    score = area * (0.5 + 0.5 * float(conf))
    return score * (0.2 if clipped else 1.0)


def expand_box(box, margin: float, W: int, H: int) -> tuple[int, int, int, int]:
    x1, y1, x2, y2 = box
    mx, my = (x2 - x1) * margin, (y2 - y1) * margin
    return (
        int(max(0, round(x1 - mx))),
        int(max(0, round(y1 - my))),
        int(min(W, round(x2 + mx))),
        int(min(H, round(y2 + my))),
    )


def caption_snapshot(img: np.ndarray, lines: list[str]) -> np.ndarray:
    """Append a caption bar *below* the crop.

    Deliberately extends the canvas rather than overlaying, so the caption can
    never cover part of the vehicle -- which matters when the crop is small.
    """
    h, w = img.shape[:2]
    scale = max(0.55, w / 900.0)
    thick = max(1, int(round(2 * scale)))
    line_h = int(round(30 * scale))
    bar = line_h * len(lines) + int(round(20 * scale))

    out = np.zeros((h + bar, w, 3), dtype=np.uint8)
    out[:h] = img

    y = h + line_h
    for ln in lines:
        cv2.putText(out, ln, (int(12 * scale), y), cv2.FONT_HERSHEY_SIMPLEX,
                    0.68 * scale, (255, 255, 255), thick, cv2.LINE_AA)
        y += line_h
    return out


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", str(text).lower()).strip("-") or "object"


def write_snapshot(dest_dir: Path, video: Path, best: dict, obj: dict,
                   src_meta: dict, plain: bool = False) -> dict:
    """Write the evidence crop for one object and describe it for the JSON."""
    crop = best["crop"]

    captured_at = None
    if src_meta.get("recorded_at"):
        try:
            captured_at = (
                dt.datetime.fromisoformat(src_meta["recorded_at"])
                + dt.timedelta(seconds=best["t"])
            ).isoformat()
        except ValueError:
            captured_at = None

    if not plain:
        headline = obj["description"]
        if obj.get("direction"):
            headline += f"  -  heading {obj['direction']}"
        lines = [headline]
        if obj.get("speed"):
            s = obj["speed"]
            lines.append(
                f"{s['mph']:.1f} mph ({s['kph']:.1f} km/h) "
                f"measured over {s['distance_ft']} ft  [{s['confidence']} confidence]"
            )
        else:
            lines.append("speed not measured")
        lines.append(f"{captured_at or video.name}   (t+{best['t']:.2f}s)")
        crop = caption_snapshot(crop, lines)

    if obj.get("speed"):
        speed_tag = f"{obj['speed']['mph']:.0f}mph"
    else:
        speed_tag = "nospeed"
    fname = (
        f"{video.stem}_track{obj['track_id']:02d}"
        f"_{slugify(obj['description'])}_{speed_tag}.jpg"
    )
    path = dest_dir / fname
    cv2.imwrite(str(path), crop, [int(cv2.IMWRITE_JPEG_QUALITY), 92])

    h, w = crop.shape[:2]
    return {
        "path": str(path.resolve()),
        "filename": fname,
        "width": int(w),
        "height": int(h),
        "source_frame": int(best["frame"]),
        "source_time_s": round(float(best["t"]), 3),
        "captured_at": captured_at,
        "captioned": not plain,
    }


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="analyze-security-camera",
        description="Detect vehicles/people in a security-camera clip and measure their speed.",
    )
    p.add_argument("video", type=Path, nargs="?", help="Video file to analyse.")
    p.add_argument("-o", "--output", type=Path, help="Write output here (default: stdout).")
    p.add_argument("--model", required=True, help="Path to YOLO .pt weights.")
    p.add_argument("--calibration", required=True, type=Path, help="Calibration JSON.")
    p.add_argument("--reference", required=True, type=Path, help="Reference frame for alignment.")
    p.add_argument("--baseline-ft", type=float, help="Override gate separation in feet.")
    p.add_argument("--conf", type=float, default=0.30, help="Detection confidence (default 0.30).")
    p.add_argument("--imgsz", type=int, default=1280, help="Inference size (default 1280).")
    p.add_argument("--device", default=None, help="cuda index or 'cpu' (default: auto).")
    p.add_argument("--no-align", action="store_true", help="Skip drift compensation.")
    p.add_argument("--include-track", action="store_true", help="Include per-frame track points.")
    p.add_argument("--annotate", type=Path, help="Also write an annotated debug video here.")

    snap = p.add_argument_group("snapshots")
    snap.add_argument("--snapshots", type=Path, metavar="DIR",
                      help="Save a focused crop of each qualifying object into DIR.")
    snap.add_argument("--snapshot-min-mph", type=float, default=None, metavar="MPH",
                      help="Only snapshot objects measured at or above this speed "
                           "(e.g. 20 to capture speeders).")
    snap.add_argument("--snapshot-kinds", default="vehicle", metavar="LIST",
                      help="Comma-separated kinds to snapshot: vehicle,cyclist,pedestrian "
                           "or 'all' (default: vehicle).")
    snap.add_argument("--snapshot-all", action="store_true",
                      help="Also snapshot objects with no measured speed.")
    snap.add_argument("--snapshot-margin", type=float, default=0.25, metavar="FRAC",
                      help="Context padding around the object, as a fraction of its "
                           "box size (default 0.25).")
    snap.add_argument("--snapshot-plain", action="store_true",
                      help="Do not burn the caption bar into the snapshot.")
    p.add_argument("--calibrate", action="store_true",
                   help="Render gates over a frame to --output and exit (no detection).")
    p.add_argument("--pretty", action="store_true", help="Indent the JSON output.")
    return p


def main() -> int:
    args = build_parser().parse_args()
    calib = load_calibration(args.calibration)

    ref_w, ref_h = calib["reference_size"]
    baseline_ft = args.baseline_ft if args.baseline_ft else float(calib["baseline_ft"])

    ref_img = cv2.imread(str(args.reference))
    if ref_img is None:
        log(f"error: cannot read reference frame {args.reference}")
        return 2
    if (ref_img.shape[1], ref_img.shape[0]) != (ref_w, ref_h):
        ref_img = cv2.resize(ref_img, (ref_w, ref_h), interpolation=cv2.INTER_AREA)

    # ---- calibrate mode: no video required -------------------------------
    if args.calibrate and args.video is None:
        gates = {k: {"name": v["name"], "line": v["line"]} for k, v in calib["gates"].items()}
        out = draw_overlay(ref_img, gates, calib.get("landmarks", {}), calib.get("road_polygon", []))
        dest = args.output or Path("calibration-overlay.jpg")
        cv2.imwrite(str(dest), out)
        log(f"wrote {dest}")
        return 0

    if args.video is None:
        log("error: a video path is required")
        return 2
    if not args.video.exists():
        log(f"error: no such file: {args.video}")
        return 2

    cap = cv2.VideoCapture(str(args.video))
    if not cap.isOpened():
        log(f"error: cannot open video {args.video}")
        return 2
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = float(cap.get(cv2.CAP_PROP_FPS)) or 15.0
    n_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    cap.release()
    if width == 0 or height == 0:
        log("error: could not read video dimensions")
        return 2

    sx, sy = width / float(ref_w), height / float(ref_h)

    # ---- drift compensation ---------------------------------------------
    M = np.array([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0]])
    align_info = {"applied": False, "method": "disabled"}
    if not args.no_align:
        bg = median_background(args.video, (ref_w, ref_h))
        if bg is not None:
            M, align_info = estimate_alignment(ref_img, bg)
        else:
            align_info = {"applied": False, "method": "orb+ransac_affine", "reason": "no_frames"}

    gates = {}
    for key, g in calib["gates"].items():
        gates[key] = {"name": g["name"], "line": transform_pts(g["line"], M, sx, sy)}
    road_poly = transform_pts(calib["road_polygon"], M, sx, sy) if calib.get("road_polygon") else []
    ground_H, ground_info = build_ground_homography(calib, M, sx, sy)
    road_vp = None
    if calib.get("road_vanishing_point") is not None:
        road_vp = transform_pts([calib["road_vanishing_point"]], M, sx, sy)[0]
    projection_info = {
        "available": road_vp is not None,
        "road_vanishing_point_quality": calib.get("road_vanishing_point_quality", "unknown"),
        "road_vanishing_point_note": calib.get("road_vanishing_point_note"),
    }

    # ---- calibrate mode over a real clip ---------------------------------
    if args.calibrate:
        # Rendered at reference resolution on purpose: a 9-frame median of 4K
        # frames would allocate gigabytes for no visual benefit.
        bg = median_background(args.video, (ref_w, ref_h))
        base = bg if bg is not None else ref_img.copy()
        ref_gates = {
            k: {"name": g["name"], "line": transform_pts(g["line"], M, 1.0, 1.0)}
            for k, g in calib["gates"].items()
        }
        ref_road = transform_pts(calib["road_polygon"], M, 1.0, 1.0) if calib.get("road_polygon") else []
        ref_lm = {k: transform_pts([v], M, 1.0, 1.0)[0] for k, v in calib.get("landmarks", {}).items()}
        for p in calib.get("ground_plane", {}).get("points", []):
            label = f"GCP {p['name']} ({p['world_ft'][0]:.1f},{p['world_ft'][1]:.1f})ft"
            ref_lm[label] = transform_pts([p["pixel"]], M, 1.0, 1.0)[0]
        out = draw_overlay(base, ref_gates, ref_lm, ref_road, thickness=3)
        dest = args.output or Path("calibration-overlay.jpg")
        cv2.imwrite(str(dest), out)
        log(f"wrote {dest} (alignment: {align_info})")
        return 0

    # ---- detection + tracking -------------------------------------------
    os.environ.setdefault("YOLO_VERBOSE", "false")
    from ultralytics import YOLO  # imported late: keeps --calibrate fast

    device = args.device
    if device is None:
        try:
            import torch
            device = "0" if torch.cuda.is_available() else "cpu"
        except Exception:
            device = "cpu"

    model = YOLO(args.model)
    tracks: dict[int, dict] = {}
    max_color_samples = 8

    want_snaps = args.snapshots is not None
    snap_kinds = {k.strip() for k in args.snapshot_kinds.split(",") if k.strip()}
    if "all" in snap_kinds:
        snap_kinds = {"vehicle", "cyclist", "pedestrian", "object"}
    if want_snaps:
        args.snapshots.mkdir(parents=True, exist_ok=True)

    writer = None
    if args.annotate:
        ow = 1280
        oh = int(round(height * ow / width))
        writer = cv2.VideoWriter(str(args.annotate), cv2.VideoWriter_fourcc(*"mp4v"), fps, (ow, oh))

    stream = model.track(
        source=str(args.video),
        stream=True,
        tracker="bytetrack.yaml",
        classes=sorted(CLASS_MAP.keys()),
        conf=args.conf,
        imgsz=args.imgsz,
        device=device,
        verbose=False,
    )

    for fi, res in enumerate(stream):
        t = fi / fps
        boxes = res.boxes
        frame = res.orig_img
        if boxes is not None and boxes.id is not None:
            ids = boxes.id.int().cpu().tolist()
            xyxy = boxes.xyxy.cpu().numpy()
            confs = boxes.conf.cpu().numpy()
            clss = boxes.cls.int().cpu().tolist()
            for tid, box, cf, cl in zip(ids, xyxy, confs, clss):
                label = CLASS_MAP.get(int(cl))
                if label is None:
                    continue
                x1, y1, x2, y2 = [float(v) for v in box]
                ground = ((x1 + x2) / 2.0, y2)  # ground contact point
                tr = tracks.setdefault(int(tid), {
                    "label_votes": {}, "conf_sum": 0.0, "n": 0,
                    "points": [], "color_samples": [], "best": None,
                })
                tr["label_votes"][label] = tr["label_votes"].get(label, 0) + 1
                tr["conf_sum"] += float(cf)
                tr["n"] += 1
                tr["points"].append({"t": t, "frame": fi, "pt": ground,
                                     "box": [x1, y1, x2, y2], "conf": float(cf)})
                if len(tr["color_samples"]) < max_color_samples and frame is not None:
                    patch = crop_body(frame, (x1, y1, x2, y2))
                    if patch is not None:
                        tr["color_samples"].append(patch)

                # Keep the single best-looking crop per track. We cannot know yet
                # whether this object will qualify for a snapshot (its speed is
                # only known once the track ends), so we hold on to the crop and
                # decide later. One modest crop per track, not per frame.
                if want_snaps and frame is not None:
                    score = snapshot_score((x1, y1, x2, y2), cf, width, height)
                    if tr["best"] is None or score > tr["best"]["score"]:
                        ex1, ey1, ex2, ey2 = expand_box(
                            (x1, y1, x2, y2), args.snapshot_margin, width, height)
                        if ex2 > ex1 and ey2 > ey1:
                            tr["best"] = {
                                "score": float(score),
                                "t": float(t),
                                "frame": int(fi),
                                "crop": frame[ey1:ey2, ex1:ex2].copy(),
                                "box": [x1, y1, x2, y2],
                            }

        if writer is not None and frame is not None:
            vis = res.plot()
            for key, color in (("a", (0, 255, 0)), ("b", (255, 128, 0))):
                p1 = tuple(int(v) for v in gates[key]["line"][0])
                p2 = tuple(int(v) for v in gates[key]["line"][1])
                cv2.line(vis, p1, p2, color, 4)
            ow = 1280
            oh = int(round(height * ow / width))
            writer.write(cv2.resize(vis, (ow, oh)))

    if writer is not None:
        writer.release()

    # ---- per-track analysis ---------------------------------------------
    src_meta = parse_source_meta(args.video)
    min_frames = int(calib.get("detection", {}).get("min_track_frames", 3))
    stationary_px = float(calib.get("detection", {}).get("stationary_px", 40.0)) * max(sx, sy)

    objects = []
    for tid, tr in sorted(tracks.items()):
        pts = tr["points"]
        if len(pts) < min_frames:
            continue

        label = max(tr["label_votes"].items(), key=lambda kv: kv[1])[0]
        kind = KIND_MAP.get(label, "object")
        color = summarise_color(tr["color_samples"])

        first, last = pts[0], pts[-1]
        dx = last["pt"][0] - first["pt"][0]
        dy = last["pt"][1] - first["pt"][1]
        displacement = float(np.hypot(dx, dy))
        moving = displacement >= stationary_px

        ca = find_crossing(pts, gates["a"]["line"])
        cb = find_crossing(pts, gates["b"]["line"])

        speed = None
        reason = None
        gate_failure = None
        direction = "right" if dx > 0 else ("left" if dx < 0 else None)

        if not moving:
            reason = "stationary"
        elif ca is None and cb is None:
            gate_failure = "crossed_neither_gate"
        elif ca is None:
            gate_failure = "did_not_cross_gate_a"
        elif cb is None:
            gate_failure = "did_not_cross_gate_b"
        else:
            delta = cb["t"] - ca["t"]
            direction = "right" if delta > 0 else "left"
            adt = abs(delta)
            if adt < 1e-6:
                reason = "degenerate_gate_times"
            else:
                ft_s = baseline_ft / adt
                gap_frames = adt * fps
                if gap_frames >= 6:
                    conf = "high"
                elif gap_frames >= 3:
                    conf = "medium"
                else:
                    conf = "low"
                speed = {
                    "ft_per_s": round(ft_s, 2),
                    "mph": round(ft_s * FT_S_TO_MPH, 1),
                    "kph": round(ft_s * FT_S_TO_KPH, 1),
                    "method": "two_gate_time_of_flight",
                    "distance_ft": baseline_ft,
                    "gate_a_time_s": round(ca["t"], 4),
                    "gate_b_time_s": round(cb["t"], 4),
                    "delta_t_s": round(adt, 4),
                    "frames_between_gates": round(gap_frames, 2),
                    "confidence": conf,
                }

        # Motion-triggered clips often begin after the vehicle has already
        # crossed one mailbox. In that case use every track point, mapped onto
        # the measured road plane, instead of returning a null speed.
        if moving and speed is None and road_vp is not None:
            projective, projective_failure = cross_ratio_track_speed(
                pts,
                gates["a"]["line"],
                gates["b"]["line"],
                road_vp,
                baseline_ft,
                calib.get("road_vanishing_point_quality", "unknown"),
            )
            if projective is not None:
                speed, direction = projective
                speed["gate_fallback_reason"] = gate_failure
                reason = None
            else:
                reason = projective_failure
        elif moving and speed is None and ground_H is not None:
            projective, projective_failure = projective_track_speed(
                pts, ground_H, ground_info.get("quality", "unknown")
            )
            if projective is not None:
                speed, direction = projective
                speed["gate_fallback_reason"] = gate_failure
                reason = None
            else:
                reason = projective_failure
        elif moving and speed is None:
            reason = gate_failure or "ground_plane_unavailable"

        if kind == "vehicle" and color:
            description = f"{color['name']} {label}"
        elif label == "bicycle":
            description = "cyclist"
        else:
            description = label

        obj = {
            "track_id": int(tid),
            "label": label,
            "kind": kind,
            "description": description,
            "detection_confidence": round(tr["conf_sum"] / tr["n"], 3),
            "color": color,
            "direction": direction,
            "moving": bool(moving),
            "on_road": point_in_poly(last["pt"], road_poly) or point_in_poly(first["pt"], road_poly),
            "first_seen_s": round(first["t"], 3),
            "last_seen_s": round(last["t"], 3),
            "frames_tracked": len(pts),
            "displacement_px": round(displacement, 1),
            "bbox_first": [round(v, 1) for v in first["box"]],
            "bbox_last": [round(v, 1) for v in last["box"]],
            "speed": speed,
            "speed_unavailable_reason": reason,
        }
        # Evidence crop. Speed is only known now, which is why the crop was held
        # in memory rather than written during the tracking pass.
        obj["snapshot"] = None
        if want_snaps and tr["best"] is not None and kind in snap_kinds:
            if speed is not None:
                qualifies = (args.snapshot_min_mph is None
                             or speed["mph"] >= args.snapshot_min_mph)
            else:
                qualifies = args.snapshot_all
            if qualifies:
                obj["snapshot"] = write_snapshot(
                    args.snapshots, args.video, tr["best"], obj,
                    src_meta, plain=args.snapshot_plain,
                )

        if args.include_track:
            obj["track"] = [
                {"t": round(p["t"], 4), "frame": p["frame"],
                 "x": round(p["pt"][0], 1), "y": round(p["pt"][1], 1)}
                for p in pts
            ]
        objects.append(obj)

    by_class: dict[str, int] = {}
    for o in objects:
        by_class[o["label"]] = by_class.get(o["label"], 0) + 1

    doc = {
        "schema_version": SCHEMA_VERSION,
        "source": {
            "path": str(args.video.resolve()),
            "filename": args.video.name,
            "camera": src_meta["camera"] or calib.get("camera"),
            "recorded_at": src_meta["recorded_at"],
            "duration_s": round(n_frames / fps, 3) if n_frames else None,
            "fps": round(fps, 4),
            "width": width,
            "height": height,
            "frame_count": n_frames or None,
        },
        "analysis": {
            "tool": "analyze-security-camera",
            "tool_version": TOOL_VERSION,
            "analyzed_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "model": Path(args.model).name,
            "imgsz": args.imgsz,
            "conf": args.conf,
            "device": str(device),
            "baseline_ft": baseline_ft,
            "alignment": align_info,
            "road_projection": projection_info,
            "ground_plane": ground_info,
        },
        "counts": {
            "total": len(objects),
            "by_class": by_class,
            "with_speed": sum(1 for o in objects if o["speed"]),
            "moving": sum(1 for o in objects if o["moving"]),
            "snapshots": sum(1 for o in objects if o.get("snapshot")),
        },
        "objects": objects,
    }

    text = json.dumps(doc, indent=2 if args.pretty else None)
    if args.output:
        args.output.write_text(text + "\n")
        log(f"wrote {args.output}")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
