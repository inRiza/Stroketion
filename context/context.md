Sistem Monitoring Stroke Berbasis AI

Problem Case

Stroke merupakan salah satu masalah kesehatan yang serius di Indonesia. Berdasarkan Survei Kesehatan Indonesia (SKI) 2023, prevalensi stroke di Indonesia mencapai 8,3 per 1.000 penduduk. Stroke juga menjadi salah satu penyebab utama kecacatan dan kematian di Indonesia.

Stroke merupakan kondisi yang membutuhkan penanganan cepat. Kementerian Kesehatan menggunakan metode BEFAST (Balance, Eyes, Face, Arm, Speech, Time) sebagai salah satu cara untuk mengenali gejala stroke secara awal. Gejala yang perlu diperhatikan antara lain wajah yang tidak simetris, kelemahan pada lengan, perubahan kemampuan berbicara, serta pentingnya segera mencari pertolongan medis.

Masalahnya, metode BEFAST pada umumnya dilakukan ketika seseorang atau orang di sekitarnya menyadari adanya perubahan secara langsung.

Hal ini menjadi masalah ketika seseorang mengalami gejala stroke saat:

Sedang sendirian di rumah.

Tidak ada caregiver di dekatnya.

Tidak menyadari bahwa gerakan tubuhnya berubah.

Mengalami perubahan bicara tetapi tidak menyadarinya.

Caregiver baru mengetahui kondisi tersebut setelah perubahan menjadi lebih parah.

Akibatnya, terdapat observation gap antara saat perubahan perilaku mulai terjadi dengan saat caregiver mengetahui kondisi tersebut.

Sistem yang diusulkan bertujuan untuk mengurangi observation gap tersebut dengan melakukan monitoring perilaku pengguna secara terus-menerus.

Sistem tidak menggantikan dokter dan tidak digunakan untuk memberikan diagnosis stroke.

Sistem berfungsi sebagai early warning system yang membantu mendeteksi perubahan perilaku yang mencurigakan dan memberikan informasi kepada caregiver agar dapat mengambil tindakan lebih cepat.



Solution

Solusi yang diusulkan adalah AI-powered home monitoring system yang memantau perubahan perilaku pengguna melalui dua kategori utama:

Motion Behaviour

Speech Behaviour

Kedua kategori tersebut dianalisis berdasarkan perubahan perilaku pengguna dari waktu ke waktu.

Konsep utama sistem adalah:

BALANCE + SPEECH + TIME

Konsep ini terinspirasi dari prinsip BEFAST untuk pengenalan gejala stroke, tetapi disesuaikan dengan kebutuhan sistem monitoring berbasis AI.

Balance

Balance merepresentasikan perilaku gerakan tubuh pengguna.

Sistem memonitor perubahan seperti:

Keseimbangan tubuh.

Pola berjalan.

Kecepatan berjalan.

Gerakan tangan.

Perbedaan gerakan antara sisi kiri dan kanan tubuh.

Perubahan pola gerakan dari kondisi normal pengguna.

Balance digunakan untuk menangkap perubahan fisik yang dapat terlihat melalui perilaku gerakan pengguna.

Contoh:

Normal:
- Berjalan stabil
- Gerakan tangan relatif simetris
- Postur tubuh stabil

Perubahan:
- Jalan menjadi tidak stabil
- Salah satu tangan lebih sedikit bergerak
- Gerakan kiri dan kanan menjadi tidak simetris



Speech

Speech merepresentasikan perilaku berbicara pengguna.

Sistem menganalisis perubahan karakteristik suara dan ucapan pengguna, seperti:

Kecepatan berbicara.

Durasi berbicara.

Durasi jeda.

Pitch.

Energi suara.

Kejelasan ucapan.

Pengucapan.

Pengulangan kata.

Perubahan pola bicara.

Perubahan speech kemudian dibandingkan dengan pola bicara normal pengguna.

Contoh:

Normal:
Pengguna berbicara dengan kecepatan
dan pola yang relatif konsisten.

Perubahan:
- Bicara menjadi lebih lambat
- Banyak jeda
- Ucapan menjadi kurang jelas
- Kesulitan mengucapkan kata

Kementerian Kesehatan menjelaskan bahwa perubahan bicara seperti menjadi sulit, tidak jelas, atau tidak dapat berbicara merupakan salah satu tanda yang perlu diperhatikan dalam FAST.



