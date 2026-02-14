from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.db.database import SessionLocal
from app.models.issue import Issue, StatusEnum
from app.schemas.issue import IssueCreate, IssueUpdate, IssueResponse
from app.dependencies.permissions import get_current_user_from_bearer
from uuid import UUID

router = APIRouter(prefix="/api", tags=["Issues"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/projects/{project_id}/issues", response_model=List[IssueResponse])
def list_project_issues(
    project_id: UUID,
    status: StatusEnum = None,
    db: Session = Depends(get_db),
    user=Depends(get_current_user_from_bearer),
):
    q = db.query(Issue).filter(Issue.project_id == project_id)
    if status:
        q = q.filter(Issue.status == status)
    return q.all()


@router.post("/projects/{project_id}/issues", response_model=IssueResponse)
def create_issue(
    project_id: UUID,
    payload: IssueCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user_from_bearer),
):
    issue = Issue(
        title=payload.title,
        description=payload.description,
        priority=payload.priority,
        project_id=project_id,
        reporter_id=UUID(user["sub"]),
        assignee_id=payload.assignee_id,
        due_date=payload.due_date,
    )
    db.add(issue)
    db.commit()
    db.refresh(issue)
    return issue


@router.get("/issues/{issue_id}", response_model=IssueResponse)
def get_issue(
    issue_id: UUID,
    db: Session = Depends(get_db),
    user=Depends(get_current_user_from_bearer),
):
    issue = db.get(Issue, issue_id)
    if not issue:
        raise HTTPException(status_code=404, detail="Not found")
    return issue


@router.patch("/issues/{issue_id}", response_model=IssueResponse)
def update_issue(
    issue_id: UUID,
    payload: IssueUpdate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user_from_bearer),
):
    issue = db.get(Issue, issue_id)
    if not issue:
        raise HTTPException(status_code=404, detail="Not found")
    for k, v in payload.dict(exclude_unset=True).items():
        setattr(issue, k, v)
    db.add(issue)
    db.commit()
    db.refresh(issue)
    return issue
