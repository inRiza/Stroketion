# Stroketion Mobile

Flutter app for patients and caregivers. Monitors balance, speech, and session risk using phone sensors.

## Requirements

- Flutter SDK 3.12+
- Physical device recommended (accelerometer, gyroscope, microphone, GPS)
- Backend running (see [backend/README.md](../backend/README.md))

## Run

```bash
flutter pub get
flutter run
```

Set server URL in **Pengaturan > Alamat server** when the API is not on the device default host.

## Roles

| Role | Main screens |
|------|----------------|
| Patient | Beranda (chart + riwayat), sesi aktif, ringkasan, QR profil, kontak darurat |
| Caregiver | Beranda pasien, scan QR, aktivitas terbaru, detail sesi pasien |

## Architecture (client)

```text
SessionSensorService
  MotionProcessor     SVM, AVM, fall FSM
  SessionGpsService   route points (outdoor)
  SpeechStreamService WebSocket PCM 16 kHz
        |
        v
SessionScoring        balance + speech + risk level
MonitoringSessionApi  POST /sessions, GET detail
SessionHistoryStorage local cache keyed by user_id
PatientSessionLoader  merge local + API per account
```

## Key packages

| Package | Use |
|---------|-----|
| `sensors_plus` | Accelerometer, gyroscope |
| `record` | Microphone PCM stream |
| `geolocator` | Outdoor route |
| `web_socket_channel` | Speech pipeline |
| `flutter_map` | Session route map |
| `mobile_scanner` | Caregiver QR scan |
| `flutter_svg` | Stroketion logo assets |

## Project structure

```
lib/
├── app.dart                 MaterialApp shell
├── core/                    theme, config, constants
├── features/
│   ├── auth/                login, register, role pick
│   ├── home/                patient + caregiver tabs
│   ├── session/             active, summary, history
│   ├── link/                QR show / scan
│   └── settings/            server, privacy, about
├── models/                  session, speech, link, user
├── services/                API, sensors, scoring, SOS
├── routes/                  named routes
└── widgets/                 shared UI components
assets/
├── logo/                    logo_r.svg, logo_w.svg
├── illustrations/
└── sounds/                  sos_alert.mp3
```

## Session flow

1. Patient picks location (home/outdoor) and activity (daily/exercise).
2. Sensors and optional GPS start; speech streams to backend if online.
3. Fall or speech SOS opens countdown dialog; caregiver gets notification.
4. On stop: scores computed, record saved locally (per user) and uploaded.
5. Summary screen shows balance chart, map (outdoor), speech panel.

## Tests

```bash
flutter test
flutter analyze
```

## Platform notes

- **Android**: `INTERNET`, `CAMERA`, `RECORD_AUDIO`, location permissions in manifest.
- **iOS**: microphone, motion, location usage strings in `Info.plist`.
- Display name: **Stroketion** (`CFBundleDisplayName`, `android:label`).
