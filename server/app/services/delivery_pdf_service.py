"""Server-side PDF generation for policy delivery receipts using fpdf2."""
from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

from fpdf import FPDF
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models.file import EntityFile, File
from app.models.policy import PolicyDelivery, PolicyDeliveryReport
from app.models.policy import Policy
from app.models.area import Area
from app.models.client import Client
from app.models.plant import Plant
from app.models.printer import Printer
from app.models.report import Report
from app.models.user import User
from app.models.catalog import CatalogModel

log = logging.getLogger(__name__)

_MONTHS: tuple[str, ...] = (
    "Ene", "Feb", "Mar", "Abr", "May", "Jun",
    "Jul", "Ago", "Sep", "Oct", "Nov", "Dic",
)

_CHECKLIST_ITEMS: tuple[str, ...] = (
    "Mantenimiento general",
    "Calibración sensores",
    "Rodillo dañado",
    "Cabezal dañado",
    "Sensor ribbon dañado",
    "Sensor papel dañado",
    "Pruebas",
    "Otros",
)

_DAMAGE_KEYS: frozenset[str] = frozenset({
    "Rodillo dañado",
    "Cabezal dañado",
    "Sensor ribbon dañado",
    "Sensor papel dañado",
})

# Ruta al logo (junto a este mismo archivo → server/app/static/)
_LOGO_PATH = Path(__file__).parent.parent / "static" / "logo_smp.png"


def _fmt_date(dt: Any) -> str:
    if dt is None:
        return "-"
    return f"{dt.day:02d} {_MONTHS[dt.month - 1]} {dt.year}"


def _parse_checkboxes(raw: Any) -> dict:
    try:
        if isinstance(raw, str):
            return json.loads(raw) or {}
        return raw or {}
    except Exception:
        return {}


def _has_damage(checkboxes: dict) -> bool:
    return any(checkboxes.get(k) is True for k in _DAMAGE_KEYS)


def _safe(text: str | None) -> str:
    if not text:
        return "-"
    return (
        text
        .replace("—", "-")
        .replace("–", "-")
        .replace("‘", "'")
        .replace("’", "'")
        .replace("“", '"')
        .replace("”", '"')
        .replace("…", "...")
    )


# ---------------------------------------------------------------------------
# Data container for each report inside the delivery
# ---------------------------------------------------------------------------

class _ReportData:
    __slots__ = ("report", "printer", "client", "plant", "area", "model", "photo_paths", "checkboxes")

    def __init__(
        self,
        report: Report,
        printer: Printer | None,
        client: Client | None,
        plant: Plant | None,
        area: Area | None,
        model: CatalogModel | None,
        photo_paths: list[str],
    ) -> None:
        self.report = report
        self.printer = printer
        self.client = client
        self.plant = plant
        self.area = area
        self.model = model
        self.photo_paths = photo_paths
        self.checkboxes = _parse_checkboxes(report.technical_checkboxes)


# ---------------------------------------------------------------------------
# FPDF subclass with header/footer
# ---------------------------------------------------------------------------

class _DeliveryPDF(FPDF):
    _logo_path: str | None = None
    _policy_folio: str = ""
    _delivery_date_str: str = ""
    _is_cover: bool = True

    def set_meta(self, logo: str | None, folio: str, date_str: str) -> None:
        self._logo_path = logo
        self._policy_folio = folio
        self._delivery_date_str = date_str

    def header(self) -> None:
        # Each page sets its own header via set_meta; the generic fallback
        # just draws a subtle top border so auto_page_break pages look clean.
        self.set_draw_color(200, 200, 200)
        self.line(15, 14, self.w - 15, 14)

    def footer(self) -> None:
        self.set_y(-12)
        self.set_font("Helvetica", "I", 7)
        self.set_text_color(160, 160, 160)
        self.cell(0, 5, f"Pag. {self.page_no()} - Poliza {self._policy_folio}", align="C")


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

MARGIN = 15.0


