from app.db.database import SessionLocal, engine, Base
from app.models.user import User
from app.core.security import hash_password


def seed():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    admin = User(
        username="admin",
        email="admin@example.com",
        password=hash_password("Admin@1234"),
        role="admin",
    )
    db.add(admin)
    db.commit()
    db.close()


if __name__ == "__main__":
    seed()
