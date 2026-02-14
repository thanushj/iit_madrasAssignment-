# iit_madrasAssignment - Bug Tracker API

A containerized Bug Tracker API built using FastAPI and PostgreSQL.
This version includes authentication APIs and Docker setup for local development.

---

## 🚀 Tech Stack

- FastAPI
- PostgreSQL
- SQLAlchemy
- Alembic (Database Migrations)
- JWT Authentication
- Docker & Docker Compose

---

## 📦 Features Implemented

### 🔐 Authentication APIs
- POST /api/auth/register  → Register new user
- POST /api/auth/login     → Login user
- POST /api/auth/refresh   → Refresh access token
- POST /api/auth/logout    → Logout user

### 🩺 Health Check
- GET /health → Check API status

---

## 🐳 Quick Start (Docker Setup)

1. Clone the repository:
   git clone <your-repo-url>
   cd iit_madrasAssignment

2. Start services using Docker:
   docker-compose up --build

3. Run database migrations:
   docker-compose exec app alembic upgrade head

4. Visit Swagger Docs:
   http://localhost:8000/docs

5. Health Check:
   http://localhost:8000/health

---

## 🗂 Project Structure

iit_madrasAssignment/
│
├── app/
│   ├── api/
│   ├── core/
│   ├── models/
│   ├── schemas/
│   └── main.py
│
├── alembic/
├── docker-compose.yml
├── Dockerfile
└── README.md

---

## 📖 API Documentation

Swagger UI:
http://localhost:8000/docs

OpenAPI Schema:
http://localhost:8000/openapi.json

---

## ⚙️ Environment Variables

DATABASE_URL=postgresql+psycopg2://buguser:password@db:5432/bugtracker
SECRET_KEY=your_secret_key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

---

## 📌 Current Status

✔ Dockerized application  
✔ PostgreSQL integration  
✔ JWT Authentication  
✔ Database migrations  

🚧 Upcoming Features:
- Bug CRUD APIs
- Role-based authorization
- Kubernetes deployment
- CI/CD pipeline

---

## 👨‍💻 Author

Thanush J  