def _section_title(pdf: FPDF, text: str) -> None:
    """Blue left-bordered section title."""
    pdf.set_fill_color(245, 247, 250)
    pdf.set_draw_color(37, 99, 235)   # #2563eb
    # left border via rect
    pdf.set_fill_color(37, 99, 235)
    pdf.rect(MARGIN, pdf.get_y(), 1.5, 5.5, style="F")
    pdf.set_x(MARGIN + 3)
    pdf.set_font("Helvetica", "B", 8)
    pdf.set_text_color(26, 58, 92)   # #1a3a5c
    pdf.cell(0, 5.5, text, new_x="LMARGIN", new_y="NEXT")
    pdf.set_draw_color(220, 220, 220)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(1.5)


def _info_row(pdf: FPDF, label: str, value: str, lbl_w: float = 22.0, col_w: float = 80.0) -> None:
    y = pdf.get_y()
    pdf.set_xy(pdf.get_x(), y)
    pdf.set_font("Helvetica", "B", 7.5)
    pdf.set_text_color(100, 130, 160)
    pdf.cell(lbl_w, 4.5, f"{label}:")
    pdf.set_font("Helvetica", "", 7.5)
    pdf.set_text_color(30, 30, 30)
    pdf.cell(col_w - lbl_w, 4.5, _safe(value), new_x="LMARGIN", new_y="NEXT")


def _two_col_info(
    pdf: FPDF,
    left_title: str,
    left_rows: list[tuple[str, str]],
    right_title: str,
    right_rows: list[tuple[str, str]],
) -> None:
    W = pdf.w - 2 * MARGIN
    COL_W = W / 2 - 3
    LBL_W = 22.0

    # Left title
    pdf.set_xy(MARGIN, pdf.get_y())
    _draw_col_header(pdf, left_title, MARGIN, COL_W)
    right_x = MARGIN + COL_W + 6
    _draw_col_header(pdf, right_title, right_x, COL_W)
    pdf.ln(0.5)

    row_h = 4.5
    for i in range(max(len(left_rows), len(right_rows))):
        row_y = pdf.get_y()
        if i < len(left_rows):
            lbl, val = left_rows[i]
            pdf.set_xy(MARGIN, row_y)
            pdf.set_font("Helvetica", "B", 7.5)
            pdf.set_text_color(100, 130, 160)
            pdf.cell(LBL_W, row_h, f"{lbl}:")
            pdf.set_font("Helvetica", "", 7.5)
            pdf.set_text_color(30, 30, 30)
            pdf.cell(COL_W - LBL_W, row_h, _safe(val))
        if i < len(right_rows):
            lbl, val = right_rows[i]
            pdf.set_xy(right_x, row_y)
            pdf.set_font("Helvetica", "B", 7.5)
            pdf.set_text_color(100, 130, 160)
            pdf.cell(LBL_W, row_h, f"{lbl}:")
            pdf.set_font("Helvetica", "", 7.5)
            pdf.set_text_color(30, 30, 30)
            pdf.cell(COL_W - LBL_W, row_h, _safe(val))
        pdf.ln(row_h)

    pdf.ln(2)
    pdf.set_draw_color(200, 200, 200)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(3)


def _draw_col_header(pdf: FPDF, title: str, x: float, w: float) -> None:
    pdf.set_xy(x, pdf.get_y())
    pdf.set_font("Helvetica", "B", 7.5)
    pdf.set_text_color(100, 130, 160)
    pdf.cell(w, 5, title, new_x="RIGHT", new_y="TOP")


