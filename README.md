![Stroketion](./mobile/assets/logo/logo_r.svg)

# Stroketion

Aplikasi monitoring stroke berbasis sensor ponsel dan analisis AI. Balance, speech, dan risiko sesi untuk pasien dan caregiver.

![License MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)![FastAPI](https://img.shields.io/badge/backend-FastAPI-009688?style=flat-square)![Flutter](https://img.shields.io/badge/mobile-Flutter-02569B?style=flat-square&logo=flutter)![Python](https://img.shields.io/badge/python-3.11+-3776AB?style=flat-square&logo=python)

[Why](#why-stroketion) · [Features](#features) · [Architecture](#architecture) · [Technical](#technical-approach) · [Math](#mathematical-approach) · [Quick start](#quick-start) · [Structure](#project-structure) · [License](#license)

---



## Why Stroketion

Pasien stroke dan caregiver sering kesulitan memantau tanda perubahan harian: keseimbangan tubuh, pola bicara, dan kejadian jatuh. Stroketion menggabungkan accelerometer, gyroscope, mikrofon, dan GPS pada satu perangkat, lalu menilai risiko sesi dengan skor yang mudah dibaca. Bukan alat diagnosis, melainkan indikator pendamping untuk tindakan lebih cepat.

## Features



### Pasien

- Sesi monitoring indoor/outdoor dengan setup lokasi dan aktivitas
- Grafik balance per detik (SVM, impact, fall marker)
- Analisis speech real-time via WebSocket PCM 16 kHz
- SOS otomatis saat jatuh terdeteksi atau disfluensi klinis tinggi
- Ringkasan sesi: skor, risiko, rute GPS (outdoor), insight balance dan speech
- QR profil untuk menghubungkan caregiver
- Riwayat sesi per akun, sinkron ke server



### Caregiver

- Dashboard beranda: ringkasan risiko mingguan per pasien
- Feed aktivitas terbaru dari pasien terhubung
- Detail sesi pasien (sama seperti tampilan pasien)
- Notifikasi SOS dan permintaan link pasien
- Scan QR pasien dengan alur persetujuan bilateral



### Backend

- Auth JWT (pasien / caregiver)
- Upload dan query sesi monitoring
- Link caregiver dengan status pending/approved
- Baseline speech kalibrasi per user
- Pipeline speech multi-tier (VAD, denoise, akustik, klinis)
- Push notifikasi SOS ke caregiver terhubung



## Architecture

```text
Flutter (mobile, tanpa computer vision)
  sensors_plus  accelerometer + gyroscope (~50 Hz), estimasi postur IMU
  record        PCM 16 kHz mono
  geolocator    GPS untuk sesi outdoor
        |
        |  REST  /api/v1/sessions, /links, /auth, ...
        |  WS    /api/v1/speech/stream
        v
FastAPI (backend)
  session_service     persist timeline + route + scores
  speech/pipeline     utterance segmentation + clinical alerts
  link_service        caregiver approval flow
  PostgreSQL / SQLite + Redis (stream state)
```

Data sesi disimpan di server. Cache lokal mobile di-scope per `user_id` agar riwayat antar akun tidak tercampur.

## Technical approach

Semua metrik gerak dihitung di **mobile** (`motion_processor.dart`). Backend hanya menyimpan agregat sesi (SVM, AVM, tilt, heading deviation, timeline).

### Motion and balance (IMU only)

| Signal | Sumber | Fungsi |
| ------ | ------ | ------ |
| SVM | Accelerometer | Magnitudo g-force, free-fall, impact |
| AVM | Gyroscope | Kecepatan rotasi, bantuan konfirmasi jatuh |
| Postural θ | Accel + gyro (complementary filter) | Kemiringan postur HP relatif gravitasi |
| Heading | Accelerometer saja | Kompas UI, deviasi dari posisi awal sesi |
| GPS | `geolocator` | Rute outdoor saja, tidak mempengaruhi skor |

**Fall state machine:** Normal → free-fall (SVM < 2) → impact (SVM > 25) → inactivity post-impact → fall confirmed → SOS.

Kandidat jatuh jika impact berat (SVM ≥ 30), didahului free-fall, atau disertai rotasi gyro ≥ 60 deg/s saat benturan. Konfirmasi: variansi SVM rendah ~2.5 detik setelah impact.

**Timeline balance:** 1 titik/detik (`svm`, flag `impact`, flag `fall`).

File: `mobile/lib/services/motion_processor.dart`, `session_sensor_service.dart`

### Speech (mobile + backend)


| Tier | Gate / module                                     |
| ---- | ------------------------------------------------- |
| 0    | Energy gate (-45 dBFS)                            |
| 1    | Silero VAD (threshold 0.55)                       |
| 2    | Utterance buffer (gap silence 320 ms)             |
| 3    | DeepFilterNet denoise                             |
| 4    | SNR quality gate                                  |
| 5    | Parselmouth acoustic + fluency + clinical scoring |


Alert live `severity == high` memicu popup SOS di mobile. Rekaman klinis 5 detik disimpan hanya untuk momen SOS terkonfirmasi (max 5 episode/sesi). Whisper (opsional) hanya untuk analisis semantik pada segmen klinis jika paket terpasang.

File: `backend/app/speech/`, `mobile/lib/services/speech_stream_service.dart`

### Session scoring

Skor 100 = kondisi normal. Overall menggabungkan balance (65%) dan speech (35%). Level risiko: low, medium, high berdasarkan jatuh, impact, threshold SVM, dan indikator speech klinis.

Implementasi: `mobile/lib/services/session_scoring.dart`, `backend/app/speech/baseline.py`

## Mathematical approach



### Signal Vector Magnitude (SVM)

```
SVM = sqrt(ax^2 + ay^2 + az^2)
```

- Diam: ~9.8 m/s² (gravitasi)
- Free-fall: SVM < 2.0 m/s²
- Impact (timeline + FSM): SVM > 25 m/s²
- Impact berat (penalti skor): SVM > 30 m/s²

### Angular Velocity Magnitude (AVM)

```
AVM = sqrt(wx^2 + wy^2 + wz^2)   [rad/s → deg/s]
```

- Rotasi saat benturan (bantuan deteksi jatuh): AVM ≥ 60 deg/s
- Penalti balance score: max AVM > 200 deg/s (-8 poin)

### Postur (accelerometer + complementary filter)

Estimasi kemiringan postur **bukan** dari kamera. Sudut dari accelerometer:

```
theta_accel = arctan2(ay, az)
```

Gyroscope memperhalus dengan complementary filter (α = 0.97):

```
theta = alpha * (theta + wx * dt) + (1 - alpha) * theta_accel
```

`maxTiltDegrees` = nilai maksimum |theta| selama sesi. Penalti balance jika > 60 deg (-5 poin).

### Heading (accelerometer, terpisah dari postur)

Kompas UI memakai `atan2` pada sumbu horizontal accelerometer (x/y saat HP tegak, fallback x/z saat datar). Deviasi dari heading awal sesi:

```
maxHeadingDeviationDeg = max |heading - heading_offset|
```

Penalti balance jika > 45 deg (-5 poin). Tidak difusion dengan gyro; hanya untuk orientasi arah dan insight UI.

### Balance score

```
balance = clamp(0, 100 - sum(penalties))
```


| Kondisi                    | Penalti          |
| -------------------------- | ---------------- |
| Fall confirmed             | -35 per kejadian |
| Impact                     | -12 per kejadian |
| max SVM > 30               | -8               |
| max SVM > 25               | -5               |
| max AVM > 200 deg/s        | -8               |
| heading deviation > 45 deg | -5               |
| tilt > 60 deg              | -5               |




### Speech score (backend, prioritas)

Penalti dari deviasi baseline akustik, risiko disartria/afasia, rasio durasi bicara, dan rekaman SOS (-6 per segmen, max -12). Fallback lokal mobile jika pipeline offline.

### Overall and risk

```
overall = round(balance * 0.65 + speech * 0.35)
```

**HIGH** jika: fall > 0, overall < 45, balance < 50, impact >= 3 dengan balance < 60, atau dysarthria/aphasia high (dan kombinasi medium + bukti klinis).

**MEDIUM** jika: overall < 70, impact > 0, max SVM > 25, atau speech medium.

**LOW** selain kondisi di atas.

### Disfluensi (fluency)

Deteksi burst suku kata pendek (<= 120 ms) + micro-pause (20-100 ms) berulang. SOS high jika >= 4 stutter-pause atau >= 3 dengan rate >= 2/detik.

## Quick start



### Backend

```bash
cd backend
uv sync
cp .env.example .env
docker compose up -d   # optional: postgres + redis
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API docs: [http://localhost:8000/docs](http://localhost:8000/docs)

Detail: [backend/README.md](./backend/README.md)

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

Atur alamat server di Pengaturan aplikasi jika backend tidak di localhost. Gunakan perangkat fisik untuk sensor, mikrofon, dan GPS.

Detail: [mobile/README.md](./mobile/README.md)

### Tests

```bash
# backend
cd backend && uv run pytest -q

# mobile
cd mobile && flutter test
```



## Project structure

```
stroketion/
├── backend/          FastAPI, speech pipeline, tests
├── mobile/           Flutter app (pasien + caregiver)
├── LICENSE           MIT
└── README.md
```



## Disclaimer

Stroketion memberikan indikator berbasis sensor dan analisis sinyal. Hasil bukan diagnosis medis. Keputusan klinis tetap pada tenaga kesehatan profesional.

## License

[MIT](./LICENSE)