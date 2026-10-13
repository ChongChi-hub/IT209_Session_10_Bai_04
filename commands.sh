#!/usr/bin/env bash
# ==============================================================================
# BÀI TẬP 4: Thiết lập Custom Network & Named Volume bằng Docker CLI
# Sinh viên: Đào Trọng Trí - PTIT062
# ==============================================================================

set -e

echo "=== BƯỚC 1: TẠO CUSTOM BRIDGE NETWORK VÀ NAMED VOLUME ==="
# 1.1. Tạo Custom Bridge Network tên 'app-net'
docker network inspect app-net >/dev/null 2>&1 || docker network create --driver bridge app-net
echo "[✓] Tạo Custom Bridge Network: app-net"

# 1.2. Tạo Named Volume tên 'db-data'
docker volume inspect db-data >/dev/null 2>&1 || docker volume create db-data
echo "[✓] Tạo Named Volume: db-data"

echo ""
echo "=== BƯỚC 2: KHỞI CHẠY POSTGRESQL DATABASE CONTAINER (db-server) ==="
# Dọn dẹp container cũ nếu đang chạy
docker rm -f db-server >/dev/null 2>&1 || true

docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  -e POSTGRES_DB=mydb \
  postgres:15-alpine

echo "[✓] Container db-server đã khởi chạy và kết nối vào network app-net"

echo ""
echo "=== BƯỚC 3: KHỞI CHẠY BACKEND CONTAINER KẾT NỐI VÀO app-net ==="
# Dọn dẹp container app-container nếu có
docker rm -f app-container >/dev/null 2>&1 || true

docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=myuser \
  -e DB_PASSWORD=mypassword \
  -e DB_NAME=mydb \
  -p 8081:3000 \
  hw-backend:v1

echo "[✓] Container app-container đã khởi chạy và tham gia app-net"

echo ""
echo "=== BƯỚC 4: KIỂM TRA DNS RESOLUTION TRÊN CUSTOM NETWORK ==="
echo "Kiểm tra danh sách networks:"
docker network ls | grep app-net

echo "Kiểm tra danh sách volumes:"
docker volume ls | grep db-data

echo "Kiểm tra phân giải hostname db-server từ app-container:"
docker exec app-container ping -c 2 db-server

echo ""
echo "=== BƯỚC 5: TEST DATA PERSISTENCE TRÊN NAMED VOLUME ==="
echo "Chờ PostgreSQL sẵn sàng..."
until docker exec db-server pg_isready -U myuser -d mydb >/dev/null 2>&1; do
  sleep 1
done

echo "Tạo bảng 'users' và thêm dữ liệu kiểm thử vào PostgreSQL:"
docker exec -i db-server psql -U myuser -d mydb << 'EOF'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO users (username, email) VALUES 
('daotrongtri', 'trongtri@example.com'),
('devops_tester', 'tester@example.com');
EOF

echo "Dữ liệu hiện tại trong database:"
docker exec db-server psql -U myuser -d mydb -c "SELECT id, username, email, created_at FROM users;"

echo ""
echo "=== BƯỚC 6: XÓA CỨNG CONTAINER DB VÀ TÁI TẠO ĐỂ KIỂM CHỨNG LƯU TRỮ BỀN VỮNG ==="
echo "Đang xóa cứng container db-server (docker rm -f db-server)..."
docker rm -f db-server

echo "Khởi chạy container PostgreSQL mới gắn cùng volume db-data cũ..."
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  -e POSTGRES_DB=mydb \
  postgres:15-alpine

echo "Chờ PostgreSQL mới sẵn sàng..."
until docker exec db-server pg_isready -U myuser -d mydb >/dev/null 2>&1; do
  sleep 1
done

echo "Xác minh dữ liệu trong container mới (Data Persistence Verification):"
docker exec db-server psql -U myuser -d mydb -c "SELECT id, username, email, created_at FROM users;"

echo ""
echo "=== HOÀN TẤT BÀI 4 THÀNH CÔNG ==="
