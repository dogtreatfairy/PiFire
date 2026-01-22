# PiFire AI Agent Skills & Safety Guide

This repository controls real pellet grill hardware. Any AI-assisted changes **must preserve safety and backwards compatibility** across:

- The Flask web UI (templates + static assets)
- The HTTP API (`/api/...`) consumed by the Web UI and external clients
- The Socket.IO API used by the mobile client(s)
- The inter-process Redis contract between `app.py` (web) and `control.py` (hardware controller)

If you’re using an AI agent to make changes, treat this document as **hard constraints**.

---

## 1) System Overview (Mental Model)

### Key processes

- `app.py`
  - Runs the Flask web server and registers blueprints.
  - Hosts the **HTTP API** under `/api`.
  - Hosts **Socket.IO** (Flask-SocketIO) used primarily by the mobile client.

- `control.py`
  - Runs the hardware/control loop.
  - Loads platform modules (GPIO/PWM/relays), probes, display, distance sensor.
  - Maintains grill temperature using controller modules (PID/fuzzy/ML/etc).
  - Communicates with `app.py` through Redis.

### Where the UI lives

- Global templates: `templates/`
- Blueprint templates (also part of the Web UI): `blueprints/*/templates/`
- Global static assets: `static/`
- Blueprint static assets: `blueprints/*/static/`

**Important:** The templates and JS are coupled via element IDs/classes and API route shapes. If you change HTML markup, verify the JS selectors still match.

---

## 2) Non-Negotiable Compatibility Rules

### 2.1 HTTP API must stay backwards compatible

Do **not** rename, remove, or change semantics of existing API endpoints.

PiFire’s HTTP API is intentionally “stringly-typed” and path-driven:

- Catch-all pattern: `/api/<action>/<arg0>/<arg1>/<arg2>/<arg3>` where `action` is typically one of:
  - `get`
  - `set`
  - `cmd`
  - `sys`

The request is ultimately handled by `common.common.process_command()`.

Additional hard constraints for AI-assisted work:

- **Do not change `app.py`.**
- **Do not add new API endpoints.** Changes must use the existing `/api/...` surface.
- Treat **all callers** as compatibility constraints, including code under `static/` and `blueprints/*/static/`.

Additionally, these legacy endpoints exist and must not be broken:

- `GET /api/settings` → `{"settings": ...}`
- `POST /api/settings` (JSON body) → returns keys including `settings` plus `result/message`
- `GET /api/control` → `{"control": ...}`
- `POST /api/control` (JSON body) → returns keys including `control` plus `result/message`
- `GET /api/current` → `{"current": ..., "notify_data": ..., "status": ...}`
- `GET /api/server` → `{"server_status": ...}`
- `GET /api/hopper` → `{"hopper_level": ..., "hopper_pellets": ...}`

Newer (but now public) endpoints also exist:

- `GET /api/wled_discover?timeout=<int>`
- `POST /api/wled_push_profiles`
- `POST /api/wled_test_profile`

**Rule:** do not add endpoints. Only extend UI using existing endpoints.

### 2.2 Preserve response shapes and key names

Front-end code expects stable key names.

Examples of stable patterns:

- `process_command()` returns:
  - `result` (string, often `OK`/`ERROR`)
  - `message` (human readable)
  - `data` (object)

- `GET /api/get/timer` returns data with keys:
  - `start`, `paused`, `end`, `shutdown`, `keep_warm`

- `GET /api/current` returns `status` with keys like:
  - `mode`, `display_mode`, `status`, `s_plus`, `units`, `name`, `ui_hash`, `probe_status`, `outpins`, etc.

**Rule:** Do not rename keys, change types, or remove keys.

If you must evolve a schema, only do so by adding new optional keys.

### 2.3 Socket.IO API must stay backwards compatible

The Socket.IO server is implemented in `blueprints/mobile/socket_io.py`.

**Do not rename or remove** these events without a migration plan:

