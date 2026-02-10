# apply_patch.ps1 — Creates devops + initial infra files and commits them on branch feat/full-delivery
param()
$ErrorActionPreference = "Stop"

# Ensure git repo
if (-not (Test-Path ".git")) {
  git init
}

git checkout -B feat/full-delivery

# Helper to write files
function Write-FileContent([string]$path, [string]$content) {
  $dir = Split-Path $path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $content | Out-File -FilePath $path -Encoding utf8 -Force
}

# Dockerfile
Write-FileContent "Dockerfile" @"
FROM python:3.11-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y build-essential libpq-dev gcc curl
COPY requirements.txt .
RUN pip install --upgrade pip && pip wheel -r requirements.txt -w /wheels

FROM python:3.11-slim
RUN addgroup --system app && adduser --system --ingroup app app
WORKDIR /app
COPY --from=builder /wheels /wheels
COPY requirements.txt .
RUN pip install --no-index --find-links=/wheels -r requirements.txt
COPY . .
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost:8000/health || exit 1
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
"@

# docker-compose.yml
Write-FileContent "docker-compose.yml" @"
version: '3.8'
services:
  api:
    build: .
    ports:
      - '8000:8000'
    environment:
      DATABASE_URL: postgresql+psycopg2://buguser:123321123@db:5432/bugtracker
      REDIS_URL: redis://redis:6379/0
      PRIVATE_KEY_PATH: /app/keys/private.pem
      PUBLIC_KEY_PATH: /app/keys/public.pem
      ACCESS_TOKEN_EXPIRE_MINUTES: '15'
      REFRESH_TOKEN_EXPIRE_DAYS: '7'
      ALGORITHM: RS256
    depends_on:
      - db
      - redis

  db:
    image: postgres:15
    environment:
      POSTGRES_USER: buguser
      POSTGRES_PASSWORD: 123321123
      POSTGRES_DB: bugtracker
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7
    volumes:
      - redisdata:/data

volumes:
  pgdata:
  redisdata:
"@

# docker-compose.override.yml
Write-FileContent "docker-compose.override.yml" @"
version: '3.8'
services:
  api:
    volumes:
      - .:/app
    command: uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
"@

# requirements.txt
Write-FileContent "requirements.txt" @"
fastapi>=0.95
uvicorn[standard]>=0.21
sqlalchemy>=1.4
psycopg2-binary>=2.9
alembic>=1.10
passlib[argon2]>=1.7
pyjwt>=2.8
python-dotenv>=1.0
pydantic-settings>=2.0
redis>=4.5
aioredis>=2.0
pytest>=7.3
pytest-asyncio>=0.21
httpx>=0.24
black>=24.3
ruff>=0.12
cryptography>=41.0
slowapi>=0.1.7
"@

# scripts/generate_rsa.sh
Write-FileContent "scripts/generate_rsa.sh" @"
#!/usr/bin/env bash
set -e
mkdir -p keys
openssl genpkey -algorithm RSA -out keys/private.pem -pkeyopt rsa_keygen_bits:2048
openssl rsa -in keys/private.pem -pubout -out keys/public.pem
echo "Generated keys/private.pem and keys/public.pem (move private.pem to secure storage)."
"@
# make executable on Unix systems (no-op on Windows)
try { icacls "scripts/generate_rsa.sh" /grant Everyone:RX } catch {}

# .github/workflows/ci.yml
Write-FileContent ".github/workflows/ci.yml" @"
name: CI

on:
  push:
    branches: [ main, feat/* ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: 3.11
      - name: Install deps
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
      - name: Lint (ruff)
        run: ruff check .
      - name: Format check (black)
        run: black --check .
      - name: Run tests
        env:
          DATABASE_URL: sqlite+aiosqlite:///:memory:
        run: |
          pytest -q --maxfail=1
"@

# deploy/k8s/deployment.yaml
Write-FileContent "deploy/k8s/deployment.yaml" @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bugtracker-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: bugtracker-api
  template:
    metadata:
      labels:
        app: bugtracker-api
    spec:
      containers:
        - name: api
          image: your-registry/bugtracker-api:latest
          ports:
            - containerPort: 8000
          env:
            - name: DATABASE_URL
              value: postgresql+psycopg2://buguser:123321123@postgres:5432/bugtracker
            - name: REDIS_URL
              value: redis://redis:6379/0
"@

# README.md
Write-FileContent "README.md" @"
# iit_madrasAssignment - Bug Tracker API

This patch adds containerization, RSA helper, CI skeleton, and k8s templates.

Quick start (local):
1. Generate RSA keys:
   ./scripts/generate_rsa.sh
2. Start services:
   docker-compose up --build
3. Create migrations and run:
   export DATABASE_URL=postgresql+psycopg2://buguser:123321123@localhost:5432/bugtracker
   alembic upgrade head
4. Seed (optional):
   python scripts/seed.py
5. Visit: http://localhost:8000/docs
"@

# minimal alembic.ini and env to allow autogenerate later
Write-FileContent "alembic.ini" @"
[alembic]
script_location = alembic
sqlalchemy.url = %(DATABASE_URL)s
"@

Write-FileContent "alembic/env.py" @"
from logging.config import fileConfig
from sqlalchemy import engine_from_config
from sqlalchemy import pool
from alembic import context
import os, sys
sys.path.insert(0, os.getcwd())
from app.db.database import Base
import app.models

config = context.config
fileConfig(config.config_file_name)
target_metadata = Base.metadata

def run_migrations_offline():
    url = os.environ.get('DATABASE_URL', 'sqlite:///:memory:')
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online():
    connectable = engine_from_config(config.get_section(config.config_ini_section), prefix='sqlalchemy.', poolclass=pool.NullPool)
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
"@

# seed script
Write-FileContent "scripts/seed.py" @"
from app.db.database import SessionLocal, engine, Base
from app.models.user import User
from app.core.security import hash_password

def seed():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    admin = User(username='admin', email='admin@example.com', password=hash_password('Admin@1234'), role='admin')
    db.add(admin)
    db.commit()
    db.close()

if __name__ == '__main__':
    seed()
"@

# minimal test to validate health endpoint
Write-FileContent "tests/test_health.py" @"
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health():
    r = client.get('/health')
    assert r.status_code == 200
    assert r.json()['status'] == 'ok'
"@

# Make basic directories & placeholder files for models/endpoints if missing
$placeholders = @{
  "app/core/__init__.py" = ""
  "app/api/routes/__init__.py" = "from .auth import router as router\n"
  "app/db/__init__.py" = ""
  "app/models/__init__.py" = ""
  "app/schemas/__init__.py" = ""
}
foreach ($k in $placeholders.Keys) {
  if (-not (Test-Path $k)) { Write-FileContent $k $placeholders[$k] }
}

# Stage, commit
git add -A
try {
  git commit -m "chore: add docker, compose, rsa helper, ci skeleton, k8s templates, alembic skeleton, seed, tests" --author="automation <you@localhost>"
} catch {
  Write-Host "No changes to commit."
}

Write-Host "Patch files created and committed on branch feat/full-delivery."
Write-Host "Next: run `git push -u origin feat/full-delivery` to push to remote."
Write-Host "Then run: ./scripts/generate_rsa.sh  and docker-compose up --build"