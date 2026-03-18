from pydantic import BaseModel


class EntityItem(BaseModel):
    type: str
    data: dict


class EntitiesUpsertRequest(BaseModel):
    entities: list[EntityItem]


class EntitiesUpsertResponse(BaseModel):
    succeeded: int
    failed: int
    errors: list[str]


class SyncPayload(BaseModel):
    """Payload genérico de sincronización."""

    entity_type: str  # 'report' | 'file' | 'signature' | 'printer' | 'client'
    entity_id: str
    payload: dict  # datos del registro


class FileSyncPayload(BaseModel):
    entity_type: str
    entity_id: str
    file_category: str  # 'photo' | 'signature'
    filename: str
    content_type: str


class SyncResponse(BaseModel):
    success: bool
    entity_id: str
    server_id: str | None = None
    message: str = ""
    errors: list[str] = []


class BulkSyncRequest(BaseModel):
    items: list[SyncPayload]


class BulkSyncResponse(BaseModel):
    total: int
    succeeded: int
    failed: int
    results: list[SyncResponse]