def _draw_logo_header(
    pdf: FPDF,
    logo_path: str | None,
    title: str,
    subtitle: str,
    date_str: str,
) -> None:
    """Logo + title block at top of a page."""
    LOGO_W = 22.0
    LOGO_H = 22.0
    top_y = 18.0

    if logo_path and Path(logo_path).exists():
        try:
            pdf.image(logo_path, x=MARGIN, y=top_y, w=LOGO_W, h=LOGO_H)
        except Exception:
            pass

    text_x = MARGIN + LOGO_W + 4
    text_w = pdf.w - text_x - MARGIN

    pdf.set_xy(text_x, top_y + 1)
    pdf.set_font("Helvetica", "B", 13)
    pdf.set_text_color(26, 58, 92)
    pdf.cell(text_w, 7, title, align="R", new_x="LMARGIN", new_y="NEXT")

    pdf.set_x(text_x)
    pdf.set_font("Helvetica", "B", 9)
    pdf.set_text_color(37, 99, 235)
    pdf.cell(text_w, 5, subtitle, align="R", new_x="LMARGIN", new_y="NEXT")

    pdf.set_x(text_x)
    pdf.set_font("Helvetica", "", 8)
    pdf.set_text_color(100, 116, 139)
    pdf.cell(text_w, 4.5, f"Fecha de entrega: {date_str}", align="R", new_x="LMARGIN", new_y="NEXT")

    pdf.set_y(top_y + LOGO_H + 3)
    pdf.set_draw_color(26, 58, 92)
    pdf.set_line_width(0.5)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.set_line_width(0.2)
    pdf.ln(4)


def _draw_status_badge(pdf: FPDF, x: float, y: float, w: float, h: float, has_damage: bool) -> None:
    if has_damage:
        pdf.set_fill_color(254, 243, 199)   # #fef3c7
        pdf.set_text_color(146, 64, 14)      # #92400e
        label = "En Atención"
    else:
        pdf.set_fill_color(220, 252, 231)    # #dcfce7
        pdf.set_text_color(22, 101, 52)      # #166534
        label = "Correcto"
    pdf.set_xy(x, y)
    pdf.set_font("Helvetica", "B", 7)
    pdf.cell(w, h, label, fill=True, align="C")
    pdf.set_text_color(30, 30, 30)


def _draw_checklist_badge(pdf: FPDF, x: float, y: float, w: float, h: float, checked: bool) -> None:
    if checked:
        pdf.set_fill_color(220, 252, 231)    # #dcfce7
        pdf.set_text_color(22, 101, 52)      # #166534
        label = "Sí"
    else:
        pdf.set_fill_color(243, 244, 246)    # #f3f4f6
        pdf.set_text_color(55, 65, 81)       # #374151
        label = "No"
    pdf.set_xy(x, y)
    pdf.set_font("Helvetica", "B", 7)
    pdf.cell(w, h, label, fill=True, align="C")
    pdf.set_text_color(30, 30, 30)


def _draw_signatures(
    pdf: FPDF,
    tech_name: str,
    tech_sig_path: str | None,
    client_name: str,
    client_role: str,
    client_sig_path: str | None,
) -> None:
    W = pdf.w - 2 * MARGIN
    COL_W = W / 2 - 3

    _section_title(pdf, "FIRMAS")

    sig_y = pdf.get_y()

    # Tech column
    _draw_one_sig_box(
        pdf,
        x=MARGIN,
        y=sig_y,
        w=COL_W,
        title="FIRMA DEL TÉCNICO",
        name=tech_name,
        role=None,
        sig_path=tech_sig_path,
    )

    # Client column
    _draw_one_sig_box(
        pdf,
        x=MARGIN + COL_W + 6,
        y=sig_y,
        w=COL_W,
        title="FIRMA DE CONFORMIDAD DEL CLIENTE",
        name=client_name,
        role=client_role,
        sig_path=client_sig_path,
    )


