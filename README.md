브라우저 → React	http://localhost:5173	프론트엔드 접속
React → FastAPI	http://backend:8000	Docker 내부 네트워크 통신
브라우저 직접 API 접근	http://localhost:8080	FastAPI 직접 접근 (테스트용)

# db 안 날리고 전체 재실행
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# volume 날려서 db 초기화
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d

# 중요파일 수정 후 재시작
docker-compose down
docker-compose up --build


# logs 확인
docker-compose logs -f db_backend

docker-compose logs -f backtesting_backend

docker-compose logs -f frontend

docker-compose logs -f database

docker-compose logs -f worker

docker-compose logs -f redis


# 도커 컨테이너 안에 디렉토리 확인
docker exec -it backend ls /app
docker exec -it backend ls /app/db_module
docker exec -it backend ls -R /app


# frontend 재시작
docker compose stop frontend
docker compose up -d --build frontend



# Celery 관리
docker compose stop worker
docker exec -it redis redis-cli FLUSHDB
docker compose up -d --build worker
docker compose logs -f worker

# Celery worker 확인
docker exec -it worker celery -A celery_task.celery_app inspect registered

# backtesting backend 관리
docker-compose build --no-cache backtesting_backend
docker-compose up -d
