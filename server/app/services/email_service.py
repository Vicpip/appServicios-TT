"""SMTP email service for the client portal.

Reads SMTP configuration from .env via config.py (smtp_host, smtp_port,
smtp_user, smtp_password, portal_base_url).

Public API:
  send_invitation_email(to_email, token, client_name)
  send_password_reset_email(to_email, token)
  send_welcome_email(to_email, name, client_name)
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
# Base template
# ---------------------------------------------------------------------------


def _base_email_template(title: str, body_html: str) -> str:
    logo_url = f"{get_settings().portal_base_url}/static/logo_smp.png"
    return f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{title}</title>
</head>
<body style="margin:0;padding:0;background:#F8FAFF;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0"
         style="background:#F8FAFF;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" border="0"
               style="max-width:600px;background:#ffffff;border-radius:12px;
                      box-shadow:0 4px 24px rgba(15,27,61,0.10);overflow:hidden;">

          <!-- HEADER -->
          <tr>
            <td style="background:#0F1B3D;padding:32px 40px;">
              <img src="{logo_url}"
                   alt="Servicios Main PC"
                   height="48"
                   style="display:block;max-height:48px;width:auto;" />
              <div style="margin-top:8px;font-size:13px;color:#8899CC;
                          letter-spacing:0.5px;">
                Portal de Clientes
              </div>
            </td>
          </tr>

          <!-- BODY -->
          <tr>
            <td style="padding:40px;color:#1A1A2E;line-height:1.6;">
              {body_html}
            </td>
          </tr>

          <!-- FOOTER -->
          <tr>
            <td style="background:#F8FAFF;padding:24px 40px;
                       font-size:12px;color:#8899CC;text-align:center;
                       border-top:1px solid #E2E8F0;">
              &copy; Servicios Main PC &mdash; Este mensaje fue generado
              autom&aacute;ticamente, por favor no responda a este correo.
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""


# ---------------------------------------------------------------------------
# Public functions
# ---------------------------------------------------------------------------


def send_invitation_email(to_email: str, token: str, client_name: str) -> None:
    """Send a portal registration invitation link to a client contact."""
    settings = get_settings()
    link = f"{settings.portal_base_url}/registro?token={token}"
    body = f"""
      <h2 style="margin:0 0 16px;font-size:20px;font-weight:700;color:#0F1B3D;">
        Ha sido invitado al Portal de Clientes
      </h2>
      <p style="margin:0 0 12px;font-size:15px;color:#4A5568;">
        La empresa <strong style="color:#0F1B3D;">{client_name}</strong> ha sido
        registrada en el Portal de Clientes de
        <strong style="color:#0F1B3D;">{_COMPANY}</strong>.
      </p>
      <p style="margin:0 0 24px;font-size:15px;color:#4A5568;">
        Haga clic en el siguiente bot&oacute;n para crear su cuenta.
      </p>
      <a href="{link}"
         style="display:inline-block;background:#1A4FD6;color:#ffffff;
                padding:14px 32px;border-radius:8px;font-size:15px;
                font-weight:600;text-decoration:none;">
        Crear mi cuenta
      </a>
      <p style="margin:16px 0 0;font-size:13px;color:#4A5568;">
        Este enlace es v&aacute;lido por <strong>48 horas</strong>.
      </p>
      <div style="border-top:1px solid #E2E8F0;margin:32px 0;"></div>
      <p style="margin:0 0 8px;font-size:13px;color:#8899CC;">
        Si no esperaba esta invitaci&oacute;n, puede ignorar este mensaje.
      </p>
      <p style="margin:0;font-size:12px;color:#8899CC;">
        Si el bot&oacute;n no funciona, copie y pegue este enlace en su navegador:<br/>
        <a href="{link}" style="color:#1A4FD6;word-break:break-all;">{link}</a>
      </p>
    """
    _send(
        to_email,
        f"Invitación al Portal de Clientes — {_COMPANY}",
        _base_email_template("Invitación", body),
    )


def send_password_reset_email(to_email: str, token: str) -> None:
    """Send a password-reset link to a registered portal user."""
    settings = get_settings()
    link = f"{settings.portal_base_url}/reset-password?token={token}"
    body = f"""
      <h2 style="margin:0 0 16px;font-size:20px;font-weight:700;color:#0F1B3D;">
        Restablecimiento de contrase&ntilde;a
      </h2>
      <p style="margin:0 0 12px;font-size:15px;color:#4A5568;">
        Recibimos una solicitud para restablecer la contrase&ntilde;a de su cuenta
        en el Portal de Clientes de
        <strong style="color:#0F1B3D;">{_COMPANY}</strong>.
      </p>
      <p style="margin:0 0 24px;font-size:15px;color:#4A5568;">
        Haga clic en el siguiente bot&oacute;n para establecer una nueva
        contrase&ntilde;a.
      </p>
      <a href="{link}"
         style="display:inline-block;background:#1A4FD6;color:#ffffff;
                padding:14px 32px;border-radius:8px;font-size:15px;
                font-weight:600;text-decoration:none;">
        Restablecer contrase&ntilde;a
      </a>
      <p style="margin:16px 0 0;font-size:13px;color:#4A5568;">
        Este enlace es v&aacute;lido por <strong>1 hora</strong>.
      </p>
      <div style="border-top:1px solid #E2E8F0;margin:32px 0;"></div>
      <p style="margin:0 0 8px;font-size:13px;color:#8899CC;">
        Si usted no solicit&oacute; este cambio, puede ignorar este mensaje.
        Su contrase&ntilde;a actual no ser&aacute; modificada.
      </p>
      <p style="margin:0;font-size:12px;color:#8899CC;">
        Si el bot&oacute;n no funciona, copie y pegue este enlace en su navegador:<br/>
        <a href="{link}" style="color:#1A4FD6;word-break:break-all;">{link}</a>
      </p>
    """
    _send(
        to_email,
        f"Restablecimiento de contraseña — {_COMPANY}",
        _base_email_template("Restablecer contraseña", body),
    )


def send_welcome_email(to_email: str, name: str, client_name: str = "") -> None:
    """Send a welcome email after successful portal registration."""
    settings = get_settings()
    portal_url = settings.portal_base_url
    company_line = (
        f" de <strong style=\"color:#0F1B3D;\">{client_name}</strong>"
        if client_name
        else ""
    )
    body = f"""
      <h2 style="margin:0 0 16px;font-size:20px;font-weight:700;color:#0F1B3D;">
        &iexcl;Bienvenido al Portal de Clientes!
      </h2>
      <p style="margin:0 0 12px;font-size:15px;color:#4A5568;">
        Hola, <strong style="color:#0F1B3D;">{name}</strong>. Su cuenta{company_line}
        ha sido creada exitosamente en el Portal de Clientes de
        <strong style="color:#0F1B3D;">{_COMPANY}</strong>.
      </p>
      <p style="margin:0 0 8px;font-size:15px;color:#4A5568;">
        Desde el portal podr&aacute; consultar:
      </p>
      <ul style="margin:0 0 24px;padding-left:20px;font-size:15px;color:#4A5568;">
        <li style="margin-bottom:6px;">Sus <strong style="color:#0F1B3D;">impresoras</strong> registradas y su estado</li>
        <li style="margin-bottom:6px;"><strong style="color:#0F1B3D;">Reportes</strong> e historial de servicios t&eacute;cnicos</li>
        <li style="margin-bottom:6px;">Sus <strong style="color:#0F1B3D;">p&oacute;lizas</strong> de mantenimiento activas</li>
      </ul>
      <a href="{portal_url}"
         style="display:inline-block;background:#1A4FD6;color:#ffffff;
                padding:14px 32px;border-radius:8px;font-size:15px;
                font-weight:600;text-decoration:none;">
        Ir al portal
      </a>
    """
    _send(
        to_email,
        f"Bienvenido al Portal de Clientes — {_COMPANY}",
        _base_email_template("Bienvenido", body),
    )
