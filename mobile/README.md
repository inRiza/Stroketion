# Stroketion Mobile

Aplikasi Flutter untuk pasien dan caregiver. Memantau balance (IMU), speech (via backend WebSocket), dan risiko sesi monitoring stroke.

## Versi Flutter / Dart

| Tool | Versi (pengembangan) |
|------|----------------------|
| Flutter | **3.44.6** (stable) |
| Dart | **3.12.2** |
| Min. SDK di `pubspec.yaml` | `^3.12.2` |

Pastikan Flutter SDK compatible sebelum build:

```bash
flutter --version
flutter doctor
```

## Spesifikasi lingkungan pengujian

| Item | Rekomendasi |
|------|-------------|
| OS | **Android 8.0 (API 26)** atau lebih baru |
| Perangkat | **HP fisik** direkomendasikan (accelerometer, gyroscope, mikrofon, GPS) |
| Emulator | Android Emulator API 33+ (speech/mic perlu konfigurasi tambahan) |
| Backend | FastAPI Stroketion harus jalan dan reachable dari HP (`--host 0.0.0.0`) |
| Jaringan | HP dan server backend **satu WiFi/LAN** (atau set IP server di Pengaturan app) |

Catatan: Emulator Android memakai `10.0.2.2:8000` otomatis. HP fisik memakai IP LAN server (default compile: `192.168.1.112`, bisa diubah di **Pengaturan > Alamat server**).

## Akun demo (login)

Backend harus sudah di-seed. Dari folder `backend/`:

```bash
uv run python scripts/seed_demo_deliverables.py
```

| Role | Email | Password |
|------|-------|----------|
| **Pasien** | `pasien.demo@stroketion.app` | `Demo1234` |
| **Caregiver** | `caregiver.demo@stroketion.app` | `Demo1234` |

Kedua akun sudah ter-link (approved). Caregiver dapat melihat riwayat sesi pasien demo termasuk satu sesi contoh.

## Menjalankan project (development)

```bash
cd mobile
flutter pub get
flutter run
```

Backend (terminal terpisah):

```bash
cd backend
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Override IP server saat run:

```bash
flutter run --dart-define=API_HOST=192.168.1.100
```

## Build APK release (deliverable)

```bash
cd mobile
flutter pub get
flutter build apk --release
```

Output APK:

```
mobile/build/app/outputs/flutter-apk/app-release.apk
```

Salin/rename untuk submission, misalnya `stroketion-v1.0.0-release.apk`.

Build split per ABI (opsional, ukuran lebih kecil):

```bash
flutter build apk --release --split-per-abi
```

## Arsip source code (deliverable)

Sebelum zip, **hapus** folder berikut agar ukuran tidak membengkak:

- `build/`
- `.dart_tool/`
- `android/build/` (jika ada)

Contoh dari root repo:

```bash
cd mobile
zip -r ../stroketion-mobile-source.zip . \
  -x "build/*" -x ".dart_tool/*" -x "android/build/*" -x "ios/Pods/*" -x ".idea/*"
```

File `README.md` ini wajib ada di dalam arsip source code.

## Roles

| Role | Layar utama |
|------|-------------|
| Pasien | Beranda, sesi aktif, ringkasan, QR profil, kontak darurat |
| Caregiver | Beranda pasien, scan QR, aktivitas terbaru, detail sesi pasien |

## Arsitektur (client)

```text
SessionSensorService
  MotionProcessor     SVM, AVM, fall FSM
  SessionGpsService   route points (outdoor)
  SpeechStreamService WebSocket PCM 16 kHz
        |
        v
SessionScoring        balance + speech + risk level
MonitoringSessionApi  POST /sessions, GET detail
SessionHistoryStorage local cache (SharedPreferences, per user_id)
PatientSessionLoader  merge local + API per account
```

## Paket utama

| Package | Fungsi |
|---------|--------|
| `sensors_plus` | Accelerometer, gyroscope |
| `record` | Microphone PCM stream |
| `geolocator` | Rute outdoor |
| `web_socket_channel` | Speech pipeline |
| `flutter_map` | Peta rute sesi |
| `mobile_scanner` | Scan QR caregiver |
| `flutter_svg` | Logo Stroketion |

## Alur sesi

1. Pasien pilih lokasi (rumah/outdoor) dan aktivitas (harian/latihan).
2. Sensor + GPS (opsional) aktif; speech stream ke backend jika online.
3. Fall atau speech SOS → dialog countdown; caregiver dapat notifikasi.
4. Stop sesi → skor dihitung, disimpan lokal (per akun) dan di-upload ke server.
5. Ringkasan: grafik balance, peta (outdoor), panel speech, timeline kejadian.

## Tests

```bash
flutter test
flutter analyze
```

## Platform notes

- **Android**: permission `INTERNET`, `CAMERA`, `RECORD_AUDIO`, lokasi di manifest.
- **iOS**: usage strings mikrofon, motion, lokasi di `Info.plist`.
- Display name: **Stroketion**.
