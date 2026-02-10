from fastapi import HTTPException, status, Depends, Request
from app.core.jwt import decode_token
from app.core.redis_client import is_blacklisted

def get_current_user_from_bearer(request: Request):
    auth = request.headers.get('Authorization')
    if not auth: raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Missing token')
    if auth.lower().startswith('bearer '): token = auth.split(' ',1)[1]
    else: token = auth
    try:
        decoded = decode_token(token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid token')
    if is_blacklisted(decoded.get('jti')): raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Token revoked')
    return decoded

def require_role(*allowed_roles):
    def _checker(user=Depends(get_current_user_from_bearer)):
        role = user.get('role')
        if role not in allowed_roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Forbidden')
        return user
    return _checker
