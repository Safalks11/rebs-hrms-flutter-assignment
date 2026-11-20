# REBS HRMS mock API

Express server for local development, used by the Flutter app. Requires Node.js 20+.

## Start

From this directory:

```sh
export OFFICE_LATITUDE=12.9716
export OFFICE_LONGITUDE=77.5946
npm ci
npm start
```

Use your real test-office coordinates for the server. The app downloads and caches them from `GET /office`; it needs no office coordinate build variables. The default server address is `127.0.0.1:8080`. For a physical device, set `HOST=0.0.0.0` and use your computer's LAN IP. Android Emulator reaches the host at `10.0.2.2`. Optional: `PORT`, `DATA_FILE` (default `data/state.json`), and `MOCK_DELAY_MS` (default 20000).

On this machine, select the working Node 24 install with `export PATH="/opt/homebrew/opt/node@24/bin:$PATH"` before npm commands.

Run `npm test` for automated tests. To restore seed data, stop the server, run `npm run reset`, then restart. The JSON file survives restarts and is ignored by Git. Only run one process per data file. Startup fails on corrupt data; reset explicitly if needed. The fresh seed has no attendance and one Pending, one Approved, and one Rejected leave request. Available balances start at 7 Casual and 4 Sick days.

## API

- `GET /health` returns `{"status":"ok"}`.
- `GET /employee/me` returns demo employee EMP001.
- `GET /office` returns the server's configured `latitude` and `longitude`.
- `GET /attendance?month=YYYY-MM` returns `{"events":[]}`.
- `POST /attendance/events` accepts `id`, `employeeId`, `companyDate`, `type` (`checkIn` or `checkOut`), timezone-aware `timestamp`, `latitude`, and `longitude`.
- `GET /leave/balance` returns `{"casual":7,"sick":4}` initially.
- `GET /leave/requests` returns `{"requests":[]}` with the seeded examples.
- `POST /leave/requests` accepts `id`, `employeeId`, `type` (`casual` or `sick`), `startDate`, `endDate` (YYYY-MM-DD), and `reason`. The saved response includes `status:"pending"`.

Example attendance body:

```json
{"id":"unique-event-id","employeeId":"EMP001","companyDate":"2026-11-20","type":"checkIn","timestamp":"2026-11-20T09:00:00Z","latitude":12.9716,"longitude":77.5946}
```

Replace the example date and coordinates with current values. Keep the same ID on retries. A new event returns 201; an identical retry returns 200 even after the 30-day acceptance window. Reusing an ID with changed data returns 409. The server requires check-in before check-out, one session per Asia/Kolkata date, location within 200 metres, and a timestamp no later than now. It accepts today and the previous 29 company dates.

Leave requests require a start date no earlier than today, an end date no earlier than start, at least 10 non-whitespace reason characters, no overlap with Pending or Approved requests, and sufficient balance. All calendar days count. Pending and Approved requests reserve balance; Rejected requests do not.

Errors return `{"code":"...","message":"..."}` with 400 for malformed input, 409 for conflicts, 422 for validation, and 500 for server failures. There is no authentication; use the server only for local development.

## Repeatable scenarios

Send `X-Mock-Scenario` with one of:

- `success` (default)
- `slow`: delay before processing
- `timeout-after-commit`: persist POST, then delay the response
- `server-error`: 500 without mutation
- `attendance-conflict`: 409 without mutation
- `leave-rejection`: 422 without mutation

```sh
curl http://127.0.0.1:8080/health
curl 'http://127.0.0.1:8080/attendance?month=2026-11'
curl http://127.0.0.1:8080/leave/balance
curl -H 'X-Mock-Scenario: server-error' http://127.0.0.1:8080/employee/me
```

For an ambiguous timeout, send a valid POST with `curl --max-time 1 -H 'X-Mock-Scenario: timeout-after-commit'`, then retry the same body and ID without the scenario header. Only one record will exist.

AI-assisted development was used for this mock API.
