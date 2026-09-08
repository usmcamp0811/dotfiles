# analyze-security-camera

Analyse a single security-camera clip and emit a JSON record describing every
**vehicle, cyclist and pedestrian** in it — what it looked like, which way it was
going, and **how fast it was travelling**.

Built for the `driveway` Reolink camera in the Campground homelab, whose clips
land in `/mnt/security-cameras/driveway/YYYY/MM/DD/`.

```bash
nix run .#analyze-security-camera -- /mnt/security-cameras/driveway/2026/09/05/Driveway_00_20260905080552.mp4
```

The JSON goes to stdout, so it pipes straight into a database loader. Everything
else (logs, progress) goes to stderr.

---

## How the speed is measured

This is the part worth understanding, because it is what makes the numbers
trustworthy.

The two mailboxes are **28.8 ft apart** (laser-measured, inside face to inside
face). A "gate" line is drawn through the base of each mailbox post. As an object
is tracked, the tool records the exact moment it crosses each gate and divides:

```
average_speed = 28.8 ft / (t_gate_b - t_gate_a)
```

**Only time is measured.** No pixels-per-foot scale is ever computed, so lens
perspective, foreshortening and the steep camera angle cannot bias the result.
This is the same principle as a police speed trap or a track timing gate.

Two refinements make it hold up in practice:

### 1. The gates are parallel *on the ground*, not in the image

Naively you would draw two vertical lines in the image. But two vertical image
lines do **not** correspond to two parallel lines on the road — they converge or
diverge, so the real distance between them changes depending on which lane the
car is in. A far-lane car would be timed over a different distance than 28.8 ft.

Instead both gates are aimed at a shared **cross-road vanishing point**
(`cross_road_vanishing_point` in `calibration.json`). That is the point where
lines perpendicular to the road converge in the image — obtained from the
driveway edges, which run perpendicular to the street. Gates drawn through that
point are genuinely parallel on the ground plane, so 28.8 ft holds in **either
lane**.

### 2. The camera drifts, so every clip is re-registered

The camera is not perfectly rigid. Comparing clips across days shows the frame
shifting by **~110 px at 4K** (measured between the 2026-08-31 and 2026-09-05
clips). Left uncorrected that is roughly a **5% speed error**, because the gates
end up over different patches of real road.

So before detection, each clip's **static background** (median of 9 frames, which
removes moving traffic) is feature-matched against the stored `reference.jpg`
using ORB + RANSAC. The resulting similarity transform is applied to the gate
coordinates. The transform is sanity-checked — scale must stay within ±10% and
translation under 400 px — and silently falls back to identity if matching fails,
which is reported in `analysis.alignment` so you can audit it.

Disable with `--no-align` if you ever need the raw fixed gates.

### Accuracy

At 15 fps a car at 30 mph crosses the 28.8 ft baseline in about 10 frames.
Crossings are interpolated to **sub-frame** precision, so the dominant error is
tracker jitter rather than frame quantisation. Each measurement carries a
`confidence` field derived from how many frames the object spent between gates:

| frames between gates | confidence | rough meaning          |
| -------------------- | ---------- | ---------------------- |
| ≥ 6                  | `high`     | ~±1 mph                |
| 3 – 6                | `medium`   | ~±3 mph                |
| < 3                  | `low`      | treat as indicative    |

Anything moving fast enough to land in `low` is going *very* quickly past the
house; consider that signal in itself.

---

## Output schema

Top level:

| field            | meaning                                                      |
| ---------------- | ------------------------------------------------------------ |
| `schema_version` | Bump this when the shape changes. Currently `1`.              |
| `source`         | Path, camera, `recorded_at` (parsed from filename), fps, size |
| `analysis`       | Model, device, baseline, and the alignment audit trail        |
| `counts`         | Quick roll-ups for cheap aggregate queries                    |
| `objects[]`      | One entry per tracked object                                  |

Each object:

