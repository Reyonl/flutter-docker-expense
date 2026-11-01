# Panduan Belajar Docker — Studi Kasus: DompetKu (Flutter + Node.js + PostgreSQL)

Selamat datang di proyek latihan Docker! Di proyek ini kita membangun aplikasi **Money Expense Tracker (DompetKu)** yang terdiri dari **3 Container** yang saling terhubung.

---

## 1. Memahami 5 Konsep Inti Docker lewat Proyek Ini

| Konsep Docker | Analogi Sederhana | Implementasi di Proyek DompetKu |
|---|---|---|
| **Dockerfile** | Resep masakan / cetak biru aplikasi | [`backend/Dockerfile`](./backend/Dockerfile) dan [`frontend/Dockerfile`](./frontend/Dockerfile) |
| **Image** | Paket instalasi siap pakai (hasil dari `Dockerfile`) | `flutter-docker-expense-backend`, `flutter-docker-expense-frontend`, `postgres:16-alpine` |
| **Container** | Aplikasi yang sedang berjalan dari sebuah Image | `expense-db`, `expense-backend`, `expense-frontend` |
| **Volume** | Harddisk eksternal agar data tidak hilang saat container dihapus | `pgdata` (menyimpan tabel transaksi PostgreSQL secara permanen) |
| **Network** | Kabel LAN virtual agar antar-container bisa saling panggil nama | `expense-net` (membuat `backend` bisa memanggil database cukup dengan `DB_HOST: db`) |

---

## 2. Bedah `backend/Dockerfile` (Baris demi Baris)

Buka file [`backend/Dockerfile`](./backend/Dockerfile):
```dockerfile
FROM node:22-alpine          # 1. Ambil sistem operasi Linux Alpine + Node.js 22
WORKDIR /app                 # 2. Masuk ke folder /app di dalam container
COPY package*.json ./        # 3. Salin daftar library lebih dulu (supaya ter-cache!)
RUN npm install --omit=dev   # 4. Install Express & PostgreSQL driver di dalam container
COPY src ./src               # 5. Salin kodingan REST API kita
ENV PORT=4000                # 6. Set environment variable PORT=4000
EXPOSE 4000                  # 7. Dokumentasikan port container
CMD ["node", "src/server.js"]# 8. Perintah utama saat container dinyalakan
```

> **Kenapa `COPY package*.json` dipisah sebelum `COPY src`?**
> Docker bekerja menggunakan **Layer Caching**. Kalau kamu hanya mengubah kode di `src/app.js` tanpa menambah library baru di `package.json`, Docker tidak akan mengulang `npm install` saat `docker compose build`. Proses build jadi selesai dalam hitungan 1 detik!

---

## 3. Bedah `docker-compose.yml` (Multi-Container Orchestration)

Daripada menjalankan 3 perintah `docker run ...` yang panjang satu per satu, kita memakai [`docker-compose.yml`](./docker-compose.yml):
1. **`db` (`postgres:16-alpine`)**:
   - Port Mapping `"5433:5432"` → Port `5432` di dalam container dipetakan ke port `5433` di laptop kamu.
   - Volume `pgdata:/var/lib/postgresql/data` → Menjamin saldo & riwayat transaksi tetap ada walaupun container dimatikan (`docker compose down`).
2. **`backend` (`./backend/Dockerfile`)**:
   - Memakai `DB_HOST: db` karena di dalam jaringan Docker (`expense-net`), nama service otomatis menjadi alamat DNS!
   - `depends_on: db (condition: service_healthy)` → Backend pintar menunggu sampai PostgreSQL benar-benar siap menerima koneksi sebelum menyala.
3. **`frontend` (`./frontend/Dockerfile`)**:
   - Menyajikan aplikasi **Flutter Web** menggunakan **Nginx Alpine** di `http://localhost:8080`.
   - File [`frontend/nginx.conf`](./frontend/nginx.conf) meneruskan (*reverse proxy*) semua panggilan `/api/*` langsung ke `http://backend:4000/api/*`.

---

## 4. Perintah-Perintah Docker yang Wajib Kamu Coba Sendiri

Buka terminal di folder proyek ini, lalu coba perintah berikut satu per satu:

### A. Melihat Container yang Sedang Jalan
```powershell
docker ps
```

### B. Melihat Log Real-Time dari Container
```powershell
# Melihat log semua container
docker compose logs -f

# Melihat log backend Node.js saja
docker compose logs -f backend
```

### C. Masuk ke Dalam Container Database PostgreSQL
```powershell
docker exec -it expense-db psql -U dompetku -d dompetku_db -c "SELECT id, title, amount, type, category FROM transactions;"
```

### D. Membuktikan Fungsi Docker Volume (Data Tidak Hilang!)
```powershell
# 1. Matikan dan hapus semua container
docker compose down

# 2. Nyalakan kembali semua container
docker compose up -d

# 3. Buka http://localhost:8080 — semua transaksi kamu masih utuh!
```
*(Catatan: Data hanya akan terhapus jika kamu sengaja menambahkan flag `-v`: `docker compose down -v`).*

### E. Menjalankan Flutter Secara Lokal (Mode Development) Sambil Backend di Docker
Kalau kamu sedang mengedit UI Flutter di `frontend/lib/main.dart` dan ingin memakai *Hot Reload*:
```powershell
cd frontend
flutter run -d chrome
```
Aplikasi Flutter lokal akan otomatis terhubung ke container `expense-backend` di `http://localhost:4000/api`!
