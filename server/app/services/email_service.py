"""SMTP email service for the client portal.

Reads SMTP configuration from .env via config.py (smtp_host, smtp_port,
smtp_user, smtp_password, portal_base_url).

Public API:
  send_invitation_email(to_email, token, client_name)
  send_password_reset_email(to_email, token)
  send_welcome_email(to_email, name, client_name)
  send_service_report_email(to_emails, client_name, tech_name, printer_serial,
                             printer_model, service_date, folio, pdf_url)
  send_delivery_email(to_emails, client_name, policy_folio, delivery_date,
                      signer_name, signer_role, equipment, summary_url)

Los correos de reportes/entregas NO adjuntan PDFs: llevan ligas públicas con
vigencia (ver share_link_service). Todo el envío SMTP pasa por
_smtp_deliver(), que las pruebas reemplazan por un backend falso.
"""

import html
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


def _smtp_deliver(recipients: list[str], message: str) -> None:
    """Entrega un mensaje ya armado por SMTP. Lanza si falla.

    Port 1025 is Mailpit's plain-SMTP listener (no TLS).  Any other port
    (e.g. 587) uses STARTTLS as required by real SMTP relays.
    """
    settings = get_settings()
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
        smtp.ehlo()
        if settings.smtp_port != 1025:
            smtp.starttls()
            smtp.ehlo()
        if settings.smtp_user and settings.smtp_password:
            smtp.login(settings.smtp_user, settings.smtp_password)
        smtp.sendmail(_SENDER, recipients, message)


def _send(to_email: str, subject: str, html_body: str) -> None:
    """Send an email via SMTP.  Logs and swallows errors so a mail failure
    never crashes an API endpoint — callers can check logs.
    """
    msg = _build_message(to_email, subject, html_body)
    try:
        _smtp_deliver([to_email], msg.as_string())
        logger.info("Email sent to %s | subject: %s", to_email, subject)
    except Exception as exc:  # noqa: BLE001
        logger.error(
            "Failed to send email to %s | subject: %s | error: %s",
            to_email,
            subject,
            exc,
        )


def _send_many(to_emails: list[str], subject: str, html_body: str) -> bool:
    """Un solo mensaje para varios destinatarios. True si se entregó al SMTP."""
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{_COMPANY} <{_SENDER}>"
    msg["To"] = ", ".join(to_emails)
    msg.attach(MIMEText(html_body, "html", "utf-8"))
    try:
        _smtp_deliver(to_emails, msg.as_string())
        logger.info("Email sent to %s | subject: %s", to_emails, subject)
        return True
    except Exception as exc:  # noqa: BLE001
        logger.error(
            "Failed to send email to %s | subject: %s | error: %s",
            to_emails,
            subject,
            exc,
        )
        return False


# ---------------------------------------------------------------------------
# Base template
# ---------------------------------------------------------------------------


def _base_email_template(title: str, body_html: str) -> str:
    logo_url = f"{get_settings().api_base_url}/static/logo_smp.png"
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


def _e(value: object) -> str:
    return html.escape("" if value is None else str(value))


def _link_button(url: str, label: str) -> str:
    return f"""
      <a href="{_e(url)}"
         style="display:inline-block;background:#1A4FD6;color:#ffffff;
                padding:14px 32px;border-radius:8px;font-size:15px;
                font-weight:600;text-decoration:none;">
        {_e(label)}
      </a>"""


def _link_footer(url: str, expire_days: int) -> str:
    return f"""
      <p style="margin:16px 0 0;font-size:13px;color:#4A5568;">
        Las ligas son personales y v&aacute;lidas por
        <strong>{int(expire_days)} d&iacute;as</strong>. No las comparta con
        terceros.
      </p>
      <p style="margin:12px 0 0;font-size:12px;color:#8899CC;">
        Si el bot&oacute;n no funciona, copie y pegue este enlace en su navegador:<br/>
        <a href="{_e(url)}" style="color:#1A4FD6;word-break:break-all;">{_e(url)}</a>
      </p>"""


def _info_row(label: str, value_html: str, last: bool = False) -> str:
    border = "" if last else "border-bottom:1px solid #E2E8F0;"
    return f"""
        <tr>
          <td style="padding:10px 14px;font-size:13px;color:#8899CC;{border}">{label}</td>
          <td style="padding:10px 14px;font-size:14px;color:#1A1A2E;font-weight:600;{border}">{value_html}</td>
        </tr>"""