```json
{
  "track_id": 3,
  "label": "car",
  "kind": "vehicle",
  "description": "red car",
  "detection_confidence": 0.91,
  "color": { "name": "red", "rgb": [178, 32, 40], "confidence": 0.78 },
  "direction": "right",
  "moving": true,
  "on_road": true,
  "first_seen_s": 1.2,
  "last_seen_s": 3.4,
  "frames_tracked": 33,
  "displacement_px": 2140.5,
  "bbox_first": [1201.4, 640.2, 1480.9, 812.0],
  "bbox_last": [3310.7, 900.1, 3720.2, 1140.6],
  "speed": {
    "ft_per_s": 40.2,
    "mph": 27.4,
    "kph": 44.1,
    "method": "two_gate_time_of_flight",
    "distance_ft": 28.8,
    "gate_a_time_s": 1.5333,
    "gate_b_time_s": 2.25,
    "delta_t_s": 0.7167,
    "frames_between_gates": 10.75,
    "confidence": "high"
  },
  "speed_unavailable_reason": null,
  "snapshot": null
}
```

Notes for the database:

- `speed` is `null` whenever the object did not cleanly traverse both gates.
  `speed_unavailable_reason` then tells you why — one of `stationary`,
  `crossed_neither_gate`, `did_not_cross_gate_a`, `did_not_cross_gate_b`,
  `degenerate_gate_times`. **Filter on `speed IS NOT NULL` for traffic stats**,
  and treat the rest as presence-only events.
- `kind` is the useful grouping column: `vehicle`, `cyclist`, `pedestrian`.
- `label` is the raw COCO class: `car`, `truck`, `bus`, `motorcycle`, `bicycle`,
  `person`. COCO's `truck` covers pickups and box trucks; `car` covers sedans and
  SUVs. Do not read more precision into it than that.
- `on_road` distinguishes street traffic from things on your driveway (a parked
  car, someone at the mailbox). Combined with `moving` it cheaply separates
  "traffic" from "activity".
- `direction` is `left` or `right` as seen on screen. For gate-crossers it is
  derived from gate ordering; otherwise from overall displacement.
- A cyclist typically produces **two** tracks — a `person` and a `bicycle`.
  De-duplicate downstream if that matters to you.

---

## Snapshots (speeding evidence)

Save a focused, captioned crop of every car over 20 mph:

```bash
nix run .#analyze-security-camera -- clip.mp4 \
  --snapshots ./evidence \
  --snapshot-min-mph 20
```

For each qualifying object the tool picks the **best** frame of that track —
largest bounding box (closest to the camera, so most detail), weighted by
detection confidence, and heavily penalising boxes clipped by the frame edge so
you never get half a car. It crops at **full sensor resolution** with 25% context
padding, and burns in a caption bar:

```
red car  -  heading right
31.4 mph (50.5 km/h) measured over 28.8 ft  [high confidence]
2026-09-05T08:05:54.930000   (t+2.41s)
```

The wall-clock time is the clip's start time (parsed from the filename) plus the
offset of the chosen frame, so the caption states when the vehicle was actually
there.

The written file is recorded back into the JSON under `objects[].snapshot`, so
your database row can link to the image.

Relevant flags:

| flag                  | default   | effect                                                    |
| --------------------- | --------- | --------------------------------------------------------- |
| `--snapshots DIR`     | off       | Enable snapshots, write into `DIR` (created if needed)     |
| `--snapshot-min-mph`  | none      | Only capture at or above this speed                        |
| `--snapshot-kinds`    | `vehicle` | `vehicle,cyclist,pedestrian` or `all`                      |
| `--snapshot-all`      | off       | Also capture objects with no measured speed                |
| `--snapshot-margin`   | `0.25`    | Context padding as a fraction of the box                   |
| `--snapshot-plain`    | off       | Skip the caption bar, save the bare crop                   |

---

## Calibration

