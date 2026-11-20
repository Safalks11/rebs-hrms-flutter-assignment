# REBS HRMS mock API

A local Node.js/Express server for the Flutter app. It saves data in `data/state.json` so attendance and leave requests survive server restarts. Requires Node.js 20+.

## Start the server

From the `mock_api` folder:

```sh
npm ci
export OFFICE_LATITUDE=12.9716
export OFFICE_LONGITUDE=77.5946
HOST=0.0.0.0 npm start
```

Use your actual test location for the office coordinates. `HOST=0.0.0.0` lets a physical phone on the same Wi-Fi network reach the server. Keep this terminal running. On the computer, check:

```sh
curl http://127.0.0.1:8080/health
```

The response should be `{"status":"ok"}`. On the phone, open `http://YOUR_COMPUTER_LAN_IP:8080/health` in its browser. If it does not load, check the computer's IP address, Wi-Fi network, and firewall. Build the debug APK with that same IP address, as shown in the [main README](../README.md). Android Emulator can still connect through `http://10.0.2.2:8080`.

## Available endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Check server status |
| GET | `/employee/me` | Get demo employee EMP001 |
| GET | `/office` | Get configured office coordinates |
| GET | `/attendance?month=YYYY-MM` | Get attendance events for a month |
| POST | `/attendance/events` | Save a check-in or check-out |
| GET | `/leave/balance` | Get Casual and Sick Leave balances |
| GET | `/leave/requests` | Get leave history |
| POST | `/leave/requests` | Submit a leave request |

A fresh server starts with no attendance or leave requests and balances of 8 Casual and 5 Sick days. There is no login or authentication.

## Test different responses

Add an `X-Mock-Scenario` header to a request:

| Value | Result |
| --- | --- |
| `success` | Normal response (default) |
| `slow` | Delayed response |
| `timeout-after-commit` | POST is saved, then response is delayed |
| `server-error` | HTTP 500 |
| `attendance-conflict` | Attendance POST returns HTTP 409 |
| `leave-rejection` | Leave POST returns HTTP 422 |

Example:

```sh
curl -H 'X-Mock-Scenario: server-error' http://127.0.0.1:8080/employee/me
```

`MOCK_DELAY_MS` controls the delay (default 20000 ms). For a timeout after commit, retry the same POST body with the same event ID. The server returns the saved record instead of creating a duplicate. The Flutter app does not expose a scenario selector; use an HTTP client such as curl to test these scenarios.

## Validation rules

Attendance must use employee `EMP001`, valid GPS coordinates within 200 metres of the office, and the Asia/Kolkata company date. Check-in comes before check-out, with one session per day. New events are accepted for today and the previous 29 company dates. Keep the same unique ID for retries.

Leave requests must start today or later, have an end date on or after the start date, include at least 10 non-whitespace characters in the reason, fit the available balance, and avoid overlap with Pending or Approved requests. All calendar days count.

Errors include a `code` and `message`. Invalid input returns HTTP 400, conflicts 409, validation failures 422, and server failures 500.

## Tests and reset

```sh
npm test
```

To clear server attendance and leave requests, stop the server, run `npm run reset`, then start it again. Resetting the server does not clear the Flutter app's local SQLite data. Run only one server process per data file. Optional settings are `PORT`, `DATA_FILE`, and `MOCK_DELAY_MS`.

The mock API and its test cases were generated using AI (Codex).
