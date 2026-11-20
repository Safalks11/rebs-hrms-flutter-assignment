# REBS HRMS

Flutter/GetX employee HRMS assignment with GPS attendance, persistent offline attendance events, leave requests, and a local Express mock API.

## Run locally

1. Start the server using [mock_api/README.md](mock_api/README.md). Set office coordinates to your actual test location.
2. Run `flutter pub get`.
3. For Android Emulator, run:

```sh
flutter run
```

The app downloads and caches office coordinates from the server; no office build variables are needed. Attendance requires one successful office sync before it can be marked offline. The default API URL is `http://10.0.2.2:8080`. For a real phone, start the server with `HOST=0.0.0.0`, connect the phone and computer to the same network, and pass `--dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8080`. For iOS Simulator use `http://127.0.0.1:8080`; a physical iPhone uses the computer's LAN IP. Local HTTP is intended for development.

The server holds demo employee EMP001 and seeds leave history. It has no authentication. The app caches employee details, office coordinates, attendance, and leave balances/history in SQLite. Valid attendance is saved before network delivery. Pending events keep their IDs and sync in check-in/check-out order on reconnect or with **Sync Now**. A timeout leaves them pending because the server may have accepted the request. Server validation failures show as Rejected in attendance history. Leave submission requires connectivity; a confirmed leave response is cached and visible offline.

## Checks

Run `dart format lib test`, `flutter analyze`, `flutter test`, and `npm test` inside `mock_api`.

## Architecture and limits

Feature-first GetX controllers and bindings; services own Dio, SQLite, and GPS. Company date is Asia/Kolkata. One attendance session per day, no overnight shifts. All calendar days count toward leave. The mock server accepts attendance for today and the previous 29 company dates. There is no background sync after the app terminates and no login.

Development was AI-assisted. Time spent has not been tracked. The debug APK and demonstration video are delivery items to prepare separately.
