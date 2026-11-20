# REBS HRMS

A Flutter app for employees to mark attendance, view working hours, and apply for leave.

note: Development was AI-assisted. **The mock API and test cases were generated using AI (Codex).**

## Features

- Employee dashboard with today's attendance, working duration, leave balance, and latest five attendance records.
- GPS-based check-in and check-out within 200 metres of the office.
- Offline attendance saved on the device, even after restarting the app.
- Automatic sync when connected again, plus a **Sync Now** button.
- Clear Pending Sync, Synced, and Rejected attendance statuses.
- Casual and Sick Leave applications with validation and saved leave history.
- Local mock API for testing success, timeouts, errors, and rejected requests.

## Getting started

You need Flutter with Dart compatible with `^3.13.7`, Node.js 20+ with npm, and an Android emulator or device. For iOS, you also need macOS and Xcode.

### 1. Start the mock API

Open a terminal in the project folder:

```sh
cd mock_api
npm ci
export OFFICE_LATITUDE=12.9716
export OFFICE_LONGITUDE=77.5946
npm start
```

Replace these example coordinates with your test location, or set the emulator's location to match them. Keep this terminal running.

See the [mock API guide](mock_api/README.md) for endpoints, sample requests, test scenarios, and reset instructions.

### 2. Run the app

Open another terminal in the project folder:

```sh
flutter pub get
flutter run
```

This uses `http://10.0.2.2:8080`, which connects an Android emulator to the API on your computer.

For an iOS simulator:

```sh
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

For a physical phone, connect your phone and computer to the same network. Start the API with `HOST=0.0.0.0 npm start`, then use your computer's local IP:

```sh
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8080
```

Enable location services and allow location permission. Open the app online once before trying offline attendance so it can save the office location and dashboard data.

## Architecture

The app uses a simple feature-first structure with MVC-style separation:

- `lib/app/`: routes, dependency bindings, and theme.
- `lib/core/`: shared networking, storage, connectivity, and utilities.
- `lib/features/`: dashboard, attendance, leave, and office profile.
- `mock_api/`: local Node.js/Express server.

Views display the UI, GetX controllers manage screen state, and services handle API calls, GPS, and storage. Dio handles HTTP requests, SQLite stores offline data, and Geolocator checks location.

Attendance is saved locally before being sent to the server. Retries use the same event ID to prevent duplicates. A timeout keeps the event pending until the server confirms it or rejects it.

## Assumptions and limitations

- Uses one demo employee, **EMP001**, with no login.
- Company timezone is **Asia/Kolkata**.
- One check-in and check-out per day; overnight shifts are not supported.
- GPS validation is required for both online and offline attendance.
- Pending attendance syncs while the app is open; it does not sync after the app is terminated.
- The server accepts new attendance for today and the previous 29 company dates.
- Leave submission needs an internet/network connection to the API. Previously loaded history remains available offline.
- Leave includes weekends and holidays. Dates cannot overlap Pending or Approved requests, and requests must fit the available balance.
- The mock API is for local development, not production. Resetting it does not clear the app's saved data.
- Android and iOS are target platforms; device testing is still needed before delivery.

## Tests

From the project folder:

```sh
flutter analyze
flutter test
```

From the `mock_api` folder:

```sh
npm test
```

Tests cover attendance ordering, duplicate prevention, offline persistence and sync, leave validation, API errors, and dashboard states.

## Build a debug APK

Use an API address that your test phone can reach:

```sh
flutter build apk --debug --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8080
```

The APK will be created at `build/app/outputs/flutter-apk/app-debug.apk`.

For submission, include the source code, debug APK, mock API, and a 3–5 minute demo showing online attendance, offline attendance surviving a restart, synchronization, and leave submission.

