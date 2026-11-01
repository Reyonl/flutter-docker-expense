# Panduan Belajar Docker & Firebase Cloud v2.5 — Arsitektur 5-Container + Serverless Cloud DB (`dompetku-4a2e1`)

Selamat datang di **DompetKu Docker Pro v2.5**! Sekarang aplikasi Money Expense Tracker kamu mendukung **Arsitektur Hybrid**:
1. **Mode 🐳 Docker Stack (5-Container):** Untuk belajar ekosistem backend microservices lokal (`Flutter Web + Nginx`, `Node.js Express`, `PostgreSQL 16`, `Redis 7 Cache`, dan `Adminer DB GUI`).
2. **Mode 🔥 Firebase Cloud (`dompetku-4a2e1`):** Database Cloud Firestore (`asia-southeast2`) gratis dari Google tanpa perlu menyewa VPS, sehingga aplikasi bisa langsung dipakai di **Android APK** maupun **Web Produksi** dari mana saja!

---

## 1. Peta 5 Container Docker + 1 Cloud Database

| No | Nama Layanan | Image / Engine | Endpoint / Port | Fungsi di Aplikasi |
|---|---|---|---|---|
| 1 | `expense-frontend` | `nginx:alpine` + Flutter Web | **http://localhost:8080** | Tampilan Dashboard Fintech Pro (Donut Chart, Cashflow Chart, Edit Transaksi, Engine Switcher) |
| 2 | `expense-backend` | `node:22-alpine` + Express | **http://localhost:4000** | REST API (`GET`, `POST`, `PUT`, `DELETE`) yang menghubungkan Flutter ke Postgres & Redis |
| 3 | `expense-db` | `postgres:16-alpine` | `localhost:5433` | Database utama Docker tempat menyimpan tabel transaksi secara permanen (`Volume: pgdata`) |
| 4 | `expense-redis` | `redis:7-alpine` | `localhost:6379` | **In-Memory Cache** super cepat untuk menyimpan hasil kalkulasi saldo (`Redis: HIT / MISS`) |
| 5 | `expense-adminer` | `adminer:latest` | **http://localhost:8081** | **Database Web GUI** untuk melihat & mengedit isi tabel PostgreSQL lewat browser |
| 6 | **Firebase Cloud** | Google Cloud Firestore | Project: **`dompetku-4a2e1`** | **Serverless Cloud Database** (`asia-southeast2`) untuk mode produksi Android/Web tanpa sewa VPS |

---

## 2. Eksperimen Seru yang Bisa Langsung Kamu Coba Sekarang!

### Eksperimen 1: Berpindah antara `🐳 Docker Stack` & `🔥 Firebase Cloud` + Sync 1-Klik
1. Buka **http://localhost:8080** di browser.
2. Di bar bagian atas, kamu akan melihat tombol:
   - **`🐳 Docker Stack`**: Menggunakan server lokal Docker (PostgreSQL + Redis Cache).
   - **`🔥 Firebase Cloud (dompetku-4a2e1)`**: Menggunakan database Cloud Firestore milikmu secara langsung.
   - **`Sync Docker ➔ Firebase`**: Klik tombol ini untuk menyalin seluruh transaksi dari database Docker PostgreSQL langsung ke Cloud Firestore `dompetku-4a2e1`!
3. Setelah klik **Sync Docker ➔ Firebase**, coba tambah/edit/hapus transaksi di mode **Firebase Cloud**, lalu buka **Firebase Console → Firestore Database (`dompetku-4a2e1`)** — datanya langsung berubah secara real-time di server Google!

### Eksperimen 2: Melihat Cara Kerja Redis Cache (`MISS` vs `HIT`) di UI Flutter
1. Pilih mode **`🐳 Docker Stack`**.
2. Saat kamu baru saja **Tambah**, **Edit**, atau **Hapus** transaksi, atau klik ikon **Sapu (`Flush Redis Cache`)** di pojok kanan atas, badge akan bertuliskan **`Redis: MISS`** (warna kuning/oranye).
3. Klik tombol **Refresh (`Muat Ulang Data`)** di pojok kanan atas! Badge langsung berubah menjadi **`Redis: HIT`** (warna hijau).

### Eksperimen 3: Membuka Database Lewat Browser dengan Container `Adminer`
1. Buka **http://localhost:8081** di browser.
2. Masukkan kredensial berikut:
   - **System:** `PostgreSQL`
   - **Server:** `db`
   - **Username:** `dompetku`
   - **Password:** `dompetku_secret`
   - **Database:** `dompetku_db`