def send_service_report_email(
    to_emails: list[str],
    client_name: str,
    tech_name: str,
    printer_serial: str,
    printer_model: str,
    service_date: str,
    folio: str,
    pdf_url: str,
    expire_days: int | None = None,
) -> bool:
    """Send a service report link to one or more client contact emails.

    El PDF ya no se adjunta: el correo lleva una liga pública con vigencia.
    Non-fatal: exceptions are caught and logged, same behavior as the other
    functions in this module — a mail failure never crashes the caller.
    Devuelve True si el mensaje se entregó al servidor SMTP.
    """
    expire_days = expire_days or get_settings().public_link_expire_days
    subject = f"Reporte de servicio {folio} — {client_name}"
    body = f"""
      <h2 style="margin:0 0 16px;font-size:20px;font-weight:700;color:#1A3557;">
        Reporte de servicio t&eacute;cnico
      </h2>
      <p style="margin:0 0 20px;font-size:15px;color:#4A5568;">
        Ya est&aacute; disponible el reporte del servicio realizado a su equipo por
        <strong style="color:#1A3557;">{_COMPANY}</strong>.
      </p>
      <table width="100%" cellpadding="0" cellspacing="0" border="0"
             style="border-collapse:collapse;margin:0 0 24px;">
        <tr>
          <td colspan="2" style="background:#1A3557;color:#ffffff;padding:10px 14px;
                                  font-size:13px;font-weight:700;letter-spacing:0.5px;">
            DETALLE DEL SERVICIO
          </td>
        </tr>
        {_info_row("Folio", _e(folio))}
        {_info_row("Equipo", f"{_e(printer_serial)} &mdash; {_e(printer_model)}")}
        {_info_row("T&eacute;cnico", _e(tech_name))}
        {_info_row("Fecha de servicio", _e(service_date), last=True)}
      </table>
      {_link_button(pdf_url, "Ver reporte (PDF)")}
      {_link_footer(pdf_url, expire_days)}
    """
    return _send_many(
        to_emails, subject, _base_email_template("Reporte de servicio", body)
    )


def send_delivery_email(
    to_emails: list[str],
    client_name: str,
    policy_folio: str,
    delivery_date: str,
    signer_name: str,
    signer_role: str,
    equipment: list[dict],
    summary_url: str,
    expire_days: int | None = None,
) -> bool:
    """Un solo correo por entrega de póliza, con ligas (sin PDFs adjuntos).

    ``equipment``: [{"model", "serial", "service_type", "url" (str | None)}].
    Devuelve True si el mensaje se entregó al servidor SMTP.
    """
    expire_days = expire_days or get_settings().public_link_expire_days
    subject = f"Entrega de póliza {policy_folio} — {client_name}"

    rows = ""
    for item in equipment:
        url = item.get("url")
        cell = (
            f'<a href="{_e(url)}" style="color:#1A4FD6;font-weight:600;">Ver PDF</a>'
            if url
            else '<span style="color:#8899CC;">No disponible</span>'
        )
        rows += f"""
        <tr>
          <td style="padding:10px 14px;font-size:13px;color:#1A1A2E;border-bottom:1px solid #E2E8F0;">{_e(item.get("model"))}</td>
          <td style="padding:10px 14px;font-size:13px;color:#1A1A2E;font-weight:600;border-bottom:1px solid #E2E8F0;">{_e(item.get("serial"))}</td>
          <td style="padding:10px 14px;font-size:13px;color:#1A1A2E;border-bottom:1px solid #E2E8F0;">{_e(item.get("service_type"))}</td>
          <td style="padding:10px 14px;font-size:13px;border-bottom:1px solid #E2E8F0;">{cell}</td>
        </tr>"""

    body = f"""
      <h2 style="margin:0 0 16px;font-size:20px;font-weight:700;color:#1A3557;">
        Entrega de servicio de p&oacute;liza
      </h2>
      <p style="margin:0 0 20px;font-size:15px;color:#4A5568;">
        <strong style="color:#1A3557;">{_COMPANY}</strong> concluy&oacute; la entrega
        de los servicios de su p&oacute;liza. A continuaci&oacute;n el resumen y las
        ligas a los reportes de cada equipo.
      </p>
      <table width="100%" cellpadding="0" cellspacing="0" border="0"
             style="border-collapse:collapse;margin:0 0 24px;">
        <tr>
          <td colspan="2" style="background:#1A3557;color:#ffffff;padding:10px 14px;
                                  font-size:13px;font-weight:700;letter-spacing:0.5px;">
            DETALLE DE LA ENTREGA
          </td>
        </tr>
        {_info_row("Folio de p&oacute;liza", _e(policy_folio))}
        {_info_row("Cliente", _e(client_name))}
        {_info_row("Fecha", _e(delivery_date))}
        {_info_row("Firm&oacute;", f"{_e(signer_name)} ({_e(signer_role)})")}
        {_info_row("Equipos entregados", str(len(equipment)), last=True)}
      </table>
      <table width="100%" cellpadding="0" cellspacing="0" border="0"
             style="border-collapse:collapse;margin:0 0 24px;">
        <tr>
          <td colspan="4" style="background:#1A3557;color:#ffffff;padding:10px 14px;
                                  font-size:13px;font-weight:700;letter-spacing:0.5px;">
            EQUIPOS
          </td>
        </tr>
        <tr style="background:#F8FAFF;">
          <td style="padding:8px 14px;font-size:12px;color:#8899CC;">Modelo</td>
          <td style="padding:8px 14px;font-size:12px;color:#8899CC;">Serie</td>
          <td style="padding:8px 14px;font-size:12px;color:#8899CC;">Servicio</td>
          <td style="padding:8px 14px;font-size:12px;color:#8899CC;">Reporte</td>
        </tr>
        {rows}
      </table>
      {_link_button(summary_url, "Ver resumen de la entrega (PDF)")}
      {_link_footer(summary_url, expire_days)}
    """
    return _send_many(
        to_emails, subject, _base_email_template("Entrega de póliza", body)
    )
