# apply_impl.ps1 — Adds full implementation files and commits on branch feat/complete-impl
$ErrorActionPreference = "Stop"

function Write-File([string]$path, [string]$content) {
  $dir = Split-Path $path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $content | Out-File -FilePath $path -Encoding utf8 -Force
}

# 1) Checkout branch
git checkout -B feat/complete-impl

# 2) Models
Write-File "app/models/__init__.py" @"
from .user import User
from .project import Project
from .issue import Issue
from .comment import Comment
"@

Write-File "app/models/project.py" @"
import uuid
from sqlalchemy import Column, String, Text, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.db.database import Base

class Project(Base):
    __tablename__ = 'projects'
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), unique=True, nullable=False)
    description = Column(Text, nullable=True)
    created_by = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='RESTRICT'), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    is_archived = Column(Boolean, default=False)
"@

Write-File "app/models/issue.py" @"
import uuid, enum
from sqlalchemy import Column, String, Text, Enum as SAEnum, Date, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.db.database import Base

class StatusEnum(str, enum.Enum):
    open = 'open'
    in_progress = 'in_progress'
    resolved = 'resolved'
    closed = 'closed'
    reopened = 'reopened'

class PriorityEnum(str, enum.Enum):
    low = 'low'
    medium = 'medium'
    high = 'high'
    critical = 'critical'

