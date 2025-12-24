# Backend Sync API Refactoring Guide

**Status:** Refactoring Required  
**Created:** December 24, 2024  
**Priority:** HIGH - Production Blocker

---

## Executive Summary

The backend content sharing API needs updates to properly handle iOS sync payloads and provide better error handling. This guide documents all required backend changes to align with the iOS sync service refactoring.

### Critical Issues

1. **content_data Field Handling** ⚠️
   - iOS may send as JSON string or nested object
   - Need flexible validation
   - Must store as JSONB in database

2. **Error Responses Lack Context** ⚠️
   - Generic error messages don't help debugging
   - Need detailed error responses for iOS

3. **Missing Validation** ⚠️
   - No validation of content_data structure per content_type
   - Missing required fields not caught early

4. **No Logging for Sync Operations** ⚠️
   - Hard to debug sync failures
   - Need structured logging

---

## Part 1: Schema Updates

### File: `app/schemas/content.py`

#### Update PublishContentRequest

```python
"""Content sharing schemas."""

import json
import logging
from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator

logger = logging.getLogger(__name__)


class PublishContentRequest(BaseModel):
    """Request to publish content.
    
    Accepts content_data as either:
    - dict[str, Any] (nested JSON object)
    - str (JSON string that will be parsed)
    """

    title: str = Field(..., min_length=3, max_length=200)
    description: str | None = Field(None, max_length=1000)
    content_type: str = Field(
        ..., 
        pattern="^(checklist|practice_guide|flashcard_deck)$",
        description="Type of content being published"
    )
    content_data: dict[str, Any] | str = Field(
        ..., 
        description="Full content structure as dict or JSON string"
    )
    tags: list[str] = Field(default_factory=list, max_length=20)
    language: str = Field(default="en", max_length=10)
    public_id: str = Field(
        ..., 
        min_length=1, 
        max_length=255,
        pattern="^[a-z0-9-]+$",
        description="URL-safe slug from client"
    )
    can_fork: bool = True

    @field_validator('content_data', mode='before')
    @classmethod
    def parse_content_data(cls, v: Any) -> dict[str, Any]:
        """Parse content_data if it's a JSON string.
        
        iOS may send content_data as a JSON string due to encoding
        limitations with [String: Any]. This validator ensures we
        always work with a dict internally.
        """
        if isinstance(v, str):
            try:
                parsed = json.loads(v)
                if not isinstance(parsed, dict):
                    raise ValueError("content_data must be a JSON object")
                logger.debug(f"Parsed content_data from JSON string: {len(parsed)} keys")
                return parsed
            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON in content_data: {e}")
                raise ValueError(f"Invalid JSON in content_data: {e}")
        
        if isinstance(v, dict):
            return v
        
        raise ValueError("content_data must be a dict or JSON string")

    @field_validator('tags')
    @classmethod
    def validate_tags(cls, v: list[str]) -> list[str]:
        """Validate and clean tags."""
        # Remove duplicates and empty strings
        cleaned = list(set(tag.strip() for tag in v if tag.strip()))
        
        # Limit tag length
        for tag in cleaned:
            if len(tag) > 50:
                raise ValueError(f"Tag too long: {tag[:20]}...")
        
        return cleaned[:20]  # Max 20 tags

    @model_validator(mode='after')
    def validate_content_structure(self) -> 'PublishContentRequest':
        """Validate content_data structure based on content_type."""
        if self.content_type == 'checklist':
            self._validate_checklist_structure()
        elif self.content_type == 'practice_guide':
            self._validate_guide_structure()
        elif self.content_type == 'flashcard_deck':
            self._validate_deck_structure()
        
        return self

    def _validate_checklist_structure(self) -> None:
        """Validate checklist content_data structure."""
        required_fields = ['id', 'title', 'sections']
        
        for field in required_fields:
            if field not in self.content_data:
                raise ValueError(
                    f"Checklist content_data missing required field: {field}"
                )
        
        # Validate sections is a list
        if not isinstance(self.content_data['sections'], list):
            raise ValueError("Checklist sections must be a list")
        
        logger.debug(
            f"Validated checklist with {len(self.content_data['sections'])} sections"
        )

    def _validate_guide_structure(self) -> None:
        """Validate practice guide content_data structure."""
        required_fields = ['id', 'title', 'markdown']
        
        for field in required_fields:
            if field not in self.content_data:
                raise ValueError(
                    f"Practice guide content_data missing required field: {field}"
                )
        
        logger.debug(
            f"Validated practice guide: {len(self.content_data.get('markdown', ''))} chars"
        )

    def _validate_deck_structure(self) -> None:
        """Validate flashcard deck content_data structure."""
        required_fields = ['id', 'title', 'cards']
        
        for field in required_fields:
            if field not in self.content_data:
                raise ValueError(
                    f"Flashcard deck content_data missing required field: {field}"
                )
        
        if not isinstance(self.content_data['cards'], list):
            raise ValueError("Flashcard deck cards must be a list")
        
        logger.debug(
            f"Validated flashcard deck with {len(self.content_data['cards'])} cards"
        )


class PublishContentResponse(BaseModel):
    """Response after publishing content."""

    id: UUID
    public_id: str
    published_at: datetime
    author_username: str | None
    can_fork: bool

    model_config = {"from_attributes": True}


class ContentErrorDetail(BaseModel):
    """Detailed error response for content operations."""
    
    error: str
    detail: str
    field: str | None = None
    suggestion: str | None = None


class SharedContentSummary(BaseModel):
    """Summary of shared content for listings."""

    id: UUID
    title: str
    description: str | None
    content_type: str
    tags: list[str]
    public_id: str
    author_username: str | None
    view_count: int
    fork_count: int
    created_at: datetime

    model_config = {"from_attributes": True}


class SharedContentDetail(BaseModel):
    """Full shared content with data."""

    id: UUID
    title: str
    description: str | None
    content_type: str
    content_data: dict[str, Any]
    tags: list[str]
    public_id: str
    can_fork: bool
    author_username: str | None
    view_count: int
    fork_count: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
```

