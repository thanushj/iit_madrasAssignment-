import os
import time
import uuid
import jwt

PRIVATE_KEY_PATH = os.getenv("PRIVATE_KEY_PATH", "keys/private.pem")
PUBLIC_KEY_PATH = os.getenv("PUBLIC_KEY_PATH", "keys/public.pem")
ACCESS_EXPIRE = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15")) * 60
REFRESH_EXPIRE = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7")) * 24 * 3600
ALGORITHM = os.getenv("ALGORITHM", "RS256")


def _load_private():
    with open(PRIVATE_KEY_PATH, "rb") as f:
        return f.read()


def _load_public():
    with open(PUBLIC_KEY_PATH, "rb") as f:
        return f.read()


_priv = None
_pub = None


def create_access_token(data: dict) -> dict:
    global _priv
    if _priv is None:
        _priv = _load_private()
    now = int(time.time())
    jti = str(uuid.uuid4())
    payload = {
        "exp": now + ACCESS_EXPIRE,
        "iat": now,
        "jti": jti,
        "type": "access",
        **data,
    }
    token = jwt.encode(payload, _priv, algorithm=ALGORITHM)
    return {"token": token, "jti": jti, "expires_in": ACCESS_EXPIRE}


def create_refresh_token(data: dict) -> dict:
    global _priv
    if _priv is None:
        _priv = _load_private()
    now = int(time.time())
    jti = str(uuid.uuid4())
    payload = {
        "exp": now + REFRESH_EXPIRE,
        "iat": now,
        "jti": jti,
        "type": "refresh",
        **data,
    }
    token = jwt.encode(payload, _priv, algorithm=ALGORITHM)
    return {"token": token, "jti": jti, "expires_in": REFRESH_EXPIRE}


def decode_token(token: str) -> dict:
    global _pub
    if _pub is None:
        _pub = _load_public()
    return jwt.decode(token, _pub, algorithms=[ALGORITHM])