def _draw_one_sig_box(
    pdf: FPDF,
    x: float,
    y: float,
    w: float,
    title: str,
    name: str,
    role: str | None,
    sig_path: str | None,
) -> None:
    LBL_W = 18.0
    pdf.set_xy(x, y)
    pdf.set_font("Helvetica", "B", 7.5)
    pdf.set_text_color(100, 130, 160)
    pdf.cell(w, 4.5, title, new_x="LEFT", new_y="NEXT")
    pdf.set_x(x)
    pdf.set_draw_color(220, 220, 220)
    pdf.line(x, pdf.get_y(), x + w, pdf.get_y())
    pdf.ln(1)

    pdf.set_xy(x, pdf.get_y())
    pdf.set_font("Helvetica", "B", 7.5)
    pdf.set_text_color(100, 130, 160)
    pdf.cell(LBL_W, 4.5, "Nombre:")
    pdf.set_font("Helvetica", "", 7.5)
    pdf.set_text_color(30, 30, 30)
    pdf.cell(w - LBL_W, 4.5, _safe(name), new_x="LEFT", new_y="NEXT")
    pdf.set_x(x)

    if role is not None:
        pdf.set_font("Helvetica", "B", 7.5)
        pdf.set_text_color(100, 130, 160)
        pdf.cell(LBL_W, 4.5, "Cargo:")
        pdf.set_font("Helvetica", "", 7.5)
        pdf.set_text_color(30, 30, 30)
        pdf.cell(w - LBL_W, 4.5, _safe(role), new_x="LEFT", new_y="NEXT")
        pdf.set_x(x)
    else:
        pdf.ln(4.5)  # spacer to align signature box with client side

    pdf.ln(2)
    box_y = pdf.get_y()
    box_h = 22.0
    pdf.set_draw_color(200, 200, 200)
    pdf.rect(x, box_y, w, box_h)

    if sig_path and Path(sig_path).exists():
        try:
            pdf.image(sig_path, x=x + 2, y=box_y + 1, w=w - 4, h=box_h - 2)
        except Exception:
            pass
    else:
        pdf.set_xy(x, box_y + box_h / 2 - 2)
        pdf.set_font("Helvetica", "I", 7)
        pdf.set_text_color(180, 180, 180)
        pdf.cell(w, 4, "Sin firma", align="C")
        pdf.set_text_color(30, 30, 30)

    pdf.set_y(box_y + box_h + 2)


def _draw_equipment_table(pdf: FPDF, report_data: list[_ReportData]) -> None:
    W = pdf.w - 2 * MARGIN
    _section_title(pdf, f"EQUIPOS ATENDIDOS ({len(report_data)})")

    # Column widths (total = W ≈ 180 mm)
    # #(8) | Modelo(38) | Serie(32) | Planta(24) | Área(24) | Tipo(24) | Estado(30)
    cols = [8.0, 38.0, 32.0, 24.0, 24.0, 24.0, 30.0]
    headers = ["#", "Modelo", "Serie", "Planta", "Área", "Tipo servicio", "Estado"]
    row_h = 5.5

    # Header row
    pdf.set_fill_color(245, 247, 250)
    pdf.set_draw_color(209, 213, 219)
    x = MARGIN
    header_y = pdf.get_y()
    for i, (hdr, cw) in enumerate(zip(headers, cols)):
        pdf.set_xy(x, header_y)
        pdf.set_font("Helvetica", "B", 7)
        pdf.set_text_color(26, 58, 92)
        pdf.cell(cw, row_h, hdr, border=1, fill=True, align="C")
        x += cw
    pdf.ln(row_h)

    # Data rows
    for idx, rd in enumerate(report_data):
        model_str = _safe(
            f"{rd.model.brand} {rd.model.model_name}" if rd.model else None
        )
        serial = _safe(rd.printer.serial_number if rd.printer else rd.report.printer_id[:8])
        plant_name = _safe(rd.plant.name if rd.plant else None)
        area_name = _safe(rd.area.name if rd.area else None)
        service_type = _safe(rd.report.service_type)
        damage = _has_damage(rd.checkboxes)

        fill_color = (255, 255, 255) if idx % 2 == 0 else (248, 250, 252)
        pdf.set_fill_color(*fill_color)

        row_y = pdf.get_y()
        x = MARGIN
        values = [str(idx + 1), model_str, serial, plant_name, area_name, service_type]
        for i, (val, cw) in enumerate(zip(values, cols[:-1])):
            pdf.set_xy(x, row_y)
            pdf.set_font("Helvetica", "", 7)
            pdf.set_text_color(30, 30, 30)
            pdf.cell(cw, row_h, val, border=1, fill=True)
            x += cw

        # Status badge cell
        badge_x = x
        pdf.set_xy(badge_x, row_y)
        pdf.set_fill_color(*fill_color)
        pdf.cell(cols[-1], row_h, "", border=1, fill=True)
        _draw_status_badge(pdf, badge_x + 1, row_y + 0.75, cols[-1] - 2, row_h - 1.5, damage)

        pdf.ln(row_h)

    pdf.ln(3)
    pdf.set_draw_color(200, 200, 200)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(3)


