# ============================================================================
# DOCKERFILE FRONTEND (Flutter Web + Nginx Alpine)
# ============================================================================
# Menggunakan image resmi Nginx berbasis Alpine Linux (~40MB) untuk menyajikan
# hasil kompilasi Flutter Web (build/web) dengan cepat dan efisien.
FROM nginx:alpine

# Salin konfigurasi Nginx kustom (mendukung SPA routing & reverse proxy /api)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Salin hasil build Flutter Web ke folder static web server Nginx
COPY build/web /usr/share/nginx/html

# Dokumentasikan port 80 di dalam container (akan di-mapping ke 8080 di laptop)
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