Time

Time bukan sensor dan bukan modality.

Time merupakan temporal intelligence layer yang digunakan untuk memahami perubahan perilaku berdasarkan waktu.

Sistem tidak hanya melihat:

"Apakah gerakan atau bicara pengguna abnormal?"

Tetapi juga:

"Kapan perubahan tersebut mulai terjadi?"

dan:

"Bagaimana perubahan tersebut berkembang dari waktu ke waktu?"

Contoh:

10:00
Gerakan normal
Speech normal

10:30
Gerakan mulai berubah

10:35
Gerakan tangan kiri dan kanan mulai tidak simetris

10:40
Speech menjadi lebih lambat

10:45
Speech semakin tidak jelas

10:46
Sistem mendeteksi kombinasi perubahan
Motion + Speech

Informasi waktu yang penting:

Last Known Normal.

First Detected Abnormality.

Waktu terjadinya perubahan.

Durasi perubahan.

Urutan perubahan.

Detection Latency.

Konsep ini penting karena stroke merupakan kondisi yang sangat berkaitan dengan waktu. Kementerian Kesehatan menekankan bahwa semakin cepat gejala dikenali dan pasien mendapatkan pertolongan, semakin baik peluang penanganannya.

Time -> ini diambil dari tracking user berdasarkan motion anomaly dan anomaly detection lainnya yang mentrigger kapan ternyata diduga penyakit ini kambuh/aktif, lalu menghitung berapa lama waktu semenjak caregiver berhasil menangani pasien. 



Hubungan dengan BEFAST

Protokol yang umum digunakan untuk mengenali gejala stroke adalah:

B - Balance
E - Eyes
F - Face
A - Arm
S - Speech
T - Time

Sistem ini mengambil prinsip tersebut dan memfokuskan implementasinya pada bagian yang paling relevan untuk monitoring perilaku secara otomatis.

BEFAST
 |
 ├── Balance
 |
 ├── Eyes
 │
 ├── Face
 │
 ├── Arm ──────────┐
 │                 │
 ├── Speech ───────┤
 │                 │
 └── Time ─────────┘
                   │
                   ▼
           Sistem Monitoring
                   │
          ┌────────┴────────┐
          ▼                 ▼
      Balance            Speech
          │                 │
          └────────┬────────┘
                   ▼
                  Time
                   │
                   ▼
          Behaviour Analysis

Dalam sistem:

Arm menjadi bagian dari analisis Motion Behaviour.

Balance digunakan untuk memperluas pemantauan terhadap perilaku gerakan tubuh.

Speech digunakan sebagai kategori perilaku berbicara.

Time digunakan sebagai lapisan temporal untuk mengetahui kapan dan bagaimana perubahan terjadi. Poinnya time ini juga dijadikan sebagai penggabung indikasi apabila semua monitoring itu berjalan bersamaan atau tidak (closely related atau tidak).

Dengan demikian:

Motion Behaviour
      +
Speech Behaviour
      +
Temporal Analysis
      ↓
Behaviour Change Detection



Personal Baseline

Setiap orang memiliki pola gerakan dan pola bicara yang berbeda.

Karena itu, sistem tidak menggunakan satu standar "normal" yang sama untuk semua orang.

Sistem terlebih dahulu membuat personal baseline.

Contoh:

Personal Baseline

Motion:
- Kecepatan berjalan normal
- Pola langkah normal
- Gerakan tangan normal
- Keseimbangan normal

Speech:
- Kecepatan bicara normal
- Pitch normal
- Durasi jeda normal
- Pola pengucapan normal

Setelah baseline terbentuk, sistem membandingkan perilaku terbaru dengan baseline tersebut.

Current Behaviour
        ↓
Personal Baseline
        ↓
Behaviour Difference
        ↓
Anomaly Score

Tujuannya adalah mendeteksi perubahan dari kebiasaan pengguna sendiri, bukan sekadar membandingkan pengguna dengan populasi umum.



Motion Behaviour Monitoring

Monitoring gerakan dapat menggunakan kombinasi:

Camera
Pose Estimation
Accelerometer
Gyroscope

Untuk sistem berbasis kamera, pose estimation digunakan untuk memperoleh posisi bagian tubuh.

Contoh:

Head
Shoulder
Elbow
Wrist
Hip
Knee
Ankle

Data tersebut kemudian digunakan untuk menganalisis:

