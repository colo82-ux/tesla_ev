#!/usr/bin/env bash
# ==============================================================================
# [테슬라_ev] 구글 클라우드(GCP e2-micro Ubuntu/Debian) 원클릭 자동 구축 스크립트
# ==============================================================================
set -e

echo "=== [1/4] 가상 메모리(Swap 2GB) 확인 및 설정 ==="
if [ ! -f /swapfile ]; then
  sudo fallocate -l 2G /swapfile </dev/null
  sudo chmod 600 /swapfile </dev/null
  sudo mkswap /swapfile </dev/null
  sudo swapon /swapfile </dev/null
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab </dev/null
  echo "Swap 2GB 생성 완료!"
else
  echo "Swap 파일이 이미 존재합니다."
fi

echo "=== [2/4] Docker 설치 확인 ==="
if ! command -v docker &> /dev/null; then
  sudo apt-get update </dev/null
  sudo apt-get install -y ca-certificates curl gnupg openssl </dev/null
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh </dev/null
  sudo usermod -aG docker "$USER" </dev/null || true
  echo "Docker 설치 완료!"
else
  echo "Docker가 이미 설치되어 있습니다."
fi

echo "=== [3/4] TeslaMate + TeslaMateAPI 폴더 및 보안 토큰 생성 ==="
mkdir -p ~/teslamate/import
cd ~/teslamate

if [ -f .env ]; then
  echo "기존 .env 보안 설정을 유지하고 DB 볼륨을 동기화합니다."
  source .env
  sudo docker compose down -v </dev/null || true
else
  TM_ENCRYPTION_KEY=$(openssl rand -hex 24)
  TM_DB_PASS=$(openssl rand -hex 16)
  TM_API_TOKEN=$(openssl rand -hex 20)

  cat <<EOF > .env
TM_ENCRYPTION_KEY=${TM_ENCRYPTION_KEY}
TM_DB_PASS=${TM_DB_PASS}
TM_API_TOKEN=${TM_API_TOKEN}
EOF
fi

cat <<'EOF' > docker-compose.yml
services:
  teslamate:
    image: teslamate/teslamate:latest
    restart: always
    environment:
      - ENCRYPTION_KEY=${TM_ENCRYPTION_KEY}
      - DATABASE_USER=teslamate
      - DATABASE_PASS=${TM_DB_PASS}
      - DATABASE_NAME=teslamate
      - DATABASE_HOST=database
      - MQTT_HOST=mosquitto
      - TZ=Asia/Seoul
    ports:
      - 4000:4000
    volumes:
      - ./import:/opt/app/import
    cap_drop:
      - all

  teslamateapi:
    image: tobiasehlert/teslamateapi:latest
    restart: always
    depends_on:
      - database
    environment:
      - ENCRYPTION_KEY=${TM_ENCRYPTION_KEY}
      - DATABASE_USER=teslamate
      - DATABASE_PASS=${TM_DB_PASS}
      - DATABASE_NAME=teslamate
      - DATABASE_HOST=database
      - MQTT_HOST=mosquitto
      - API_TOKEN=${TM_API_TOKEN}
      - ENABLE_COMMANDS=false
      - TZ=Asia/Seoul
    ports:
      - 8080:8080

  database:
    image: postgres:16
    restart: always
    environment:
      - POSTGRES_USER=teslamate
      - POSTGRES_PASSWORD=${TM_DB_PASS}
      - POSTGRES_DB=teslamate
      - POSTGRES_HOST_AUTH_METHOD=trust
    volumes:
      - teslamate-db:/var/lib/postgresql/data

  grafana:
    image: teslamate/grafana:latest
    restart: always
    environment:
      - DATABASE_USER=teslamate
      - DATABASE_PASS=${TM_DB_PASS}
      - DATABASE_NAME=teslamate
      - DATABASE_HOST=database
    ports:
      - 3000:3000
    volumes:
      - teslamate-grafana-data:/var/lib/grafana

  mosquitto:
    image: eclipse-mosquitto:2
    restart: always
    command: mosquitto -c /mosquitto-no-auth.conf
    volumes:
      - mosquitto-conf:/mosquitto/config
      - mosquitto-data:/mosquitto/data

volumes:
  teslamate-db:
  teslamate-grafana-data:
  mosquitto-conf:
  mosquitto-data:
EOF

echo "=== [4/4] TeslaMate 컨테이너 다운로드 및 실행 중... ==="
sudo docker compose up -d </dev/null

echo "컨테이너 초기화 대기 중 (10초)..."
sleep 10
sudo docker compose ps </dev/null

EXTERNAL_IP=$(curl -s ifconfig.me || echo "34.11.135.61")

echo ""
echo "=================================================================="
echo " 🎉 구글 클라우드 TeslaMate + TeslaMateAPI 구축이 완료되었습니다!"
echo "=================================================================="
echo "1. 테슬라 토큰 최초 연동 웹페이지 (브라우저 접속):"
echo "   http://${EXTERNAL_IP}:4000"
echo ""
echo "2. Grafana 대시보드 웹페이지 (초기 ID/PW: admin / admin):"
echo "   http://${EXTERNAL_IP}:3000"
echo ""
echo "3. 스마트폰 [테슬라_ev] 앱 -> [소모품&설정] -> [TeslaMate API]에 입력할 값:"
echo "   - TeslaMate Base URL     : http://${EXTERNAL_IP}:8080"
echo "   - TeslaMate Bearer Token : ${TM_API_TOKEN}"
echo "   - Car ID                 : 1"
echo "=================================================================="
