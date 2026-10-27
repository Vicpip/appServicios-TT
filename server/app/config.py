from functools import lru_cache
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Valores que jamás deben usarse como secreto de firma de URLs de archivos.
_INSECURE_SIGNING_SECRETS = {"", "change-me", "changeme", "cambiar-este-secreto"}
_MIN_SIGNING_SECRET_LEN = 32


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

    # URLs firmadas (HMAC) a fotos/firmas/PDFs: secreto y vigencia en segundos.
    # En producción el secreto es obligatorio (>= 32 caracteres) y distinto del
    # valor de ejemplo; si falta, la app no arranca. Generar con: openssl rand -hex 32
    file_signing_secret: str = ""
    file_url_ttl_seconds: int = 3600

    @model_validator(mode="after")
    def _check_file_signing_secret(self) -> "Settings":
        if self.app_env.lower() not in ("production", "prod"):
            return self
        secret = self.file_signing_secret.strip()
        if secret.lower() in _INSECURE_SIGNING_SECRETS or len(secret) < _MIN_SIGNING_SECRET_LEN:
            raise ValueError(
                "FILE_SIGNING_SECRET es obligatorio en producción: defínelo en .env con "
                f"al menos {_MIN_SIGNING_SECRET_LEN} caracteres aleatorios "
                "(openssl rand -hex 32) y distinto del valor de ejemplo."
            )
        return self


@lru_cache()
def get_settings() -> Settings:
    return Settings()
