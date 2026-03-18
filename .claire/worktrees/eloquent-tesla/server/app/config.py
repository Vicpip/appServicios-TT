from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    upload_dir: str = "/var/smp/uploads"
    max_file_size_mb: int = 10
    cors_origins: list[str] = ["*"]
    log_level: str = "INFO"
    app_env: str = "production"

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
