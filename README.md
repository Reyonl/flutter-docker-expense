# DompetKu Docker — Flutter Money Expense + Node.js API + PostgreSQL

Proyek pembelajaran **Docker dari Nol sampai Multi-Container (`Docker Compose`)** menggunakan aplikasi pencatat keuangan (**Money Expense Tracker**).

## Arsitektur Container
1. **`expense-db` (PostgreSQL 16 Alpine)** — Menyimpan transaksi keuangan secara permanen dengan **Docker Volume** (`pgdata`).
2. **`expense-backend` (Node.js + Express REST API)** — Backend API di dalam container tersendiri (`backend/Dockerfile`) yang terhubung ke database lewat **Docker Network** (`expense-net`).
3. **`expense-frontend` (Flutter Web + Nginx Alpine)** — Aplikasi UI Flutter Money Expense yang di-serve melalui container Nginx (`frontend/Dockerfile`) dan meneruskan request `/api/*` ke container backend.