---

## Part 2: Endpoint Updates

### File: `app/api/v1/content.py`

#### Enhanced Error Handling and Logging

```python
"""Content sharing endpoints."""

import logging
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.api.middleware import limiter
from app.database import get_db
from app.models.content import SharedContent
from app.schemas.content import (
    ContentErrorDetail,
    PublishContentRequest,
    PublishContentResponse,
    SharedContentDetail,
    SharedContentSummary,
)

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post(
    "/share",
    response_model=PublishContentResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        400: {
            "model": ContentErrorDetail,
            "description": "Invalid content data"
        },
        409: {
            "model": ContentErrorDetail,
            "description": "Duplicate public_id"
        }
    }
)
@limiter.limit("10/minute")
async def publish_content(
    request: Request,
    content: PublishContentRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> PublishContentResponse:
    """
    Publish content to make it publicly available.

    This endpoint:
    1. Validates the content payload (including structure)
    2. Checks for duplicate public_id
    3. Stores the content in shared_content table
    4. Returns publication metadata
    
    The content_data field can be sent as either:
    - A nested JSON object (preferred)
    - A JSON string (will be parsed automatically)
    """
    logger.info(
        f"Publish content request from user: {current_user.id}, "
        f"type: {content.content_type}, public_id: {content.public_id}"
    )

    # Check if public_id already exists
    result = await db.execute(
        select(SharedContent).where(
            SharedContent.public_id == content.public_id,
            SharedContent.deleted_at.is_(None)
        )
    )
    existing = result.scalar_one_or_none()

    if existing is not None:
        logger.warning(
            f"Duplicate public_id: {content.public_id} "
            f"(existing: {existing.id}, user: {existing.user_id})"
        )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "error": "duplicate_public_id",
                "detail": f"Content with public_id '{content.public_id}' already exists",
                "suggestion": "Generate a new public_id with a different suffix"
            }
        )

    # Create shared content
    try:
        shared_content = SharedContent(
            user_id=current_user.id,
            title=content.title,
            description=content.description,
            content_type=content.content_type,
            content_data=content.content_data,  # Already validated as dict
            tags=content.tags,
            language=content.language,
            public_id=content.public_id,
            can_fork=content.can_fork,
        )

        db.add(shared_content)
        await db.commit()
        await db.refresh(shared_content)

        logger.info(
            f"Content published successfully: {shared_content.id}, "
            f"public_id: {shared_content.public_id}, "
            f"content_type: {shared_content.content_type}"
        )

        return PublishContentResponse(
            id=shared_content.id,
            public_id=shared_content.public_id,
            published_at=shared_content.created_at,
            author_username=current_user.username,
            can_fork=shared_content.can_fork,
        )
    
    except Exception as e:
        logger.error(f"Failed to publish content: {e}", exc_info=True)
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "error": "publish_failed",
                "detail": "Failed to publish content to database",
                "suggestion": "Please try again or contact support if the issue persists"
            }
        )


@router.delete(
    "/{public_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={
        403: {
            "model": ContentErrorDetail,
            "description": "Not the owner"
        },
        404: {
            "model": ContentErrorDetail,
            "description": "Content not found"
        }
    }
)
@limiter.limit("20/minute")
async def unpublish_content(
    request: Request,
    public_id: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> None:
    """
    Unpublish (soft delete) shared content.

    Only the owner can unpublish their content.
    
    Returns 204 No Content on success.
    Returns 404 if content doesn't exist or was already deleted.
    Returns 403 if user is not the owner.
    """
    logger.info(
        f"Unpublish request for public_id: {public_id} from user: {current_user.id}"
    )

    # Find content
    result = await db.execute(
        select(SharedContent).where(
            SharedContent.public_id == public_id,
            SharedContent.deleted_at.is_(None),
        )
    )
    content = result.scalar_one_or_none()

    if content is None:
        logger.warning(f"Content not found for unpublish: {public_id}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": "content_not_found",
                "detail": f"Content with public_id '{public_id}' not found or already deleted",
                "suggestion": "Verify the public_id is correct"
            }
        )

    # Check ownership
    if content.user_id != current_user.id:
        logger.warning(
            f"User {current_user.id} attempted to unpublish content "
            f"owned by {content.user_id}"
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "not_owner",
                "detail": "You can only unpublish your own content",
                "suggestion": None
            }
        )

    # Soft delete
    try:
        from datetime import datetime
        content.deleted_at = datetime.now()
        await db.commit()

        logger.info(
            f"Content unpublished successfully: {public_id} (id: {content.id})"
        )
    except Exception as e:
        logger.error(f"Failed to unpublish content: {e}", exc_info=True)
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "error": "unpublish_failed",
                "detail": "Failed to unpublish content",
                "suggestion": "Please try again"
            }
        )


@router.get("/public", response_model=list[SharedContentSummary])
async def list_public_content(
    db: Annotated[AsyncSession, Depends(get_db)],
    content_type: str | None = None,
    limit: int = 20,
    offset: int = 0,
) -> list[SharedContentSummary]:
    """
    List public content (for discovery).

    Optional filters:
    - content_type: Filter by type (checklist, practice_guide, flashcard_deck)
    - limit: Max results (default 20, max 100)
    - offset: Pagination offset
    """
    logger.debug(
        f"List public content request: type={content_type}, "
        f"limit={limit}, offset={offset}"
    )

    # Clamp limit
    limit = min(limit, 100)

    # Build query
    query = select(SharedContent).where(SharedContent.deleted_at.is_(None))

    if content_type:
        query = query.where(SharedContent.content_type == content_type)

    query = query.order_by(SharedContent.created_at.desc()).limit(limit).offset(offset)

    result = await db.execute(query)
    contents = result.scalars().all()

    # Load users for username
    summaries = []
    for content in contents:
        await db.refresh(content, ["user"])
        summaries.append(
            SharedContentSummary(
                id=content.id,
                title=content.title,
                description=content.description,
                content_type=content.content_type,
                tags=content.tags or [],
                public_id=content.public_id,
                author_username=content.user.username,
                view_count=content.view_count,
                fork_count=content.fork_count,
                created_at=content.created_at,
            )
        )

    logger.info(f"Returning {len(summaries)} public content items")
    return summaries


@router.get("/{public_id}", response_model=SharedContentDetail)
async def get_content(
    public_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> SharedContentDetail:
    """
    Get full content by public_id.

    This endpoint is public (no auth required).
    Increments view_count.
    """
    logger.debug(f"Get content request: {public_id}")

    result = await db.execute(
        select(SharedContent).where(
            SharedContent.public_id == public_id,
            SharedContent.deleted_at.is_(None),
        )
    )
    content = result.scalar_one_or_none()

    if content is None:
        logger.warning(f"Content not found: {public_id}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": "content_not_found",
                "detail": f"Content with public_id '{public_id}' not found",
                "suggestion": "Verify the public_id is correct"
            }
        )

    # Increment view count
    try:
        content.view_count += 1
        await db.commit()
        await db.refresh(content, ["user"])
    except Exception as e:
        logger.error(f"Failed to increment view count: {e}")
        # Non-critical error, continue

    logger.info(f"Returning content: {public_id}, view_count: {content.view_count}")

    return SharedContentDetail(
        id=content.id,
        title=content.title,
        description=content.description,
        content_type=content.content_type,
        content_data=content.content_data,
        tags=content.tags or [],
        public_id=content.public_id,
        can_fork=content.can_fork,
        author_username=content.user.username,
        view_count=content.view_count,
        fork_count=content.fork_count,
        created_at=content.created_at,
        updated_at=content.updated_at,
    )


@router.exception_handler(ValidationError)
async def validation_exception_handler(request: Request, exc: ValidationError):
    """Custom handler for Pydantic validation errors."""
    logger.error(f"Validation error: {exc}")
    
    # Extract first error for simplicity
    first_error = exc.errors()[0]
    
    return HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail={
            "error": "validation_error",
            "detail": first_error.get("msg", "Validation failed"),
            "field": ".".join(str(loc) for loc in first_error.get("loc", [])),
            "suggestion": "Check the field format and try again"
        }
    )
```