Client → server:
- `connect` / `disconnect` (built-ins)
- `listen_app_data`
- `get_app_data`
- `post_app_data`

Server → client emits:
- `socket_event_data`
- `socket_pellet_data`
- `socket_dash_data`

**Rule:** event names and payload structure are part of the public API.

### 2.4 Redis contract must stay stable

`app.py` and `control.py` communicate through Redis (localhost). The following keys/queues are core integration points:

- `control:general` (canonical control state JSON)
- `control:write` (queue of partial updates to merge into `control:general`)
- `control:systemq` (queue: system command requests from web/app)
- `control:systemo` (queue: system command responses from control process)

Other critical data structures include (non-exhaustive):
- `settings` and settings-related Redis keys (read via `read_settings()` / `read_settings_redis()`)
- `errors`, warnings, current temps, history/metrics keys

**Rule:** Changing key names, serialization formats, or queue semantics is a breaking change.

---

## 3) Safety-Critical Invariants (Do Not Violate)

This software controls real heaters and motors.

### 3.1 Control loop invariants

- The controller must always be able to:
  - turn off auger and igniter in error/shutdown scenarios
  - keep the fan behavior consistent with the current mode
  - respect safety thresholds (`settings['safety']`) and mode transitions

**Do not** make “UI-only” changes that accidentally change:
- units conversion
- setpoint interpretation
- allowed mode strings
- manual override gating

### 3.2 Manual outputs are dangerous

Manual toggles exist (fan/auger/igniter/power, PWM). They are guarded by:
- being in `Manual` mode **or**
- `settings['safety']['allow_manual_changes']`

Any UI work that touches manual controls must:
- keep the same commands and URLs
- keep the same confirmation/visibility semantics
- avoid “auto-triggering” manual commands on page load

### 3.3 Don’t increase risk by changing defaults

Avoid changing default values, timings, or safety thresholds unless explicitly requested by the maintainer.

---

## 4) Where to Make Changes Safely

### 4.1 Safe zones for UI work

- Templates in `templates/` and `blueprints/*/templates/`
- CSS/JS in `static/` and `blueprints/*/static/`

When editing templates:
- Keep element IDs used by existing JS (e.g., toolbar button IDs) unless you update all callers.
- Keep Jinja variables passed by blueprints consistent.

When editing JS:
- Do not change API URLs.
- Do not change the expected response schema.
- Prefer progressive enhancement (support old behavior + new UI).

### 4.2 High-risk zones (avoid with AI unless explicitly requested)

- `control.py` and any controller modules in `controller/`
- Hardware/platform drivers under `grillplat/`, `probes/`, `display/`, `distance/`
- Core API implementation in `common/common.py` and `blueprints/api/routes.py`

If changes are unavoidable:
- Make them minimal.
- Add only optional fields/branches.
- Validate on real hardware or a carefully simulated environment.

---

## 5) Compatibility Checklist (Run Before Shipping)

### 5.1 HTTP API smoke checks

Verify these calls still work and return JSON:

- `GET /api/current`
- `GET /api/get/status`
- `GET /api/get/timer`
- `POST /api/set/mode/hold/225` (or your unit)
- `POST /api/set/splus/true`
- `POST /api/set/timer/start/60`

Verify legacy endpoints:

- `GET /api/settings`
- `POST /api/settings` with a minimal nested JSON update
- `GET /api/control`

### 5.2 Socket.IO smoke checks

- Client can connect.
- `listen_app_data` starts periodic emits.
- Client receives `socket_dash_data` at least once per second.

### 5.3 UI/Template checks

- Dashboard loads without console errors.
- Control panel buttons still trigger the same `/api/set/...` calls.
- Timer bar still works (start/pause/stop) and reflects `/api/get/timer`.
- Wizard/update/settings pages still load and submit.

### 5.4 Safety checks (when on real hardware)

- Startup → Smoke/Hold transitions behave as expected.
- Over-temp / startup failure protections still trip correctly.
- Manual outputs do not change unless user explicitly clicks.

