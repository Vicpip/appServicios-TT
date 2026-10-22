from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    database_url: str
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    # Duración del token móvil (días). Se renueva en cada sincronización exitosa
    # (POST /api/auth/refresh), así que la sesión no vence mientras se use la app.
    mobile_token_expire_days: int = 365
    upload_dir: str = "/var/smp/uploads"
    max_file_size_mb: int = 10
    cors_origins: list[str] = ["*"]
    log_level: str = "INFO"
    app_env: str = "production"

    # SMTP — for portal email notifications
    smtp_host: str = "localhost"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""

    # Base URL of the client portal front-end (used in email links)
    portal_base_url: str = "https://clientes.mainservicepc.com"
    api_base_url: str = "https://api.mainservicepc.com"

    # Ligas públicas a PDFs (correos de reportes/entregas): vigencia en días y
    # límite de peticiones por IP del endpoint público (ventana deslizante).
    public_link_expire_days: int = 30
    public_link_rate_limit: int = 60
    public_link_rate_window_seconds: int = 60


@lru_cache()
def get_settings() -> Settings:
    return Settings()