Calibration lives in `calibration.json`, in the coordinate space of
`reference.jpg` (1920×1080). It is rescaled to whatever resolution the clip
actually is, so it keeps working if the camera profile changes.

**Always verify visually after changing anything:**

```bash
# gates drawn over a real clip's background, with drift correction applied
nix run .#analyze-security-camera -- clip.mp4 --calibrate -o overlay.jpg

# or over the stored reference frame
nix run .#analyze-security-camera -- --calibrate -o overlay.jpg
```

Check that:

1. Each green/orange gate passes through the **base of its mailbox post** (where
   the post meets the ground — not the mailbox itself, which is several feet up
   and would be wrong by parallax).
2. Each gate spans the **full width of the road**, so cars in either lane cross it.
3. The gates look like they are **perpendicular to the road** — as if painted
   across the tarmac. If they look skewed, adjust
   `cross_road_vanishing_point`.

Key fields:

| field                         | meaning                                                        |
| ----------------------------- | -------------------------------------------------------------- |
| `baseline_ft`                 | The 28.8 ft measurement. Override per-run with `--baseline-ft`. |
| `cross_road_vanishing_point`  | Where road-perpendicular lines converge. Controls gate skew.    |
| `gates.a` / `gates.b`         | The gate segments. `a` is the 507 mailbox, `b` the neighbour's. |
| `landmarks`                   | Mailbox post bases, drawn on the overlay for reference.         |
| `road_polygon`                | Drives the `on_road` flag.                                      |
| `detection.min_track_frames`  | Drop tracks shorter than this (noise suppression).              |
| `detection.stationary_px`     | Movement below this counts as parked.                           |

### Sanity-checking the speeds

The honest way to validate: drive past at a known speedometer reading and check
what the tool reports. Failing that, watch for a **systematic difference between
the two directions** — if left-bound and right-bound traffic show consistently
different average speeds, the gates are not truly parallel on the ground and
`cross_road_vanishing_point` needs adjusting. That asymmetry is the most
sensitive tell available without a ground-truth run.

---

## All options

```
analyze-security-camera [VIDEO] [options]

  -o, --output PATH        Write JSON (or the overlay image) here; default stdout
      --pretty             Indent the JSON
      --include-track      Embed per-frame track points (large; for debugging)

      --conf FLOAT         Detection confidence threshold (default 0.30)
      --imgsz INT          Inference resolution (default 1280)
      --device STR         'cpu' or a CUDA index (default: auto-detect)
      --model PATH         Override the pinned YOLO weights
      --baseline-ft FLOAT  Override the 28.8 ft gate separation

      --no-align           Skip camera-drift compensation
      --calibrate          Render the gate overlay and exit
      --annotate PATH      Write an annotated debug video
```

## Notes on the build

- Detection is **YOLO11m**, pinned by hash via `fetchurl`, so nothing is
  downloaded at runtime and results are reproducible.
- Tracking is **ByteTrack**, which handles the brief occlusion from the tree
  trunk and overhanging branches.
- PyTorch comes from the upstream `torch-bin` wheels (CUDA included, in the
  binary cache) rather than a local CUDA source build. The
  `python3.override { self = python; packageOverrides = ... }` idiom propagates
  that swap to every transitive consumer so only one `torch` lands in the env.
- On an RTX 4070 Ti SUPER a 10-second 4K clip takes a few seconds. It runs on CPU
  too, just far slower — fine for one-offs, painful for bulk backfill.

## Batch processing

```bash
find /mnt/security-cameras/driveway/2026/09 -name '*.mp4' -print0 |
  xargs -0 -I{} -P1 sh -c '
    out="/var/lib/traffic/$(basename "{}" .mp4).json"
    [ -f "$out" ] || nix run /config#analyze-security-camera -- "{}" -o "$out"
  '
```

Keep `-P1`: the GPU is the bottleneck, so parallel invocations mostly contend for
VRAM. The `[ -f "$out" ]` guard makes the whole thing resumable.
