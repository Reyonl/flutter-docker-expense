# Quality Acceptance Engineering (QAE) Matrix — DompetKu Docker

## 1. Stack, Arsitektur & Integrasi
- **Frontend:** Flutter 3.47.5 (Web/Mobile/Desktop) disajikan melalui container **Nginx Alpine** (`expense-frontend`, Port `8080:80`).
- **Backend API:** Node.js 22 Alpine + Express REST API (`expense-backend`, Port `4000:4000`).
- **Database:** PostgreSQL 16 Alpine (`expense-db`, Port `5433:5432`) dengan persistent Docker Volume (`pgdata`) dan jaringan internal (`expense-net`).
- **External Integrations:** Tidak ada integrasi pihak ketiga berbayar; seluruh layanan berjalan terisolasi di dalam Docker containers lokal.

## 2. Acceptance Criteria Matrix

| ID | Layer | Mandatory | Acceptance Criterion | Expected Outcome | Evidence File |
|---|---|---|---|---|---|
| `EXP-001` | `integration` | Yes | Ketiga container (`expense-db`, `expense-backend`, `expense-frontend`) berstatus running/healthy dan `GET /api/health` mengembalikan `200 OK` | `status: "ok"`, `db: "connected"`, dan `containerId` terisi | `evidence/EXP-001-health.json` |
| `EXP-002` | `api` | Yes | Positive CRUD: `POST /api/transactions` menambah pemasukan & pengeluaran baru, dan `GET /api/summary` menghitung `totalIncome`, `totalExpense`, dan `balance` secara akurat | HTTP `201` saat create, HTTP `200` saat summary dengan perhitungan matematis tepat | `evidence/EXP-002-crud-summary.json` |
| `EXP-003` | `api` | Yes | Negative Validation: `POST /api/transactions` menolak nominal negatif/nol (`-5000`, `0`), judul kosong, atau tipe tidak valid (`"hutang"`) dengan HTTP `400` | HTTP `400 Bad Request` beserta daftar pesan error validasi | `evidence/EXP-003-negative-validation.json` |
| `EXP-004` | `database` | Yes | Database Persistence & Volume: Data transaksi benar-benar tersimpan di tabel PostgreSQL `transactions` di dalam container `expense-db` | Query langsung ke PostgreSQL mengonfirmasi baris tersimpan sesuai input | `evidence/EXP-004-db-persistence.json` |
| `EXP-005` | `security` | Yes | OWASP Security: Input dengan tag `<script>` (XSS) disanitasi dan percobaan SQL Injection pada parameter query/body ditangani dengan aman tanpa merusak tabel | Tag `<script>` dihapus dari field tersimpan dan tabel `transactions` tetap utuh | `evidence/EXP-005-security.json` |
| `EXP-006` | `unit` | Yes | Unit & Widget Tests: Backend (`npm run lint && npm test`) dan Frontend Flutter (`flutter analyze lib && flutter test`) lulus 100% | Exit code `0`, 0 kegagalan test | `evidence/EXP-006-unit-widget.json` |
| `EXP-007` | `e2e` | Yes | Browser E2E (Selenium WebDriver): Membuka aplikasi Flutter Web di container `http://localhost:8080`, memverifikasi render aplikasi & integrasi proxy `/api/summary`, tanpa console/network error, dan mengambil screenshot | Screenshot tersimpan (`evidence/EXP-007-selenium-ui.png`) dan laporan JSON E2E berstatus `PASS` | `evidence/EXP-007-selenium-e2e.json`, `evidence/EXP-007-selenium-ui.png` |