def _draw_checklist(pdf: FPDF, checkboxes: dict) -> None:
    W = pdf.w - 2 * MARGIN
    _section_title(pdf, "LISTA TÉCNICA DE VERIFICACIÓN")

    ITEM_COL_W = W * 0.72
    BADGE_W = 10.0
    ROW_H = 5.0
    GAP = 4.0

    # Two-column layout
    half = len(_CHECKLIST_ITEMS) // 2 + len(_CHECKLIST_ITEMS) % 2
    left_items = _CHECKLIST_ITEMS[:half]
    right_items = _CHECKLIST_ITEMS[half:]
    right_x = MARGIN + (W / 2) + 2

    for i in range(max(len(left_items), len(right_items))):
        row_y = pdf.get_y()

        if i < len(left_items):
            item = left_items[i]
            checked = checkboxes.get(item) is True
            pdf.set_xy(MARGIN, row_y)
            pdf.set_font("Helvetica", "", 7.5)
            pdf.set_text_color(30, 30, 30)
            pdf.cell(W / 2 - BADGE_W - GAP, ROW_H, item)
            _draw_checklist_badge(pdf, MARGIN + W / 2 - BADGE_W - GAP - 2, row_y + 0.5, BADGE_W, ROW_H - 1, checked)

        if i < len(right_items):
            item = right_items[i]
            checked = checkboxes.get(item) is True
            pdf.set_xy(right_x, row_y)
            pdf.set_font("Helvetica", "", 7.5)
            pdf.set_text_color(30, 30, 30)
            pdf.cell(W / 2 - BADGE_W - GAP, ROW_H, item)
            _draw_checklist_badge(pdf, right_x + W / 2 - BADGE_W - GAP - 2, row_y + 0.5, BADGE_W, ROW_H - 1, checked)

        pdf.ln(ROW_H)

    pdf.ln(2)
    pdf.set_draw_color(200, 200, 200)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(3)


