# Panduan Belajar Docker v2.0 — Arsitektur 5-Container (Flutter Pro + Node.js + Postgres + Redis + Adminer)

Selamat datang di **DompetKu Docker v2.0**! Sekarang aplikasi Money Expense Tracker kamu sudah naik level menjadi arsitektur **5-Container** seperti yang dipakai oleh aplikasi Startup / Fintech sungguhan.

---

## 1. Peta 5 Container di Proyek Ini

| No | Nama Container | Image | Port di Laptop | Fungsi di Aplikasi |
|---|---|---|---|---|
| 1 | `expense-frontend` | `nginx:alpine` + Flutter Web | **http://localhost:8080** | Tampilan Dashboard Fintech Pro (Donut Chart, Cashflow Chart, Edit Transaksi) |
| 2 | `expense-backend` | `node:22-alpine` + Express | **http://localhost:4000** | REST API (`GET`, `POST`, `PUT`, `DELETE`) yang menghubungkan Flutter ke Postgres & Redis |
| 3 | `expense-db` | `postgres:16-alpine` | `localhost:5433` | Database utama tempat menyimpan tabel transaksi secara permanen (`Volume: pgdata`) |
| 4 | `expense-redis` | `redis:7-alpine` | `localhost:6379` | **In-Memory Cache** super cepat untuk menyimpan hasil kalkulasi saldo (`Redis: HIT / MISS`) |
| 5 | `expense-adminer` | `adminer:latest` | **http://localhost:8081** | **Database Web GUI** untuk melihat & mengedit isi tabel PostgreSQL lewat browser |

---

## 2. Eksperimen Seru yang Bisa Langsung Kamu Coba Sekarang!

### Eksperimen 1: Melihat Cara Kerja Redis Cache (`MISS` vs `HIT`) di UI Flutter
1. Buka **http://localhost:8080** di browser.
2. Lihat badge di bagian atas:
   - Saat kamu baru saja **Tambah**, **Edit**, atau **Hapus** transaksi, atau klik ikon **Sapu (`Flush Redis Cache`)** di pojok kanan atas, badge akan bertuliskan **`Redis: MISS`** (warna kuning/oranye). Artinya: Backend harus menghitung ulang saldo dari database PostgreSQL, lalu menyimpan hasilnya ke container `expense-redis`.
   - Sekarang klik tombol **Refresh (`Muat Ulang Data`)** di pojok kanan atas! Badge langsung berubah menjadi **`Redis: HIT`** (warna hijau). Artinya: Data diambil instan dari RAM container `expense-redis` tanpa membebani PostgreSQL!

### Eksperimen 2: Membuka Database Lewat Browser dengan Container `Adminer`
1. Buka **http://localhost:8081** di browser.
2. Masukkan kredensial berikut (bisa dilihat juga dengan klik ikon Database di pojok kanan atas aplikasi Flutter):
   - **System:** `PostgreSQL`
   - **Server:** `db` *(perhatikan kita menulis `db`, bukan `localhost`, karena container Adminer memanggil container Postgres lewat jaringan internal Docker `expense-net`!)*
   - **Username:** `dompetku`
   - **Password:** `dompetku_secret`
   - **Database:** `dompetku_db`
3. Klik **Login** → klik tabel **`transactions`** → klik **Select data**. Kamu bisa melihat seluruh transaksi yang kamu input dari Flutter secara langsung!

### Eksperimen 3: Mengintip Isi Memori Redis Lewat Terminal
Penasaran seperti apa data yang disimpan di dalam container `expense-redis`? Jalankan perintah ini di terminal:
```powershell
docker exec -it expense-redis redis-cli KEYS *
docker exec -it expense-redis redis-cli GET dompetku:summary:v2
```
Kamu akan melihat JSON ringkasan saldo yang sedang di-cache oleh Redis!