class Issue(Base):
    __tablename__ = 'issues'
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    status = Column(SAEnum(StatusEnum), default=StatusEnum.open)
    priority = Column(SAEnum(PriorityEnum), default=PriorityEnum.medium)
    project_id = Column(UUID(as_uuid=True), ForeignKey('projects.id', ondelete='CASCADE'), nullable=False)
    reporter_id = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='RESTRICT'), nullable=False)
    assignee_id = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    due_date = Column(Date, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
"@

Write-File "app/models/comment.py" @"
import uuid
from sqlalchemy import Column, Text, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.db.database import Base

class Comment(Base):
    __tablename__ = 'comments'
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    content = Column(Text, nullable=False)
    issue_id = Column(UUID(as_uuid=True), ForeignKey('issues.id', ondelete='CASCADE'), nullable=False)
    author_id = Column(UUID(as_uuid=True), ForeignKey('users.id', ondelete='RESTRICT'), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
"@

# 3) Redis client
Write-File "app/core/redis_client.py" @"
import os
import redis

REDIS_URL = os.getenv('REDIS_URL','redis://localhost:6379/0')
_redis = redis.Redis.from_url(REDIS_URL, decode_responses=True)

def blacklist_jti(jti: str, expires: int):
    _redis.setex(f'bl:{jti}', expires, '1')

def is_blacklisted(jti: str) -> bool:
    return _redis.exists(f'bl:{jti}') == 1
"@

# 4) JWT helpers
Write-File "app/core/jwt.py" @"
import os, time, uuid
import jwt

PRIVATE_KEY_PATH = os.getenv('PRIVATE_KEY_PATH','keys/private.pem')
PUBLIC_KEY_PATH = os.getenv('PUBLIC_KEY_PATH','keys/public.pem')
ACCESS_EXPIRE = int(os.getenv('ACCESS_TOKEN_EXPIRE_MINUTES','15')) * 60
REFRESH_EXPIRE = int(os.getenv('REFRESH_TOKEN_EXPIRE_DAYS','7')) * 24 * 3600
ALGORITHM = os.getenv('ALGORITHM','RS256')

def _load_private():
    with open(PRIVATE_KEY_PATH,'rb') as f: return f.read()

def _load_public():
    with open(PUBLIC_KEY_PATH,'rb') as f: return f.read()

_priv = None
_pub = None

def create_access_token(data: dict) -> dict:
    global _priv
    if _priv is None: _priv = _load_private()
    now = int(time.time()); jti = str(uuid.uuid4())
    payload = {'exp': now + ACCESS_EXPIRE, 'iat': now, 'jti': jti, 'type':'access', **data}
    token = jwt.encode(payload, _priv, algorithm=ALGORITHM)
    return {'token': token, 'jti': jti, 'expires_in': ACCESS_EXPIRE}

def create_refresh_token(data: dict) -> dict:
    global _priv
    if _priv is None: _priv = _load_private()
    now = int(time.time()); jti = str(uuid.uuid4())
    payload = {'exp': now + REFRESH_EXPIRE, 'iat': now, 'jti': jti, 'type':'refresh', **data}
    token = jwt.encode(payload, _priv, algorithm=ALGORITHM)
    return {'token': token, 'jti': jti, 'expires_in': REFRESH_EXPIRE}

def decode_token(token: str) -> dict:
    global _pub
    if _pub is None: _pub = _load_public()
    return jwt.decode(token, _pub, algorithms=[ALGORITHM])
"@

# 5) Update auth router (full)
Write-File "app/api/routes/auth.py" @"
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app.models.user import User
from app.schemas.user import UserCreate, UserLogin, UserResponse
from app.core.security import hash_password, verify_password
from app.core.jwt import create_access_token, create_refresh_token, decode_token
from app.core.redis_client import blacklist_jti, is_blacklisted
import os

router = APIRouter(prefix='/api/auth', tags=['Auth'])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post('/register', response_model=UserResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == user.email).first()
    if existing: raise HTTPException(status_code=400, detail='Email already registered')
    new_user = User(username=user.username, email=user.email, password=hash_password(user.password), role=user.role)
    db.add(new_user); db.commit(); db.refresh(new_user)
    return new_user

@router.post('/login')
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()
    if not db_user or not verify_password(user.password, db_user.password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid credentials')
    payload = {'sub': str(db_user.id), 'username': db_user.username, 'role': db_user.role}
    access = create_access_token(payload)
    refresh = create_refresh_token(payload)
    return {'access_token': access['token'], 'refresh_token': refresh['token'], 'token_type':'bearer', 'expires_in': access['expires_in']}

@router.post('/refresh')
def refresh_token(body: dict):
    token = body.get('refresh_token')
    if not token: raise HTTPException(status_code=400, detail='refresh_token required')
    try:
        decoded = decode_token(token)
    except Exception:
        raise HTTPException(status_code=401, detail='Invalid token')
    if decoded.get('type') != 'refresh': raise HTTPException(status_code=401, detail='Invalid token type')
    jti = decoded.get('jti')
    if is_blacklisted(jti): raise HTTPException(status_code=401, detail='Token revoked')
    # rotate
    blacklist_jti(jti, int(os.getenv('REFRESH_TOKEN_EXPIRE_DAYS','7')) * 24 * 3600)
    payload = {'sub': decoded.get('sub'), 'username': decoded.get('username'), 'role': decoded.get('role')}
    access = create_access_token(payload)
    refresh = create_refresh_token(payload)
    return {'access_token': access['token'], 'refresh_token': refresh['token'], 'expires_in': access['expires_in']}

@router.post('/logout')
def logout(body: dict):
    token = body.get('refresh_token')
    if not token: raise HTTPException(status_code=400, detail='refresh_token required')
    try:
        decoded = decode_token(token)
    except Exception:
        raise HTTPException(status_code=401, detail='Invalid token')
    blacklist_jti(decoded.get('jti'), int(os.getenv('REFRESH_TOKEN_EXPIRE_DAYS','7')) * 24 * 3600)
    return {'message':'Logged out'}
"@

# 6) Permissions dependency
Write-File "app/dependencies/permissions.py" @"
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
"@

# 7) Schemas (project/issue/comment)
Write-File "app/schemas/project.py" @"
from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional
from datetime import datetime

class ProjectCreate(BaseModel):
    name: str = Field(..., max_length=100)
    description: Optional[str] = Field(None, max_length=1000)

class ProjectUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = Field(None, max_length=1000)
    is_archived: Optional[bool]

class ProjectResponse(BaseModel):
    id: UUID
    name: str
    description: Optional[str]
    created_by: UUID
    created_at: datetime
    updated_at: datetime
    is_archived: bool
    class Config: from_attributes = True
"@

Write-File "app/schemas/issue.py" @"
from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional
from datetime import date, datetime
from app.models.issue import StatusEnum, PriorityEnum

class IssueCreate(BaseModel):
    title: str = Field(..., max_length=200)
    description: Optional[str] = Field(None, max_length=5000)
    priority: Optional[PriorityEnum] = PriorityEnum.medium
    assignee_id: Optional[UUID]
    due_date: Optional[date]

class IssueUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    description: Optional[str] = Field(None, max_length=5000)
    status: Optional[StatusEnum]
    priority: Optional[PriorityEnum]
    assignee_id: Optional[UUID]
    due_date: Optional[date]

class IssueResponse(BaseModel):
    id: UUID
    title: str
    description: Optional[str]
    status: StatusEnum
    priority: PriorityEnum
    project_id: UUID
    reporter_id: UUID
    assignee_id: Optional[UUID]
    due_date: Optional[date]
    created_at: datetime
    updated_at: datetime
    class Config: from_attributes = True
"@

Write-File "app/schemas/comment.py" @"
from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime

class CommentCreate(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)

class CommentResponse(BaseModel):
    id: UUID
    content: str
    issue_id: UUID
    author_id: UUID
    created_at: datetime
    updated_at: datetime
    class Config: from_attributes = True
"@

# 8) Routes for projects/issues/comments
Write-File "app/api/routes/projects.py" @"
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List
from app.db.database import SessionLocal
from app.models.project import Project
from app.schemas.project import ProjectCreate, ProjectUpdate, ProjectResponse
from app.dependencies.permissions import get_current_user_from_bearer, require_role
from uuid import UUID

router = APIRouter(prefix='/api/projects', tags=['Projects'])

def get_db():
    db = SessionLocal(); try: yield db
    finally: db.close()

@router.get('', response_model=List[ProjectResponse])
def list_projects(search: str = Query(None), is_archived: bool = False, db: Session = Depends(get_db), user=Depends(get_current_user_from_bearer)):
    q = db.query(Project).filter(Project.is_archived == is_archived)
    if search: q = q.filter(Project.name.ilike(f'%{search}%'))
    return q.all()

@router.post('', response_model=ProjectResponse)
def create_project(payload: ProjectCreate, db: Session = Depends(get_db), user=Depends(require_role('manager','admin'))):
    existing = db.query(Project).filter(Project.name == payload.name).first()
    if existing: raise HTTPException(status_code=400, detail='Project name exists')
    proj = Project(name=payload.name, description=payload.description, created_by=UUID(user['sub']))
    db.add(proj); db.commit(); db.refresh(proj)
    return proj

@router.get('/{project_id}', response_model=ProjectResponse)
def get_project(project_id: UUID, db: Session = Depends(get_db), user=Depends(get_current_user_from_bearer)):
    proj = db.get(Project, project_id)
    if not proj: raise HTTPException(status_code=404, detail='Not found')
    return proj

@router.patch('/{project_id}', response_model=ProjectResponse)
def update_project(project_id: UUID, payload: ProjectUpdate, db: Session = Depends(get_db), user=Depends(require_role('manager','admin'))):
    proj = db.get(Project, project_id)
    if not proj: raise HTTPException(status_code=404, detail='Not found')
    for k,v in payload.dict(exclude_unset=True).items(): setattr(proj, k, v)
    db.add(proj); db.commit(); db.refresh(proj)
    return proj

@router.delete('/{project_id}')
def archive_project(project_id: UUID, db: Session = Depends(get_db), user=Depends(require_role('manager','admin'))):
    proj = db.get(Project, project_id)
    if not proj: raise HTTPException(status_code=404, detail='Not found')
    proj.is_archived = True
    db.add(proj); db.commit()
    return {'message':'archived'}
"@

Write-File "app/api/routes/issues.py" @"
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List
from app.db.database import SessionLocal
from app.models.issue import Issue, StatusEnum
from app.schemas.issue import IssueCreate, IssueUpdate, IssueResponse
from app.dependencies.permissions import get_current_user_from_bearer
from uuid import UUID

router = APIRouter(prefix='/api', tags=['Issues'])

def get_db():
    db = SessionLocal(); try: yield db
    finally: db.close()

@router.get('/projects/{project_id}/issues', response_model=List[IssueResponse])
def list_project_issues(project_id: UUID, status: StatusEnum = None, db: Session = Depends(get_db), user=Depends(get_current_user_from_bearer)):
    q = db.query(Issue).filter(Issue.project_id == project_id)
    if status: q = q.filter(Issue.status == status)
    return q.all()

@router.post('/projects/{project_id}/issues', response_model=IssueResponse)
def create_issue(project_id: UUID, payload: IssueCreate, db: Session = Depends(get_db), user=Depends(get_current_user_from_bearer)):
    issue = Issue(title=payload.title, description=payload.description, priority=payload.priority, project_id=project_id, reporter_id=UUID(user['sub']), assignee_id=payload.assignee_id, due_date=payload.due_date)
    db.add(issue); db.commit(); db.refresh(issue)
    return issue

@router.get('/issues/{issue_id}', response_model=IssueResponse)
def get_issue(issue_id: UUID, db: Session = Depends(get_db), user=Depends(get_current_user_from_bearer)):
    issue = db.get(Issue, issue_id)
    if not issue: raise HTTPException(status_code=404, detail='Not found')
    return issue

@router.patch('/issues/{issue_id}', response_model=IssueResponse)
def update_issue(issue_id: UUID, payload: IssueUpdate, db: Session = Depends(get_db), user=Depends(get_current_user_from_bearer)):
    issue = db.get(Issue, issue_id)
    if not issue: raise HTTPException(status_code=404, detail='Not found')
    for k,v in payload.dict(exclude_unset=True).items(): setattr(issue, k, v)
    db.add(issue); db.commit(); db.refresh(issue)
    return issue
"@

Write-File "app/api/routes/comments.py" @"
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.db.database import SessionLocal
from app.models.comment import Comment
from app.schemas.comment import CommentCreate, CommentResponse
from app.dependencies.permissions import get_current_user_from_bearer
from uuid import UUID

router = APIRouter(prefix='/api', tags=['Comments'])

def get_db():
    db = SessionLocal(); try: yield db
    finally: db.close()

@router.get('/issues/{issue_id}/comments', response_model=List[CommentResponse])
def list_comments(issue_id: UUID, db: Session = Depends(get_db), user=Depends(get_current_user_from_bearer)):
    return db.query(Comment).filter(Comment.issue_id == issue_id).all()

@router.post('/issues/{issue_id}/comments', response_model=CommentResponse)
def add_comment(issue_id: UUID, payload: CommentCreate, db: Session = Depends(get_db), user=Depends(get_current_user_from_bearer)):
    c = Comment(content=payload.content, issue_id=issue_id, author_id=UUID(user['sub']))
    db.add(c); db.commit(); db.refresh(c)
    return c

@router.patch('/comments/{comment_id}', response_model=CommentResponse)
def edit_comment(comment_id: UUID, payload: CommentCreate, db: Session = Depends(get_db), user=Depends(get_current_user_from_bearer)):
    c = db.get(Comment, comment_id)
    if not c: raise HTTPException(status_code=404, detail='Not found')
    if str(c.author_id) != user['sub']: raise HTTPException(status_code=403, detail='Forbidden')
    c.content = payload.content
    db.add(c); db.commit(); db.refresh(c)
    return c
"@

# 9) Alembic initial migration (simple)
Write-File "alembic/versions/0001_initial.py" @"
\"\"\"initial

Revision ID: 0001_initial
Revises:
Create Date: 2026-02-10 00:00:00.000000
\"\"\"
from alembic import op
import sqlalchemy as sa
import sqlalchemy.dialects.postgresql as pg

revision = '0001_initial'
down_revision = None
branch_labels = None
depends_on = None

def upgrade():
    op.create_table('users',
        sa.Column('id', pg.UUID(as_uuid=True), primary_key=True),
        sa.Column('username', sa.String(length=50), nullable=False),
        sa.Column('email', sa.String(), nullable=False),
        sa.Column('password', sa.String(), nullable=False),
        sa.Column('role', sa.String(), nullable=False),
        sa.Column('is_active', sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
        sa.Column('last_login', sa.DateTime(timezone=True), nullable=True)
    )
    op.create_table('projects',
        sa.Column('id', pg.UUID(as_uuid=True), primary_key=True),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('created_by', pg.UUID(as_uuid=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
        sa.Column('is_archived', sa.Boolean(), server_default=sa.false(), nullable=False)
    )
    op.create_table('issues',
        sa.Column('id', pg.UUID(as_uuid=True), primary_key=True),
        sa.Column('title', sa.String(length=200), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('status', sa.String(), nullable=False),
        sa.Column('priority', sa.String(), nullable=False),
        sa.Column('project_id', pg.UUID(as_uuid=True), nullable=False),
        sa.Column('reporter_id', pg.UUID(as_uuid=True), nullable=False),
        sa.Column('assignee_id', pg.UUID(as_uuid=True), nullable=True),
        sa.Column('due_date', sa.Date(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'))
    )
    op.create_table('comments',
        sa.Column('id', pg.UUID(as_uuid=True), primary_key=True),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('issue_id', pg.UUID(as_uuid=True), nullable=False),
        sa.Column('author_id', pg.UUID(as_uuid=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'))
    )

def downgrade():
    op.drop_table('comments')
    op.drop_table('issues')
    op.drop_table('projects')
    op.drop_table('users')
"@

# 10) Basic tests
Write-File "tests/test_endpoints.py" @"
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health():
    r = client.get('/health')
    assert r.status_code == 200 and r.json()['status'] == 'ok'
"@

# 11) Update requirements (append)
Add-Content -Path "requirements.txt" -Value "`ncryptography>=41.0`npyjwt>=2.8`nredis>=4.5`n"

# 12) Commit changes
git add -A
try {
  git commit -m "feat: add models, auth (RS256+rotation), redis blacklist, endpoints, alembic migration, tests"
} catch {
  Write-Host "Nothing to commit or commit failed: $($_.Exception.Message)"
}

Write-Host "Implementation files written and committed to branch feat/complete-impl. Run: git push -u origin feat/complete-impl"