---

## Part 3: Testing

### File: `tests/test_content_payloads.py` (NEW)

```python
"""Tests for content payload handling."""

import json
import pytest
from uuid import uuid4
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_publish_content_with_nested_json(
    client: AsyncClient, authenticated_user_token: str
):
    """Test that backend correctly handles nested JSON in content_data."""
    checklist_data = {
        "id": str(uuid4()),
        "title": "Test Checklist",
        "sections": [
            {
                "id": str(uuid4()),
                "title": "Safety",
                "items": [
                    {
                        "id": str(uuid4()),
                        "title": "Check life jackets",
                        "is_required": True
                    }
                ]
            }
        ],
        "tags": ["safety"],
        "checklist_type": "general",
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z",
        "sync_status": "synced"
    }
    
    response = await client.post(
        "/api/v1/content/share",
        json={
            "title": "Test Checklist",
            "description": "Test description",
            "content_type": "checklist",
            "content_data": checklist_data,  # Nested object
            "tags": ["test", "safety"],
            "language": "en",
            "public_id": "test-nested-json-123",
            "can_fork": True
        },
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert response.status_code == 201, f"Response: {response.text}"
    data = response.json()
    assert data["public_id"] == "test-nested-json-123"
    assert data["id"] is not None


@pytest.mark.asyncio
async def test_publish_content_with_json_string(
    client: AsyncClient, authenticated_user_token: str
):
    """Test that backend correctly handles JSON string in content_data."""
    checklist_data = {
        "id": str(uuid4()),
        "title": "Test Checklist",
        "sections": [],
        "tags": [],
        "checklist_type": "general",
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z",
        "sync_status": "synced"
    }
    
    # Convert to JSON string (as iOS sends it)
    checklist_json_string = json.dumps(checklist_data)
    
    response = await client.post(
        "/api/v1/content/share",
        json={
            "title": "Test Checklist",
            "description": "Test description",
            "content_type": "checklist",
            "content_data": checklist_json_string,  # JSON string
            "tags": ["test"],
            "language": "en",
            "public_id": "test-json-string-456",
            "can_fork": True
        },
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert response.status_code == 201, f"Response: {response.text}"
    data = response.json()
    assert data["public_id"] == "test-json-string-456"


@pytest.mark.asyncio
async def test_publish_content_missing_required_fields(
    client: AsyncClient, authenticated_user_token: str
):
    """Test validation fails for missing required fields in content_data."""
    response = await client.post(
        "/api/v1/content/share",
        json={
            "title": "Test Checklist",
            "content_type": "checklist",
            "content_data": {
                "id": str(uuid4()),
                # Missing 'title' and 'sections'
            },
            "tags": [],
            "language": "en",
            "public_id": "test-invalid-789",
            "can_fork": True
        },
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert response.status_code == 400
    error = response.json()
    assert "detail" in error
    assert "title" in error["detail"].lower() or "sections" in error["detail"].lower()


@pytest.mark.asyncio
async def test_publish_content_invalid_json_string(
    client: AsyncClient, authenticated_user_token: str
):
    """Test validation fails for invalid JSON string."""
    response = await client.post(
        "/api/v1/content/share",
        json={
            "title": "Test Checklist",
            "content_type": "checklist",
            "content_data": "not-valid-json",  # Invalid JSON
            "tags": [],
            "language": "en",
            "public_id": "test-invalid-json-999",
            "can_fork": True
        },
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert response.status_code == 400
    error = response.json()
    assert "json" in error["detail"].lower()


@pytest.mark.asyncio
async def test_unpublish_content_success(
    client: AsyncClient, authenticated_user_token: str, test_user
):
    """Test successful unpublishing."""
    # First publish content
    publish_response = await client.post(
        "/api/v1/content/share",
        json={
            "title": "Test for Unpublish",
            "content_type": "checklist",
            "content_data": {
                "id": str(uuid4()),
                "title": "Test",
                "sections": []
            },
            "tags": [],
            "language": "en",
            "public_id": "test-unpublish-success",
            "can_fork": True
        },
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    assert publish_response.status_code == 201
    
    # Then unpublish
    unpublish_response = await client.delete(
        "/api/v1/content/test-unpublish-success",
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert unpublish_response.status_code == 204
    
    # Verify it's gone (404)
    get_response = await client.get("/api/v1/content/test-unpublish-success")
    assert get_response.status_code == 404


@pytest.mark.asyncio
async def test_unpublish_content_not_found(
    client: AsyncClient, authenticated_user_token: str
):
    """Test unpublishing non-existent content."""
    response = await client.delete(
        "/api/v1/content/does-not-exist",
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert response.status_code == 404
    error = response.json()
    assert "not_found" in error["detail"]["error"]
```

