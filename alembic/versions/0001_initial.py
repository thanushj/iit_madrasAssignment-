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
