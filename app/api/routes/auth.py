from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app.models.user import User
from app.schemas.user import UserCreate, UserLogin, UserResponse
from app.core.security import hash_password, verify_password
from app.core.jwt import create_access_token, create_refresh_token, decode_token
from app.core.redis_client import blacklist_jti, is_blacklisted
import os

router = APIRouter(prefix="/api/auth", tags=["Auth"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/register", response_model=UserResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == user.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    new_user = User(
        username=user.username,
        email=user.email,
        password=hash_password(user.password),
        role=user.role,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


@router.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()
    if not db_user or not verify_password(user.password, db_user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials"
        )
    payload = {
        "sub": str(db_user.id),
        "username": db_user.username,
        "role": db_user.role,
    }
    access = create_access_token(payload)
    refresh = create_refresh_token(payload)
    return {
        "access_token": access["token"],
        "refresh_token": refresh["token"],
        "token_type": "bearer",
        "expires_in": access["expires_in"],
    }


@router.post("/refresh")
def refresh_token(body: dict):
    token = body.get("refresh_token")
    if not token:
        raise HTTPException(status_code=400, detail="refresh_token required")
    try:
        decoded = decode_token(token)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")
    if decoded.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid token type")
    jti = decoded.get("jti")
    if is_blacklisted(jti):
        raise HTTPException(status_code=401, detail="Token revoked")
    # rotate
    blacklist_jti(jti, int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7")) * 24 * 3600)
    payload = {
        "sub": decoded.get("sub"),
        "username": decoded.get("username"),
        "role": decoded.get("role"),
    }
    access = create_access_token(payload)
    refresh = create_refresh_token(payload)
    return {
        "access_token": access["token"],
        "refresh_token": refresh["token"],
        "expires_in": access["expires_in"],
    }


@router.post("/logout")
def logout(body: dict):
    token = body.get("refresh_token")
    if not token:
        raise HTTPException(status_code=400, detail="refresh_token required")
    try:
        decoded = decode_token(token)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")
    blacklist_jti(
        decoded.get("jti"), int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7")) * 24 * 3600
    )
    return {"message": "Logged out"}
