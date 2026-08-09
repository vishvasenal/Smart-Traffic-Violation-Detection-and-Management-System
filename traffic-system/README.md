# Traffic Violation Management System — Web Frontend

A browser frontend for your `main 2.0.pl` program. The original logic
(license validation, vehicle multipliers, violation fines, credit
deduction) runs **unchanged inside SWI-Prolog** — `server.pl` just wraps
it with an HTTP/JSON API instead of `read/1` console prompts, and
`www/index.html` is a web UI that calls that API.

```
traffic-system/
├── server.pl        ← Prolog backend (facts + rules + HTTP API)
├── www/
│   └── index.html    ← Frontend (talks to the API via fetch)
└── README.md
```

## 1. Requirements

- [SWI-Prolog](https://www.swi-prolog.org/download/stable) 8.x or newer
  (includes the `http` library group by default).

Check it's installed:
```bash
swipl --version
```

## 2. Run the server

From the `traffic-system` folder:

```bash
swipl server.pl
```

You should see:

```
=== Traffic Violation Management System ===
Server running at http://localhost:8080
```

This drops you into the Prolog toplevel (`?-`) — that's normal, the
HTTP server keeps running in the background in its own thread. Leave
this terminal open.

## 3. Open the frontend

Visit **http://localhost:8080** in your browser. The Prolog server
serves the page itself, so there's no separate frontend server or CORS
setup needed.

To stop the server, close the terminal or type `halt.` at the `?-` prompt.

## How it maps to the original code

| Original predicate | Now lives as |
|---|---|
| `valid_license/1`, `vehicle_multiplier/2`, `violation/4` | Unchanged facts in `server.pl` |
| `check_license/1` (repeat/read loop) | `POST /api/license` — frontend re-submits the form on error instead of Prolog looping on `read/1` |
| `input_vehicle_type/0` | `POST /api/vehicle` |
| `generate_report/1` (incl. the no_helmet-for-bikes rule) | `POST /api/violation` — returns the report as JSON instead of `write/1` to console |
| `check_status/1` | `status_of/3`, used by `/api/violation` and `/api/status` |
| `driver_credits/1`, `current_license/1`, etc. | Same `dynamic` facts, now mutated per HTTP request instead of per console turn |

## API reference

| Endpoint | Method | Body | Purpose |
|---|---|---|---|
| `/api/start` | POST | — | Reset session, credits → 10 |
| `/api/license` | POST | `{"license": 10000000}` | Validate a license number |
| `/api/vehicle` | POST | `{"vehicle_num": "WP CAB 1234", "vehicle_type": "bike"}` | Register vehicle |
| `/api/violation` | POST | `{"offense": "speeding"}` | File a violation, get the fine report |
| `/api/status` | GET | — | Current credits/status for the gauge |

## Notes / things you may want to extend

- State is currently a single global session (matches the original
  single-session console program). For multiple simultaneous users
  you'd key the dynamic facts by a session ID (e.g. a cookie) instead.
- Vehicle numbers/violations aren't persisted anywhere — add a log
  file or SQLite via `library(persistency)` if you want history across
  restarts.