Postur.

Keseimbangan.

Gerakan tangan.

Pola berjalan.

Simetri gerakan.

Perubahan gerakan dari waktu ke waktu.

Contoh alur:

Camera
   ↓
Pose Estimation
   ↓
Body Landmarks
   ↓
Motion Feature Extraction
   ↓
Motion Behaviour Score



Speech Behaviour Monitoring

Speech monitoring menggunakan pipeline:

Microphone
    ↓
Voice Activity Detection
    ↓
Noise Reduction
    ↓
Speech Segmentation
    ↓
Speech Analysis
    ↓
Feature Extraction
    ↓
Speech Behaviour Score

Fitur yang dapat digunakan:

Speech Rate
Pause Duration
Pitch
Energy
Speaking Duration
Articulation Timing
Pronunciation
Repetition
Speech Intelligibility

Sistem kemudian membandingkan fitur tersebut dengan personal baseline pengguna.



Behaviour Change Detection

Motion dan Speech tidak dianalisis secara terpisah saja.

Sistem menggabungkan keduanya untuk mendapatkan gambaran perubahan perilaku yang lebih lengkap.

Motion Behaviour
       │
       ▼
Motion Score
       │
       ├──────────────┐
       │              │
       ▼              ▼
Speech Behaviour    Time
       │              │
       ▼              │
Speech Score ────────┘
       │
       ▼
Behaviour Analysis
       │
       ▼
Risk Assessment

Contoh:

Motion:
Perubahan keseimbangan terdeteksi.

Speech:
Kecepatan bicara menurun dan ucapan
menjadi kurang jelas.

Time:
Kedua perubahan terjadi dalam
periode waktu yang berdekatan.

Result:
Behaviour Change Score meningkat.

Sistem kemudian menentukan apakah kondisi tersebut cukup signifikan untuk menghasilkan alert.



Risk Assessment

Sistem dapat menggunakan tiga level sederhana:

LOW

Tidak terdapat perubahan signifikan dari personal baseline.

Motion: Normal
Speech: Normal
Time: Normal

Risk: LOW

Sistem tetap melakukan monitoring.

MEDIUM

Terdapat perubahan perilaku yang cukup signifikan tetapi belum cukup kuat untuk menghasilkan alert darurat.

Motion: Slight Change
Speech: Normal
Time: Short Duration

Risk: MEDIUM

Sistem dapat melakukan monitoring lebih intensif atau meminta verifikasi dari pengguna.

HIGH

Terdapat kombinasi perubahan Motion dan Speech yang signifikan dalam periode waktu tertentu.

Motion: Significant Change
Speech: Significant Change
Time: Closely Related

Risk: HIGH

Sistem mengirimkan alert kepada caregiver.

Risk level merupakan hasil analisis sistem dan bukan diagnosis medis.



Caregiver Monitoring

Salah satu fungsi utama sistem adalah memberikan monitoring dan tracking perilaku pengguna kepada caregiver.

Caregiver dapat melihat kondisi pengguna melalui aplikasi.

Contoh dashboard:

USER STATUS

Motion       : Abnormal
Speech       : Abnormal
Risk Level   : HIGH

Last Known Normal:
10:00

First Detected Change:
10:30

Latest Event:
10:45

Caregiver juga dapat melihat timeline:

10:00
Normal

10:30
Motion change detected

10:35
Arm movement asymmetry detected

10:40
Speech change detected

10:45
High-risk behaviour detected

Dengan demikian, caregiver tidak hanya menerima notifikasi bahwa terjadi sesuatu, tetapi juga dapat memahami:

Apa yang berubah.

Kapan perubahan terjadi.

Berapa lama perubahan berlangsung.

Perubahan terjadi pada motion atau speech.

Bagaimana kondisi berkembang dari waktu ke waktu.



Sistem Monitoring

Secara keseluruhan, sistem bekerja seperti berikut:

                USER
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
     MOTION              SPEECH
        │                   │
        ▼                   ▼
Motion Features       Speech Features
        │                   │
        └─────────┬─────────┘
                  ▼
          Personal Baseline
                  │
                  ▼
       Behaviour Comparison
                  │
                  ▼
              TIME
       Temporal Intelligence
                  │
                  ▼
          Behaviour Analysis
                  │
                  ▼
          Risk Assessment
                  │
          ┌───────┴───────┐
          ▼               ▼
        Normal           Alert
                          │
                          ▼
                   Caregiver App