---

## 6) Guidelines for AI-Assisted Changes

### 6.1 “Allowed” AI tasks

- Refactor HTML/CSS for readability, layout, accessibility (while preserving IDs and endpoints).
- Add new UI components **only if** they call existing endpoints.
- Improve error messaging and edge-case handling in JS.

### 6.2 “Not allowed” without explicit maintainer approval

- Changing API route paths, request methods, or parameter parsing.
- Adding any new `/api/...` endpoints.
- Changing `app.py`.
- Renaming fields in API responses.
- Altering controller timing constants, mode strings, or safety checks.
- Replacing Redis keys/structures.

### 6.3 When you must change Python

Use this pattern:

1. **Add** new functionality without deleting old behavior.
2. Keep old defaults the same.
3. Maintain legacy keys in JSON responses.
4. Add an integration test plan (even if manual) to verify hardware-safe behavior.

---

## 7) Pointers to Critical Files

- Web entrypoint: `app.py`
- Hardware/control entrypoint: `control.py`
- Core API routing: `blueprints/api/routes.py`
- Command processor + Redis structures: `common/common.py`
- Socket.IO mobile API: `blueprints/mobile/socket_io.py`
- Shared web helpers: `common/app.py`
- Updater CLI/helpers: `updater.py`
- Install/config wizard CLI/helpers: `wizard.py`
- Board configuration tool: `board-config.py`

---

## 8) Full HTTP API Map (Frozen)

This is the **complete** HTTP API surface currently implemented by PiFire on this branch (to the best of our ability, based on code review). Treat everything below as frozen/backwards-compatible.

### 8.1 API Router

The API blueprint registers the following patterns (all accept `GET` and `POST` at the Flask level):

- `/api/`
- `/api/<action>`
- `/api/<action>/<arg0>`
- `/api/<action>/<arg0>/<arg1>`
- `/api/<action>/<arg0>/<arg1>/<arg2>`
- `/api/<action>/<arg0>/<arg1>/<arg2>/<arg3>`

If `action` is one of `get`, `set`, `cmd`, `sys`, the router delegates to `common.common.process_command(action, arglist)`.

Note on status codes:

- Many endpoints return HTTP `201` even for `GET` (legacy behavior). Do not “normalize” these unless explicitly approved.

### 8.2 Resource-Style Endpoints (Legacy + Public)

These are handled directly in the API blueprint and are used by the UI/JS.

- `GET /api/settings` → `{"settings": <settings dict>}` (HTTP 201)
- `POST /api/settings` (JSON) → returns:
  - `settings`: `success|error` (legacy key, must remain)
  - `result`: `success|error`
  - `message`: human readable
  - (HTTP 201)

- `GET /api/control` → `{"control": <control dict>}` (HTTP 201)
- `POST /api/control` (JSON) → returns:
  - `control`: `success|error` (legacy key, must remain)
  - `result`: `success|error`
  - `message`: human readable
  - (HTTP 201)

- `GET /api/current` → `{"current": <temps>, "notify_data": <list>, "status": <object>}` (HTTP 201)
  - `status` includes keys such as: `mode`, `display_mode`, `status`, `s_plus`, `units`, `name`, `outpins`, `ui_hash`, `probe_status`, etc.

- `GET /api/server` → `{"server_status": "available"|...}` (HTTP 201)

- `GET /api/hopper` → `{"hopper_level": <int>, "hopper_pellets": <string>}`

WLED endpoints (public):

- `GET /api/wled_discover?timeout=<int>` → returns `result/message/devices` (HTTP 200 on success; 4xx/5xx on failure)
- `POST /api/wled_push_profiles` (JSON: `device_address`, optional `profile_numbers`) → returns `result/message/...`
- `POST /api/wled_test_profile` (JSON: `device_address`, `profile_number`) → returns `result/message`

### 8.2.1 Sample responses (captured from a live system)

