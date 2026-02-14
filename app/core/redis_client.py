import os
import redis

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
_redis = redis.Redis.from_url(REDIS_URL, decode_responses=True)


def blacklist_jti(jti: str, expires: int):
    _redis.setex(f"bl:{jti}", expires, "1")


def is_blacklisted(jti: str) -> bool:
    return _redis.exists(f"bl:{jti}") == 1