### File: `tests/test_content_validation.py` (NEW)

```python
"""Tests for content validation logic."""

import pytest
from uuid import uuid4
from app.schemas.content import PublishContentRequest


def test_validate_checklist_valid():
    """Test valid checklist structure."""
    request = PublishContentRequest(
        title="Test Checklist",
        content_type="checklist",
        content_data={
            "id": str(uuid4()),
            "title": "Test",
            "sections": [
                {
                    "id": str(uuid4()),
                    "title": "Section 1",
                    "items": []
                }
            ]
        },
        tags=["test"],
        language="en",
        public_id="test-valid-checklist"
    )
    
    assert request.content_type == "checklist"
    assert isinstance(request.content_data, dict)


def test_validate_checklist_missing_sections():
    """Test checklist validation fails without sections."""
    with pytest.raises(ValueError, match="sections"):
        PublishContentRequest(
            title="Test Checklist",
            content_type="checklist",
            content_data={
                "id": str(uuid4()),
                "title": "Test"
                # Missing 'sections'
            },
            tags=[],
            language="en",
            public_id="test-invalid-checklist"
        )


def test_validate_guide_valid():
    """Test valid practice guide structure."""
    request = PublishContentRequest(
        title="Test Guide",
        content_type="practice_guide",
        content_data={
            "id": str(uuid4()),
            "title": "Test Guide",
            "markdown": "# Guide Content\n\nSome content here."
        },
        tags=["guide"],
        language="en",
        public_id="test-valid-guide"
    )
    
    assert request.content_type == "practice_guide"


def test_validate_guide_missing_markdown():
    """Test guide validation fails without markdown."""
    with pytest.raises(ValueError, match="markdown"):
        PublishContentRequest(
            title="Test Guide",
            content_type="practice_guide",
            content_data={
                "id": str(uuid4()),
                "title": "Test"
                # Missing 'markdown'
            },
            tags=[],
            language="en",
            public_id="test-invalid-guide"
        )
```