The following examples were captured from a running PiFire instance at `http://pifire.local` and lightly redacted.

Full captured samples are stored in `api_samples.redacted.json`.

`GET /api/server`

```json
{
  "server_status": "available"
}
```

`GET /api/hopper`

```json
{
  "hopper_level": 50,
  "hopper_pellets": "Generic Alder"
}
```

`GET /api/settings` (truncated)

```json
{
  "settings": {
    "controller": { "selected": "pid" },
    "cycle_data": { "PMode": 2, "HoldCycleTime": 25 },
    "versions": { "server": "1.10.4", "build": 64 }
  }
}
```

### 8.3 Command Endpoints via `process_command()`

These use the path format `/api/<action>/<arg0>/<arg1>/<arg2>/<arg3>`.

#### 8.3.1 `get` commands

- `GET /api/get/temp/<probe_label>`
  - Returns: `data.temp` containing the probe temperature if found.

- `GET /api/get/current`
  - Returns: `data` containing the full current temperature structure (e.g., `P`, `F`, `AUX`, `NT`, `PSP`, `TS`).

- `GET /api/get/mode`
  - Returns: `data.mode` from the control structure.

- `GET /api/get/uuid`
  - Returns: `data.uuid` (server UUID).

- `GET /api/get/versions`
  - Returns: `data.version`, `data.build`.

- `GET /api/get/hopper`
  - Triggers a hopper check and then returns `data.hopper`.

- `GET /api/get/timer`
  - Returns: `data.start`, `data.paused`, `data.end`, `data.shutdown`, `data.keep_warm`.

- `GET /api/get/notify`
  - Returns: `data` as the notify list (`control.notify_data`).

- `GET /api/get/status`
  - Returns: `data` object containing status keys used heavily by UI (`mode`, `display_mode`, `status`, `s_plus`, `units`, `name`, times, `outpins`, `ui_hash`, etc.).

All `get` responses follow the `process_command()` envelope:

- `result`: `OK|ERROR`
- `message`: string
- `data`: object

Sample `get` responses:

`GET /api/get/status`

```json
{
  "result": "OK",
  "message": "Command was accepted successfully.",
  "data": {
    "mode": "Stop",
    "display_mode": "Stop",
    "units": "F",
    "s_plus": false,
    "outpins": { "auger": false, "fan": false, "igniter": false, "power": false, "pwm": 0 },
    "ui_hash": 7553131808187328464
  }
}
```

`GET /api/get/current`

```json
{
  "result": "OK",
  "message": "Command was accepted successfully.",
  "data": {
    "P": { "Grill": 0 },
    "F": { "Probe1": 0, "Probe2": 0, "Probe3": 0 },
    "AUX": {},
    "NT": { "Grill": 0, "Probe1": 0, "Probe2": 0, "Probe3": 0 },
    "PSP": 0
  }
}
```

`GET /api/get/timer`

```json
{
  "result": "OK",
  "message": "Command was accepted successfully.",
  "data": { "start": 0, "paused": 0, "end": 0, "shutdown": false, "keep_warm": false }
}
```

`GET /api/get/uuid`

```json
{
  "result": "OK",
  "message": "Command was accepted successfully.",
  "data": { "uuid": "7274bb52-f70d-11f0-8d3b-d83add89e62c" }
}
```

`GET /api/get/mode`

```json
{
  "result": "OK",
  "message": "Command was accepted successfully.",
  "data": { "mode": "Stop" }
}
```

`GET /api/get/versions`

```json
{
  "result": "OK",
  "message": "Command was accepted successfully.",
  "data": { "version": "1.10.4", "build": 64 }
}
```

#### 8.3.2 `set` commands

These are typically invoked via `POST` from the UI, but the router accepts both methods.

- `POST /api/set/psp/<temp>`
  - Sets primary setpoint and moves mode to `Hold`.

- `POST /api/set/units/<C|F>`
  - Converts settings units and flags `control.settings_update`, `control.units_change`.