Teknologi yang Digunakan

Mobile Application

Aplikasi dapat menggunakan:

Flutter
Dart

Flutter digunakan untuk membangun:

User Mobile App.

Caregiver Mobile App.

Alternatif:

React Native
TypeScript



Motion AI

Teknologi yang dapat digunakan:

Pose Estimation
Computer Vision
Accelerometer
Gyroscope

Model computer vision dapat digunakan untuk memperoleh body landmarks dan menganalisis pergerakan pengguna.



Speech AI

Teknologi yang dapat digunakan:

Voice Activity Detection
Speech Recognition
Audio Processing
Speech Feature Extraction
ASR

Model seperti speech-to-text atau speech encoder dapat digunakan sebagai bagian dari analisis speech behaviour.



AI / Machine Learning

Teknologi:

Python
PyTorch
scikit-learn
ONNX
ONNX Runtime

Untuk menganalisis pola perilaku berdasarkan waktu dapat digunakan model seperti:

LSTM
GRU
TCN
Transformer

Untuk MVP, model temporal yang lebih sederhana dapat digunakan terlebih dahulu.



Backend

Backend dapat menggunakan:

Python
FastAPI
PostgreSQL
Redis

Backend bertanggung jawab terhadap:

Authentication.

User management.

Caregiver management.

Personal baseline.

Behaviour history.

Event storage.

Risk events.

Data synchronization.

Notification management.



Notification

Notifikasi caregiver dapat menggunakan:

Firebase Cloud Messaging (FCM)

Contoh:

HIGH RISK BEHAVIOUR DETECTED

Perubahan signifikan pada motion
dan speech behaviour terdeteksi.

First detected:
10:30

Latest event:
10:45



On-Device dan Backend Processing

Untuk mengurangi latency dan menjaga privasi, beberapa proses dapat dilakukan langsung pada perangkat pengguna.

On-Device

Motion Detection
Speech Detection
Feature Extraction
Initial Behaviour Analysis

Backend

User Data
Behaviour History
Baseline Management
Event Storage
Caregiver Synchronization
Notifications
Analytics

Arsitektur:

             USER DEVICE
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
   Motion AI            Speech AI
        │                   │
        └─────────┬─────────┘
                  ▼
          Behaviour Analysis
                  │
                  ▼
              Backend
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
     Database          Notification
        │                   │
        └─────────┬─────────┘
                  ▼
           CAREGIVER APP



Protokol Sistem

Protokol sistem dapat diringkas menjadi:

BALANCE
   ↓
Monitor movement and balance behaviour

SPEECH
   ↓
Monitor speech behaviour

TIME
   ↓
Track when behavioural changes occur

BALANCE + SPEECH + TIME
   ↓
Compare with personal baseline
   ↓
Detect behavioural change
   ↓
Calculate risk level
   ↓
Notify caregiver

Konsep ini tetap mengikuti prinsip utama FAST, yaitu mengenali tanda yang mencurigakan dan bertindak cepat, tetapi sistem mengimplementasikannya sebagai monitoring perilaku berbasis AI.

FAST
Face + Arm + Speech + Time
             ↓
       Stroke Awareness
             ↓
   ┌─────────┴─────────┐
   ▼                   ▼
MOTION              SPEECH
   │                   │
   └─────────┬─────────┘
             ▼
            TIME
             │
             ▼
   Behaviour Monitoring
             │
             ▼
    Caregiver Early Alert

Sistem ini bukan alat diagnosis stroke. Ketika terdapat gejala yang mengarah pada stroke, tujuan sistem adalah membantu mempercepat kesadaran dan respons caregiver agar pengguna dapat segera memperoleh pertolongan medis. Kementerian Kesehatan menekankan bahwa gejala stroke merupakan keadaan darurat dan pasien perlu segera dibawa ke fasilitas kesehatan.

Inti Solusi

Problem:
Caregiver tidak dapat mengawasi pengguna
setiap saat, terutama ketika pengguna
sendirian di rumah.

Solution:
AI melakukan monitoring terhadap
Motion Behaviour dan Speech Behaviour.

Protocol:
BALANCE + SPEECH + TIME

Output:
Behaviour Change Detection
        ↓
Risk Assessment
        ↓
Caregiver Alert
        ↓
Early Medical Response