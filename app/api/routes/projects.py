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
