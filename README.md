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


# iit_madrasAssignment - Bug Tracker API

Backend API for a Bug Reporting System built using FastAPI and PostgreSQL.
This project includes core authentication, database models, JWT setup with RSA keys, and Docker-based containerization.

------------------------------------------------------------
Implemented Features
------------------------------------------------------------

- User authentication (Register & Login)
- Password hashing using bcrypt
- UUID-based primary keys
- Role-based user model (developer, manager, admin)
- PostgreSQL integration
- SQLAlchemy ORM
- Alembic database migrations
- RSA key-based JWT setup (RS256)
- Docker containerization
- Docker Compose setup (API + Postgres)

------------------------------------------------------------
Tech Stack
------------------------------------------------------------

Backend: FastAPI  
Database: PostgreSQL  
ORM: SQLAlchemy  
Migrations: Alembic  
Authentication: JWT (RS256)  
Containerization: Docker & Docker Compose  

------------------------------------------------------------
Quick Start (Local Development)
------------------------------------------------------------

1. Generate RSA keys:
   ./scripts/generate_rsa.sh

2. Start services:
   docker-compose up --build

3. Run database migrations:
   export DATABASE_URL=postgresql+psycopg2://buguser:123321123@localhost:5432/bugtracker
   alembic upgrade head

4. (Optional) Seed database:
   python scripts/seed.py

5. Visit API documentation:
   http://localhost:8000/docs


------------------------------------------------------------
Available Endpoints
------------------------------------------------------------

Authentication:
POST   /api/auth/register
POST   /api/auth/login

(Additional endpoints under development)


------------------------------------------------------------
Project Structure
------------------------------------------------------------

app/
  api/
  core/
  models/
  schemas/
  db/
  main.py

Dockerfile
docker-compose.yml
alembic/
scripts/


------------------------------------------------------------
Docker Services
------------------------------------------------------------

- API (FastAPI application)
- PostgreSQL database


------------------------------------------------------------
Run Tests (if configured)
------------------------------------------------------------

pytest


------------------------------------------------------------
Author
------------------------------------------------------------

Thanush
AI4Bharat Backend Hiring Challenge

