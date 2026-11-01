# Quality Acceptance Engineering (QAE) Matrix v2.0 — DompetKu Docker Pro (5-Container Stack)

## 1. Stack, Arsitektur 5-Container & Integrasi
- **Container 1 (`expense-db`):** PostgreSQL 16 Alpine (`Port 5433:5432`) dengan persistent Docker Volume (`pgdata`).
- **Container 2 (`expense-redis`):** Redis 7 Alpine (`Port 6379:6379`) untuk in-memory caching `/api/summary` (`HIT` / `MISS` + auto-invalidation saat mutasi data).
- **Container 3 (`expense-adminer`):** Adminer Database Web GUI (`Port 8081:8080`) terhubung ke `db`.
- **Container 4 (`expense-backend`):** Node.js 22 Alpine + Express REST API v2.0 (`Port 4000:4000`) mendukung CRUD + Edit (`PUT /api/transactions/:id`) + Redis Cache Flush (`POST /api/cache/flush`).
- **Container 5 (`expense-frontend`):** Flutter Web v2.0 (Donut Chart, Cashflow Bar Chart, Redis Telemetry, Edit Transaksi) disajikan melalui Nginx Alpine (`Port 8080:80`).

## 2. Acceptance Criteria Matrix (v2.0)

| ID | Layer | Mandatory | Acceptance Criterion | Expected Outcome | Evidence File |
|---|---|---|---|---|---|
| `EXP-001` | `integration` | Yes | Kelima container (`expense-db`, `expense-redis`, `expense-adminer`, `expense-backend`, `expense-frontend`) running/healthy & `GET /api/health` → `200 OK` | `status: "ok"`, `db: "connected"`, `redis: "connected"` | `evidence/EXP-001-health.json` |
| `EXP-002` | `api` | Yes | Positive CRUD: `POST /api/transactions` menambah pemasukan & pengeluaran baru, dan `GET /api/summary` menghitung saldo secara akurat | HTTP `201` saat create, HTTP `200` saat summary | `evidence/EXP-002-crud-summary.json` |
| `EXP-003` | `api` | Yes | Negative Validation: `POST` & `PUT /api/transactions` menolak nominal `<= 0`, judul kosong, atau tipe salah (`HTTP 400`), serta ID tidak ada (`HTTP 404`) | HTTP `400` dan `404` sesuai kontrak validasi | `evidence/EXP-003-negative-validation.json` |
| `EXP-004` | `database` | Yes | Database Persistence & Volume: Data transaksi di PostgreSQL bertahan saat container `expense-backend` di-restart | Jumlah dan total transaksi identik sebelum & sesudah restart | `evidence/EXP-004-db-persistence.json` |
| `EXP-005` | `security` | Yes | OWASP Security: Sanitasi tag `<script>` (XSS) pada input transaksi & ketahanan parameter terhadap SQL Injection | Tag `<script>` dibersihkan dan tabel tetap utuh | `evidence/EXP-005-security.json` |
| `EXP-006` | `unit` | Yes | Unit & Widget Tests: Backend (`npm run lint && npm test`) dan Flutter (`flutter analyze lib && flutter test`) lulus 100% (termasuk Edit & Charts) | Exit code `0`, 0 kegagalan test | `evidence/EXP-006-unit-widget.json` |
| `EXP-007` | `e2e` | Yes | Browser E2E (Selenium WebDriver): Membuka `http://localhost:8080`, menguji alur Create + Edit + Redis HIT/MISS dari browser, dan mengambil screenshot | Screenshot tersimpan (`evidence/EXP-007-selenium-ui.png`) & status `PASS` | `evidence/EXP-007-selenium-e2e.json`, `evidence/EXP-007-selenium-ui.png` |
| `EXP-008` | `api` | Yes | Edit / Update Transaksi (`PUT /api/transactions/:id`): Mengubah judul, nominal, dan kategori transaksi yang sudah ada serta memperbarui saldo | HTTP `200 OK`, perubahan tersimpan di DB & mengubah nilai summary | `evidence/EXP-008-edit-transaction.json` |
| `EXP-009` | `integration` | Yes | Redis Cache (`MISS` → `HIT` → Invalidation) & Adminer Web GUI (`http://localhost:8081`): Verifikasi siklus cache Redis dan aksesibilitas halaman login Adminer | Summary pertama `MISS`, kedua `HIT`, pasca-flush `MISS`, dan Adminer `HTTP 200` | `evidence/EXP-009-redis-adminer.json` |
