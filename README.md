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

Production-ready backend API for a Bug Reporting System built as part of the AI4Bharat Backend Hiring Challenge.

This project includes:
- RESTful API design (Users, Projects, Issues, Comments)
- JWT authentication (RS256)
- Role-based access control
- Issue status state machine
- Soft delete for projects
- Token blacklisting & refresh rotation
- Security hardening (rate limiting, headers, validation)
- Docker & Docker Compose setup
- Kubernetes templates
- CI/CD pipeline (GitHub Actions)
- Database migrations (Alembic)
- Seed script

------------------------------------------------------------
Quick Start (Local Development)
------------------------------------------------------------

1. Generate RSA keys:
   ./scripts/generate_rsa.sh

2. Start services (API + Postgres + Redis + Nginx):
   docker-compose up --build

3. Run database migrations:
   export DATABASE_URL=postgresql+psycopg2://buguser:123321123@localhost:5432/bugtracker
   alembic upgrade head

4. (Optional) Seed database:
   python scripts/seed.py

5. Access API documentation:
   http://localhost:8000/docs


------------------------------------------------------------
API Overview
------------------------------------------------------------

Authentication:
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/refresh
POST   /api/auth/logout
GET    /api/auth/me

Projects:
GET    /api/projects
POST   /api/projects
GET    /api/projects/{id}
PATCH  /api/projects/{id}
DELETE /api/projects/{id}

Issues:
GET    /api/projects/{id}/issues
POST   /api/projects/{id}/issues
GET    /api/issues/{id}
PATCH  /api/issues/{id}

Comments:
GET    /api/issues/{id}/comments
POST   /api/issues/{id}/comments
PATCH  /api/comments/{id}


------------------------------------------------------------
Security Features
------------------------------------------------------------

- bcrypt password hashing
- JWT RS256 (asymmetric keys)
- Access token expiry: 15 minutes
- Refresh token expiry: 7 days
- Token blacklist (logout support)
- Login rate limiting
- Global rate limiting
- Security headers (HSTS, X-Frame-Options, etc.)
- Strict CORS configuration
- Input validation with Pydantic
- ORM-based SQL injection protection
- Markdown sanitization for XSS prevention


------------------------------------------------------------
Issue State Machine
------------------------------------------------------------

open → in_progress → resolved → closed
                         ↓
                      reopened

Critical issues cannot be closed without at least one comment.


------------------------------------------------------------
Docker Services
------------------------------------------------------------

- API (FastAPI)
- PostgreSQL
- Redis
- Nginx (reverse proxy)


------------------------------------------------------------
Run Tests
------------------------------------------------------------

pytest --cov=app


------------------------------------------------------------
Kubernetes Deployment
------------------------------------------------------------

kubectl apply -f k8s/


------------------------------------------------------------
CI/CD Pipeline
------------------------------------------------------------

GitHub Actions pipeline includes:
- Linting
- Type checking
- Unit tests
- Coverage validation (≥70%)
- Dependency security scanning
- Docker build


------------------------------------------------------------
Author
------------------------------------------------------------

Thanush
AI4Bharat Backend Hiring Challenge Submission