---

## Part 4: Deployment Checklist

### Pre-Deployment
- [ ] Review all schema changes
- [ ] Run all tests locally
- [ ] Test with curl/httpie
- [ ] Check database migrations (if needed)

### Deployment Steps
1. [ ] Deploy backend changes
2. [ ] Verify health endpoint
3. [ ] Test publish endpoint with curl
4. [ ] Test unpublish endpoint
5. [ ] Monitor logs for errors

### Post-Deployment
- [ ] Monitor error rates
- [ ] Check sync success rate from iOS
- [ ] Review logged errors
- [ ] Verify JSONB storage in database

---

## Part 5: Monitoring

### Key Metrics
- Request volume per endpoint
- Error rates (400, 409, 500)
- Average response time
- Content validation failures

### Logging Queries
```sql
-- Check recently published content
SELECT public_id, title, content_type, created_at, user_id
FROM shared_content
WHERE deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 20;

-- Check for validation errors (via logs)
-- grep "validation_error" /var/log/anyfleet-backend.log

-- Check sync operation counts
SELECT content_type, COUNT(*) as count
FROM shared_content
WHERE deleted_at IS NULL
GROUP BY content_type;
```

---

## Success Criteria

- [ ] All tests pass
- [ ] iOS can publish with 100% success rate
- [ ] iOS can unpublish with 100% success rate
- [ ] Error messages are actionable
- [ ] JSONB storage works correctly
- [ ] No production errors for 24 hours

