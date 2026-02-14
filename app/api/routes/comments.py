from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.db.database import SessionLocal
from app.models.comment import Comment
from app.schemas.comment import CommentCreate, CommentResponse
from app.dependencies.permissions import get_current_user_from_bearer
from uuid import UUID

router = APIRouter(prefix="/api", tags=["Comments"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/issues/{issue_id}/comments", response_model=List[CommentResponse])
def list_comments(
    issue_id: UUID,
    db: Session = Depends(get_db),
    user=Depends(get_current_user_from_bearer),
):
    return db.query(Comment).filter(Comment.issue_id == issue_id).all()


@router.post("/issues/{issue_id}/comments", response_model=CommentResponse)
def add_comment(
    issue_id: UUID,
    payload: CommentCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user_from_bearer),
):
    c = Comment(content=payload.content, issue_id=issue_id, author_id=UUID(user["sub"]))
    db.add(c)
    db.commit()
    db.refresh(c)
    return c


@router.patch("/comments/{comment_id}", response_model=CommentResponse)
def edit_comment(
    comment_id: UUID,
    payload: CommentCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user_from_bearer),
):
    c = db.get(Comment, comment_id)
    if not c:
        raise HTTPException(status_code=404, detail="Not found")
    if str(c.author_id) != user["sub"]:
        raise HTTPException(status_code=403, detail="Forbidden")
    c.content = payload.content
    db.add(c)
    db.commit()
    db.refresh(c)
    return c