- `POST /api/set/mode/<mode>`
  - `mode` must be one of: `startup`, `smoke`, `shutdown`, `stop`, `reignite`, `monitor`, `error`, `manual`.

- `POST /api/set/mode/prime/<grams>[/<next_mode>]`
  - `next_mode` is typically `startup` or `monitor`; otherwise defaults to `Stop`.

- `POST /api/set/mode/hold/<temp>`
  - Sets mode to `Hold` and updates primary setpoint.

- `POST /api/set/pmode/<0-9>`
  - Updates `settings.cycle_data.PMode`.

- `POST /api/set/splus/<true|false>`
  - Updates `control.s_plus`.

- `POST /api/set/lid_open/toggle`
  - Triggers lid-open toggle behavior (`control.lid_open_toggle`).

Notify / limits:

- `POST /api/set/notify/<label>/(req|shutdown|keep_warm|reignite)/<true|false>`
- `POST /api/set/notify/<label>/target/<value>` (not valid for `Timer` or `Hopper`)
- `POST /api/set/limit_high/<label>/...` and `POST /api/set/limit_low/<label>/...`
  - Same subcommands as `notify`, but targets the corresponding `probe_limit_high` / `probe_limit_low` object types.

Fan / tuning:

- `POST /api/set/pwm/<true|false>`
- `POST /api/set/duty_cycle/<0-100>`
- `POST /api/set/tuning_mode/<true|false>`

Timer control:

- `POST /api/set/timer/start/<seconds>`
- `POST /api/set/timer/start` (used for unpause)
- `POST /api/set/timer/pause`
- `POST /api/set/timer/stop`
- `POST /api/set/timer/shutdown/<true|false>`
- `POST /api/set/timer/keep_warm/<true|false>`

Manual outputs (dangerous):

- `POST /api/set/manual/power/<true|false|toggle>`
- `POST /api/set/manual/igniter/<true|false|toggle>`
- `POST /api/set/manual/fan/<true|false|toggle>`
- `POST /api/set/manual/auger/<true|false|toggle>`
- `POST /api/set/manual/pwm/<speed>`

#### 8.3.3 `cmd` commands

- `POST /api/cmd/restart`
- `POST /api/cmd/reboot`
- `POST /api/cmd/shutdown`

These are server/system actions. Treat them as safety-critical.

#### 8.3.4 `sys` commands

- `POST /api/sys/<command>[/<arg1>[/<arg2>[/<arg3>]]]`

Behavior:

- Enqueues the request to Redis queue `control:systemq`.
- `control.py` consumes it and calls the corresponding method on the active `grill_platform` implementation.
- The web process waits for an answer on `control:systemo` matching the requested command.

Because supported commands depend on the active grill platform module, the authoritative way to discover them is:

- `POST /api/sys/supported_commands` then read the response.

Known `sys` commands referenced by the repo (treat as part of the API surface):

- `supported_commands`
- `check_alive`
- `scan_bluetooth`
- `check_wifi_quality`
- `check_throttled`
- `check_cpu_temp`
- `network_info`
- `hardware_info`

### 8.4 Callers That Must Remain Working

When updating the UI, remember that `/api/...` is called from multiple places:

- Global UI JS under `static/js/` (e.g., control panel + timer)
- Blueprint JS under `blueprints/*/static/`
- Some templates under `templates/` and `blueprints/*/templates/`
- The flex display can call API endpoints locally (e.g., manual toggles)

If you refactor HTML, update JS selectors, but do not change API URLs or payload expectations.

---

## 9) Quick Reference: API Commands Used By UI

Common patterns used in JS:

- `POST /api/set/<command>` (no JSON body)
  - Examples: `manual/igniter/toggle`, `timer/pause`, `timer/stop`, `mode/hold/225`

- `GET /api/get/<thing>`
  - Examples: `timer`, `status`, `mode`, `current`

If you see front-end code building URLs like `'/api/set/' + command`, treat the command strings as public API.
