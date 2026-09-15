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

A calibrated **pinhole camera model** gives a homography from image pixels to
feet on the road plane. Every track point is mapped through it and
distance-versus-time is fitted robustly, so the measurement uses the whole track
rather than two instants. The method reports `ground_plane_track_fit`.

### How the camera model was obtained

Not by eyeballing road edges — that was the previous approach and it was wrong
by a factor that made a moving car read 6.8 mph. Each piece comes from data:

| quantity | source | residual |
| -------- | ------ | -------- |
| horizon line | a person of known height standing at 8 road-surface stations in a calibration walk | 2.6 px |
| road vanishing point | 38 real vehicle tracks across 45 clips | — |
| cross-road direction, camera height | the only two fitted parameters, solved against four laser distances | 1.1% rms |
| focal length | follows from the two vanishing points being orthogonal ground directions | — |

The horizon trick is the load-bearing one. For a constant-height object standing
on a plane, `(y_feet − y_head)` is *linear* in `(x_feet, y_feet)`, so the horizon
falls straight out of least squares. It also yields the camera height as a
by-product — **11.8 ft**, a sane eave height, which is a free sanity check.

Two things that were quietly wrong before and are now enforced:

- Stations on the **elevated far lawn** are excluded. They are not on the road
  plane and including them tilted the fit (horizon residual 6.2 px → 2.6 px).
- The **driveway edges are not used** for the cross-road direction. The driveway
  slopes, so its edges do not lie in the road plane.

### Validation

Four laser-tape distances, reproduced by the model:

| measurement | laser | model | error |
| ----------- | ----- | ----- | ----- |
| driveway width | 16.92 ft | 16.60 ft | −1.9% |
| left corner → manhole | 20.07 ft | 20.14 ft | +0.4% |
| right corner → manhole | 30.57 ft | 30.46 ft | −0.4% |
| mailbox 507 → neighbour post | 28.80 ft | 29.05 ft | +0.9% |

Two free parameters were fitted against these four numbers, so this is close to
but not fully independent. Genuinely independent checks:

- The **24″×18″ yard sign** in the calibration walk reproduces to **−0.4% mean**.
- The **two-gate timing cross-check** (below) agrees to **+3.2% mean, 5.7% rms**.

### The two-gate cross-check

Time of flight between the two mailbox gates is still computed, now as an
*independent check* rather than the primary answer. It needs only two crossing
times and the surveyed baseline — it shares the tracker with the primary method
but none of its geometry — so agreement between them is real evidence. It
appears as `speed_cross_check`, including `agreement_pct`.

Over a 147-clip sample, the two methods agreed within ±10% on 89% of the
vehicles that crossed both gates.

### Frame-edge clipping

A bounding box touching the frame border is **truncated**, so its centre is no
longer the object's centre. As a vehicle leaves frame the box stops growing and
the derived ground point stalls — which reads as sudden braking.

Measured on a real clip: a car holding ~106 px/frame dropped to ~40 px/frame the
instant its box hit the right edge, dragging the reported speed from ~12 mph to
**6.8 mph**. Those points are now excluded from speed (kept for metadata), and
`speed.frames_edge_clipped_dropped` records how many were discarded. Tracks left
with too few clean frames report `too_few_unclipped_frames` rather than a wrong
number — about 10% of vehicle tracks.

### Frame rate

These Reolink files carry a bogus first presentation timestamp: frames 0 and 1
are 25 ms apart while every other gap is 66.6 ms. That drags `CAP_PROP_FPS` to
15.063 when the clip is really ~14.93. Speed scales linearly with frame rate, so
the rate is now taken from the **median gap between real timestamps**, reported
in `analysis.timing`.

### The camera drifts, so every clip is re-registered

The camera is not perfectly rigid; the frame shifts by ~110 px at 4K across
days. Before detection, each clip's **static background** (median of 9 frames,
which removes moving traffic) is feature-matched against the stored
`reference.jpg` using ORB + RANSAC, and the camera model is composed with the
resulting similarity transform. Sanity-checked — scale within ±10%, translation
under 400 px — and falls back to identity if matching fails, reported in
`analysis.alignment`.

Disable with `--no-align`.

### Known limitation

Right-bound traffic measures **+14.6% faster** than left-bound (medians 18.0 vs
15.7 mph over 94 on-road vehicles). The two directions occupy different lanes
(Y ≈ 6.7 ft vs 12.9 ft), so lane and direction are confounded in the available
data and this **cannot currently be separated** into "residual cross-road
calibration error" versus "traffic genuinely is faster one way".

Treat cross-direction comparisons with caution until resolved. See
*Closing the direction asymmetry* below.

---

## Output schema

Top level:

| field            | meaning                                                      |
| ---------------- | ------------------------------------------------------------ |
| `schema_version` | Bump this when the shape changes. Currently `2`.              |
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
    "ft_per_s": 24.2,
    "mph": 16.5,
    "kph": 26.5,
    "method": "ground_plane_track_fit",
    "distance_ft": 31.4,
    "duration_s": 1.2998,
    "frames_used": 20,
    "frames_rejected": 1,
    "frames_edge_clipped_dropped": 3,
    "fit_rmse_ft": 0.21,
    "fit_r_squared": 0.9971,
    "lateral_velocity_ft_s": 0.14,
    "lateral_rmse_ft": 0.19,
    "calibration_quality": "measured",
    "confidence": "high"
  },
  "speed_cross_check": {
    "method": "two_gate_time_of_flight",
    "ft_per_s": 24.9,
    "mph": 17.0,
    "distance_ft": 29.05,
    "delta_t_s": 1.1667,
    "frames_between_gates": 17.4,
    "confidence": "high",
    "agreement_pct": 3.0
  },
  "speed_unavailable_reason": null,
  "snapshot": null
}
```

Notes for the database:

- `speed.method` is `ground_plane_track_fit` for essentially all measurements.
  `two_gate_time_of_flight` appears in `speed` only in the rare case where the
  geometry fit failed but both gate crossings were clean.
- `speed_cross_check` is populated when the vehicle crossed both gates. Its
  `agreement_pct` is the single most useful health metric you can aggregate —
  if it drifts away from zero, the calibration has moved.
- `speed.frames_edge_clipped_dropped` counts frames discarded because the box
  touched the frame border. A large value means the vehicle was only briefly
  fully visible; treat the measurement as weaker than its `confidence` suggests.
- `speed` is `null` when there is not enough clean motion. The
  `speed_unavailable_reason` explains why — most commonly `stationary` (parked
  cars, ~38% of vehicle tracks) or `too_few_unclipped_frames` (~10%).
  **Filter on `speed IS NOT NULL` for traffic stats.**
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
16.5 mph (26.5 km/h) measured over 31.4 ft  [high confidence]
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

The overlay draws a **one-foot ground grid**. Check that:

1. The grid **lies flat on the asphalt** — lines should look painted on the road,
   not floating above or sinking into it.
2. The green cross-road lines look **perpendicular to the road**, and the orange
   along-road lines stay **parallel to the kerb** all the way across the frame.
3. Each gate passes through the **base of its mailbox post** (where the post
   meets the ground — not the mailbox itself, which is several feet up and would
   be wrong by parallax).

Key fields:

| field                         | meaning                                                        |
| ----------------------------- | -------------------------------------------------------------- |
| `camera_model.H_image_to_ground` | The homography. Everything else in that block documents how it was derived. |
| `camera_model.validation`     | Laser distances vs model. Regenerate if you retune anything.    |
| `camera_model.horizon`        | Fitted from the calibration walk. Both vanishing points must lie on it. |
| `road_vanishing_point`        | From 38 vehicle tracks. Sets the along-road direction.          |
| `cross_road_vanishing_point`  | Fitted. Sets lateral scale — the suspect for lane-dependent bias. |
| `baseline_ft`                 | 29.05 ft, gate to gate. Cross-check only. Override with `--baseline-ft`. |
| `survey`                      | Laser measurements kept for validation. **Not** used to build the model. |
| `gates.a` / `gates.b`         | Gate segments, regenerated from the model as true cross-road lines. |
| `road_polygon`                | Drives the `on_road` flag.                                      |
| `detection.stationary_px`     | Movement below this counts as parked.                           |

### Closing the direction asymmetry

The one known defect is the **+14.6% right-bound vs left-bound** difference. To
resolve it, in rough order of cost:

1. **Re-pick the survey pixels.** Two are demonstrably off: `street_manhole_center`
   sits on the right *edge* of the manhole rather than its centre, and
   `driveway_left_asphalt_corner` sits slightly into the grass. Both feed the
   validation residuals and one of them feeds the fitted parameters.
2. **Tune `cross_road_vanishing_point` against symmetry.** Dump tracks with
   `--include-track` over a few hundred clips, then scan the cross-road vanishing
   point for the value that minimises the left/right median difference *while*
   keeping the laser residuals near 1%. If a single value does both, the
   asymmetry was calibration; if nothing does, it is real traffic.
3. **A known-speed pass.** Drive past at a held speedometer reading, in *both*
   directions, and record the clip names. This is the only thing that settles it
   outright, and it would also let `camera_model.quality` be asserted rather than
   argued.

### A note on what was wrong before

The previous calibration was not merely imprecise. Its two vanishing points did
not lie on a common horizon (they were 171 px and 320 px off), which implied a
**135° lens** on a camera that is actually ~68°. The `ground_plane` homography it
shipped was built from four near-collinear control points and came out
**sign-flipped** — it placed the two mailboxes 26.6 ft apart *in the wrong order*.
It was disabled, correctly, and the cross-ratio fallback that ran instead
under-read a real car by roughly a factor of two.

If you ever see the mailbox separation come back negative from
`camera_model.H_image_to_ground`, that failure mode has returned.

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
      --baseline-ft FLOAT  Override the 29.05 ft gate separation (cross-check only)

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