def _draw_photos(pdf: FPDF, photo_paths: list[str]) -> None:
    if not photo_paths:
        return
    W = pdf.w - 2 * MARGIN
    _section_title(pdf, "EVIDENCIA FOTOGRÁFICA")
    PHOTOS_PER_ROW = 3
    gap = 3.0
    img_w = (W - gap * (PHOTOS_PER_ROW - 1)) / PHOTOS_PER_ROW
    img_h = img_w * 0.65  # approx 4:3

    for row_start in range(0, len(photo_paths), PHOTOS_PER_ROW):
        row = photo_paths[row_start: row_start + PHOTOS_PER_ROW]
        row_y = pdf.get_y()
        if pdf.get_y() + img_h + 5 > pdf.h - 20:
            pdf.add_page()
            pdf.ln(5)
            row_y = pdf.get_y()
        for j, path in enumerate(row):
            if not Path(path).exists():
                continue
            try:
                x = MARGIN + j * (img_w + gap)
                pdf.image(path, x=x, y=row_y, w=img_w, h=img_h)
                pdf.set_draw_color(200, 200, 200)
                pdf.rect(x, row_y, img_w, img_h)
            except Exception:
                pass
        pdf.set_y(row_y + img_h + gap)

    pdf.ln(3)
    pdf.set_draw_color(200, 200, 200)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(3)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def generate_delivery_pdf(delivery_id: str, db: Session) -> str | None:
    """Generate the policy delivery PDF and return its relative path.

    Returns None on any failure so the caller can treat it as non-fatal.
    """
    settings = get_settings()

    try:
        delivery: PolicyDelivery | None = db.get(PolicyDelivery, delivery_id)
        if not delivery:
            log.warning("generate_delivery_pdf: delivery %s not found", delivery_id)
            return None

        policy: Policy | None = db.get(Policy, delivery.policy_id)
        client: Client | None = db.get(Client, policy.client_id) if policy else None
        tech: User | None = db.get(User, delivery.tech_id)
        tech_name = tech.name if tech else "No especificado"

        # Resolve tech signature path
        tech_sig_path: str | None = None
        if tech and tech.signature_path:
            p = Path(tech.signature_path)
            if not p.is_absolute():
                p = Path(settings.upload_dir) / p
            if p.exists():
                tech_sig_path = str(p)

        # Resolve client (delivery) signature path via EntityFile
        client_sig_path: str | None = None
        ef_sig = (
            db.query(EntityFile)
            .filter(
                EntityFile.entity_id == delivery_id,
                EntityFile.entity_type == "signature",
            )
            .join(EntityFile.file)
            .first()
        )
        if ef_sig and ef_sig.file and Path(ef_sig.file.storage_path).exists():
            client_sig_path = ef_sig.file.storage_path

        # Load all delivery reports
        dr_rows = (
            db.query(PolicyDeliveryReport)
            .filter(PolicyDeliveryReport.delivery_id == delivery_id)
            .all()
        )

        report_data: list[_ReportData] = []
        for dr in dr_rows:
            report: Report | None = db.get(Report, dr.report_id)
            if not report:
                continue

            printer: Printer | None = db.query(Printer).filter(Printer.id == report.printer_id).first()
            plant: Plant | None = db.get(Plant, printer.plant_id) if printer and printer.plant_id else None
            area: Area | None = db.get(Area, printer.area_id) if printer and printer.area_id else None
            model: CatalogModel | None = db.get(CatalogModel, printer.model_id) if printer and printer.model_id else None

            # Photos from EntityFile (server-stored, not device paths)
            ef_photos = (
                db.query(EntityFile)
                .filter(
                    EntityFile.entity_id == report.id,
                    EntityFile.entity_type == "report",
                    EntityFile.file_category == "photo",
                )
                .join(EntityFile.file)
                .all()
            )
            photo_paths = [
                ef.file.storage_path
                for ef in ef_photos
                if ef.file and Path(ef.file.storage_path).exists()
            ]

            report_data.append(
                _ReportData(
                    report=report,
                    printer=printer,
                    client=client,
                    plant=plant,
                    area=area,
                    model=model,
                    photo_paths=photo_paths,
                )
            )

        # ── Build PDF ────────────────────────────────────────────────────────
        logo_path = str(_LOGO_PATH) if _LOGO_PATH.exists() else None
        folio = policy.folio if policy else delivery.policy_id[:8]
        date_str = _fmt_date(delivery.delivery_date)

        pdf = _DeliveryPDF(orientation="P", unit="mm", format="A4")
        pdf.set_auto_page_break(auto=True, margin=20)
        pdf.set_meta(logo_path, folio, date_str)
        pdf.set_margins(MARGIN, 15, MARGIN)

        # ── Page 1: Cover ────────────────────────────────────────────────────
        pdf.add_page()
        _draw_logo_header(pdf, logo_path, "ACTA DE ENTREGA DE PÓLIZA", f"Póliza: {folio}", date_str)

        # Client + Policy info (two columns)
        coverage = _safe(policy.coverage_type) if policy else "-"
        vigencia = (
            f"{_fmt_date(policy.start_date)} - {_fmt_date(policy.end_date)}"
            if policy else "-"
        )
        _two_col_info(
            pdf,
            left_title="DATOS DEL CLIENTE",
            left_rows=[
                ("Cliente", client.name if client else "-"),
                ("RFC", client.rfc if client else "-"),
                ("Direccion", client.address if client else "-"),
            ],
            right_title="DATOS DE LA PÓLIZA",
            right_rows=[
                ("Folio", folio),
                ("Cobertura", coverage),
                ("Vigencia", vigencia),
                ("Técnico", tech_name),
            ],
        )

        # Equipment table
        _draw_equipment_table(pdf, report_data)

        # Signatures
        _draw_signatures(
            pdf,
            tech_name=tech_name,
            tech_sig_path=tech_sig_path,
            client_name=delivery.signature_name,
            client_role=delivery.signature_role,
            client_sig_path=client_sig_path,
        )

        # ── Pages per report ─────────────────────────────────────────────────
        for i, rd in enumerate(report_data):
            pdf.add_page()

            # Mini header for this report page
            report_code = rd.report.code or f"R-{rd.report.id[:8].upper()}"
            _draw_logo_header(
                pdf,
                logo_path,
                f"RESUMEN DE SERVICIO - Equipo {i + 1}/{len(report_data)}",
                f"Póliza: {folio}  |  {report_code}",
                date_str,
            )

            # Client + Printer info
            model_str = _safe(
                f"{rd.model.brand} {rd.model.model_name} {rd.model.dpi}dpi"
                if rd.model else None
            )
            printer_code = _safe(rd.printer.code if rd.printer else None)
            serial = _safe(rd.printer.serial_number if rd.printer else None)

            _two_col_info(
                pdf,
                left_title="INFORMACION DEL CLIENTE",
                left_rows=[
                    ("Nombre", client.name if client else "-"),
                    ("RFC", client.rfc if client else "-"),
                    ("Direccion", client.address if client else "-"),
                    ("Planta", rd.plant.name if rd.plant else "-"),
                    ("Area", rd.area.name if rd.area else "-"),
                ],
                right_title="DATOS DE LA IMPRESORA",
                right_rows=[
                    ("Codigo", printer_code),
                    ("Serie", f"S/N: {serial}"),
                    ("Modelo", model_str),
                    ("Contador", f"{rd.report.linear_inches_counter} pulg." if rd.report.linear_inches_counter is not None else "-"),
                    ("Temperatura", str(rd.report.darkness_level) if rd.report.darkness_level is not None else "-"),
                ],
            )

            # Checklist
            _draw_checklist(pdf, rd.checkboxes)

            # Notes
            if rd.report.notes:
                _section_title(pdf, "NOTAS DEL SERVICIO")
                pdf.set_font("Helvetica", "", 8)
                pdf.set_text_color(30, 30, 30)
                pdf.multi_cell(pdf.w - 2 * MARGIN, 4.5, _safe(rd.report.notes))
                pdf.ln(2)
                pdf.set_draw_color(200, 200, 200)
                pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
                pdf.ln(3)

            # Photos
            _draw_photos(pdf, rd.photo_paths)

            # Tech signature only on report pages
            _section_title(pdf, "FIRMA DEL TÉCNICO")
            pdf.set_font("Helvetica", "B", 7.5)
            pdf.set_text_color(100, 130, 160)
            pdf.cell(20, 4.5, "Nombre:")
            pdf.set_font("Helvetica", "", 7.5)
            pdf.set_text_color(30, 30, 30)
            pdf.cell(0, 4.5, _safe(tech_name), new_x="LMARGIN", new_y="NEXT")
            pdf.ln(2)
            sig_box_y = pdf.get_y()
            sig_box_h = 20.0
            sig_box_w = (pdf.w - 2 * MARGIN) / 2
            pdf.set_draw_color(200, 200, 200)
            pdf.rect(MARGIN, sig_box_y, sig_box_w, sig_box_h)
            if tech_sig_path:
                try:
                    pdf.image(tech_sig_path, x=MARGIN + 2, y=sig_box_y + 1, w=sig_box_w - 4, h=sig_box_h - 2)
                except Exception:
                    pass
            pdf.set_y(sig_box_y + sig_box_h + 3)

        # ── Save PDF to disk ─────────────────────────────────────────────────
        out_dir = Path(settings.upload_dir) / "deliveries"
        out_dir.mkdir(parents=True, exist_ok=True)
        out_filename = f"delivery_{delivery_id}_resumen.pdf"
        out_path = out_dir / out_filename
        out_path.write_bytes(bytes(pdf.output()))

        relative_path = f"uploads/deliveries/{out_filename}"
        log.info("generate_delivery_pdf: saved %s", relative_path)
        return relative_path

    except Exception:
        log.exception("generate_delivery_pdf: unexpected error for delivery %s", delivery_id)
        return None
