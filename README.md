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
