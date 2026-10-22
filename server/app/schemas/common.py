"""Validadores compartidos por los schemas."""
import re

# Mismo criterio que la app Flutter (isValidEmail): algo@dominio.tld sin espacios.
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def normalize_optional_email(value: str | None) -> str | None:
    """Recorta espacios; vacío -> None; formato inválido -> ValueError (422)."""
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None
    if len(value) > 254 or not _EMAIL_RE.match(value):
        raise ValueError("Correo inválido")
    return value
