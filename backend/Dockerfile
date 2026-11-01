# ============================================================================
# DOCKERFILE BACKEND (Node.js + Express REST API)
# ============================================================================
# 1. FROM: Pilih base image resmi Node.js versi 22 berbasis Alpine Linux
#    (Alpine sangat ringan, ukurannya hanya ~50MB dibanding image penuh ~350MB)
FROM node:22-alpine

# 2. WORKDIR: Tentukan folder kerja di dalam container
WORKDIR /app

# 3. COPY package*.json lebih dulu agar Docker bisa meng-cache layer npm install
#    (Kalau kode src/ berubah tapi package.json tidak berubah, build jadi super cepat!)
COPY package*.json ./

# 4. RUN: Install dependency produksi di dalam container
RUN npm install --omit=dev

# 5. COPY: Salin seluruh kode sumber aplikasi ke dalam container
COPY src ./src

# 6. ENV & EXPOSE: Set port default 4000 dan dokumentasikan bahwa container
#    mendengarkan di port 4000
ENV NODE_ENV=production
ENV PORT=4000
EXPOSE 4000

# 7. CMD: Perintah yang dijalankan saat container menyala
CMD ["node", "src/server.js"]
