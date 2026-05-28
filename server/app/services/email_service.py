"""SMTP email service for the client portal.

Reads SMTP configuration from .env via config.py (smtp_host, smtp_port,
smtp_user, smtp_password, portal_base_url).

Public API:
  send_invitation_email(to_email, token, client_name)
  send_password_reset_email(to_email, token)
  send_welcome_email(to_email, name)
"""

import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.config import get_settings

logger = logging.getLogger(__name__)

_SENDER = "noreply@mainservicepc.com"
_COMPANY = "Servicios Main PC"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _build_message(to_email: str, subject: str, html_body: str) -> MIMEMultipart:
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{_COMPANY} <{_SENDER}>"
    msg["To"] = to_email
    msg.attach(MIMEText(html_body, "html", "utf-8"))
    return msg


def _send(to_email: str, subject: str, html_body: str) -> None:
    """Send an email via SMTP.  Logs and swallows errors so a mail failure
    never crashes an API endpoint — callers can check logs.

    Port 1025 is Mailpit's plain-SMTP listener (no TLS).  Any other port
    (e.g. 587) uses STARTTLS as required by real SMTP relays.
    """
    settings = get_settings()
    msg = _build_message(to_email, subject, html_body)
    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
            smtp.ehlo()
            if settings.smtp_port != 1025:
                smtp.starttls()
                smtp.ehlo()
            if settings.smtp_user and settings.smtp_password:
                smtp.login(settings.smtp_user, settings.smtp_password)
            smtp.sendmail(_SENDER, [to_email], msg.as_string())
        logger.info("Email sent to %s | subject: %s", to_email, subject)
    except Exception as exc:  # noqa: BLE001
        logger.error(
            "Failed to send email to %s | subject: %s | error: %s",
            to_email,
            subject,
            exc,
        )


# ---------------------------------------------------------------------------
# Email templates
# ---------------------------------------------------------------------------

def _base_template(title: str, body_html: str) -> str:
    return f"""
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{title}</title>
  <style>
    body {{
      margin: 0; padding: 0; background: #f4f6f9;
      font-family: 'Segoe UI', Arial, sans-serif; color: #333;
    }}
    .wrapper {{ max-width: 600px; margin: 40px auto; background: #ffffff;
                border-radius: 8px; overflow: hidden;
                box-shadow: 0 2px 12px rgba(0,0,0,0.08); }}
    .header {{ background: #1a2e5a; padding: 28px 36px; }}
    .header h1 {{ margin: 0; color: #ffffff; font-size: 20px; font-weight: 600; }}
    .header p  {{ margin: 4px 0 0; color: #a8c0e0; font-size: 13px; }}
    .body {{ padding: 32px 36px; line-height: 1.6; }}
    .body h2 {{ color: #1a2e5a; margin-top: 0; font-size: 18px; }}
    .btn {{
      display: inline-block; margin-top: 24px; padding: 14px 28px;
      background: #2563eb; color: #ffffff !important; text-decoration: none;
      border-radius: 6px; font-weight: 600; font-size: 15px;
    }}
    .footer {{ background: #f4f6f9; padding: 20px 36px;
               font-size: 12px; color: #888; text-align: center; }}
    .divider {{ border: none; border-top: 1px solid #e8ecf0; margin: 24px 0; }}
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <h1>{_COMPANY}</h1>
      <p>Portal de Clientes</p>
    </div>
    <div class="body">
      {body_html}
    </div>
    <div class="footer">
      &copy; {_COMPANY} &mdash; Este mensaje fue generado automáticamente,
      por favor no responda a este correo.
    </div>
  </div>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# Public functions
# ---------------------------------------------------------------------------


def send_invitation_email(to_email: str, token: str, client_name: str) -> None:
    """Send a portal registration invitation link to a client contact."""
    settings = get_settings()
    link = f"{settings.portal_base_url}/registro?token={token}"
    body = f"""
      <h2>Ha sido invitado al Portal de Clientes</h2>
      <p>
        La empresa <strong>{client_name}</strong> ha sido registrada en el
        Portal de Clientes de <strong>{_COMPANY}</strong>.
      </p>
      <p>
        Haga clic en el siguiente botón para crear su cuenta. Este enlace es
        válido por <strong>48 horas</strong>.
      </p>
      <a class="btn" href="{link}">Crear mi cuenta</a>
      <hr class="divider" />
      <p style="font-size:12px;color:#888;">
        Si no esperaba esta invitación, puede ignorar este mensaje.<br/>
        O copie y pegue este enlace en su navegador:<br/>
        <a href="{link}" style="color:#2563eb;">{link}</a>
      </p>
    """
    _send(to_email, f"Invitación al Portal de Clientes — {_COMPANY}", _base_template("Invitación", body))


def send_password_reset_email(to_email: str, token: str) -> None:
    """Send a password-reset link to a registered portal user."""
    settings = get_settings()
    link = f"{settings.portal_base_url}/restablecer?token={token}"
    body = f"""
      <h2>Restablecimiento de contraseña</h2>
      <p>
        Recibimos una solicitud para restablecer la contraseña de su cuenta en
        el Portal de Clientes de <strong>{_COMPANY}</strong>.
      </p>
      <p>
        Haga clic en el siguiente botón para establecer una nueva contraseña.
        Este enlace es válido por <strong>1 hora</strong>.
      </p>
      <a class="btn" href="{link}">Restablecer contraseña</a>
      <hr class="divider" />
      <p style="font-size:12px;color:#888;">
        Si usted no solicitó este cambio, puede ignorar este mensaje. Su
        contraseña actual no será modificada.<br/>
        O copie y pegue este enlace:<br/>
        <a href="{link}" style="color:#2563eb;">{link}</a>
      </p>
    """
    _send(to_email, f"Restablecimiento de contraseña — {_COMPANY}", _base_template("Restablecer contraseña", body))


def send_welcome_email(to_email: str, name: str) -> None:
    """Send a welcome email after successful portal registration."""
    settings = get_settings()
    login_url = f"{settings.portal_base_url}/login"
    body = f"""
      <h2>¡Bienvenido, {name}!</h2>
      <p>
        Su cuenta en el Portal de Clientes de <strong>{_COMPANY}</strong>
        ha sido creada exitosamente.
      </p>
      <p>
        Desde el portal podrá consultar sus impresoras, el historial de
        servicios y sus pólizas activas en cualquier momento.
      </p>
      <a class="btn" href="{login_url}">Ir al Portal</a>
      <hr class="divider" />
      <p style="font-size:12px;color:#888;">
        Si tiene alguna pregunta, póngase en contacto con su técnico asignado.
      </p>
    """
    _send(to_email, f"Bienvenido al Portal de Clientes — {_COMPANY}", _base_template("Bienvenido", body))
