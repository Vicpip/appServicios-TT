"""Server-side PDF generation for policy delivery receipts using fpdf2."""
from __future__ import annotations

import json
import logging
from io import BytesIO
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

_LOGO_PATH = Path(__file__).parent.parent / "static" / "logo_smp.png"
_DEJAVU_REG_PATH = Path(__file__).parent.parent / "static" / "DejaVuSans.ttf"
_DEJAVU_BOLD_PATH = Path(__file__).parent.parent / "static" / "DejaVuSans-Bold.ttf"


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
    text = (
        text
        .replace("—", "-")
        .replace("–", "-")
        .replace("‘", "'")
        .replace("’", "'")
        .replace("“", '"')
        .replace("”", '"')
        .replace("…", "...")
    )
    # Strip chars outside Latin-1 so core PDF fonts never throw
    return text.encode("latin-1", errors="replace").decode("latin-1")


def _corrected_image_bytes(path: str) -> BytesIO | None:
    """Return BytesIO with EXIF-orientation-corrected image, or None on failure."""
    try:
        from PIL import Image  # type: ignore[import]
        img = Image.open(path)
        orientation: int | None = None
        try:
            exif_data = img._getexif()  # type: ignore[attr-defined]
            if exif_data:
                orientation = exif_data.get(274)
        except Exception:
            pass
        if orientation == 3:
            img = img.rotate(180, expand=True)
        elif orientation == 6:
            img = img.rotate(270, expand=True)
        elif orientation == 8:
            img = img.rotate(90, expand=True)
        buf = BytesIO()
        img.save(buf, format="JPEG")
        buf.seek(0)
        return buf
    except Exception:
        return None


def _image_aspect(src: str | BytesIO) -> float | None:
    """Return height/width ratio using Pillow, or None if unavailable."""
    try:
        from PIL import Image  # type: ignore[import]
        if isinstance(src, BytesIO):
            src.seek(0)
            img = Image.open(src)
            src.seek(0)
        else:
            img = Image.open(src)
        w, h = img.size
        return h / w if w > 0 else None
    except Exception:
        return None


def _logo_dimensions(logo_path: str, desired_w: float) -> tuple[float, float]:
    """Return (w, h) for logo preserving its aspect ratio."""
    ratio = _image_aspect(logo_path)
    if ratio:
        return desired_w, desired_w * ratio
    return desired_w, desired_w  # fallback: square


# ---------------------------------------------------------------------------
# Data container
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
    _font_family: str = "Helvetica"

    def set_meta(self, logo: str | None, folio: str, date_str: str) -> None:
        self._logo_path = logo
        self._policy_folio = folio
        self._delivery_date_str = date_str

    def setup_fonts(self) -> None:
        """Register DejaVu Unicode font if .ttf files exist, else keep Helvetica."""
        if _DEJAVU_REG_PATH.exists():
            try:
                self.add_font("DejaVu", "", str(_DEJAVU_REG_PATH), uni=True)
                bold_src = _DEJAVU_BOLD_PATH if _DEJAVU_BOLD_PATH.exists() else _DEJAVU_REG_PATH
                self.add_font("DejaVu", "B", str(bold_src), uni=True)
                self._font_family = "DejaVu"
            except Exception:
                pass

    def header(self) -> None:
        self.set_draw_color(200, 200, 200)
        self.line(15, 14, self.w - 15, 14)

    def footer(self) -> None:
        self.set_y(-12)
        self.set_font(self._font_family, "", 8)
        self.set_text_color(160, 160, 160)
        # {nb} is replaced by fpdf2 alias_nb_pages() with the actual total
        page_text = (
            "Documento generado por Servicios Main PC App"
            f" | P\xe1g. {self.page_no()} / "
        ) + "{nb}"
        self.cell(0, 5, page_text, align="C")


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

MARGIN = 15.0


def _section_title(pdf: _DeliveryPDF, text: str) -> None:
    """Blue left-bordered section title matching Flutter style."""
    BAR_W = 3.0
    ROW_H = 7.0
    y = pdf.get_y()
    pdf.set_fill_color(37, 99, 235)    # #2563eb
    pdf.rect(MARGIN, y, BAR_W, ROW_H, style="F")
    pdf.set_x(MARGIN + BAR_W + 3)
    pdf.set_font(pdf._font_family, "B", 11)
    pdf.set_text_color(26, 58, 92)     # #1a3a5c
    pdf.cell(0, ROW_H, text.upper(), new_x="LMARGIN", new_y="NEXT")
    pdf.set_draw_color(220, 220, 220)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(2)


def _info_row(pdf: _DeliveryPDF, label: str, value: str, lbl_w: float = 24.0, col_w: float = 85.0) -> None:
    """Label in normal weight, value in bold — matching Flutter style."""
    pdf.set_font(pdf._font_family, "", 10)
    pdf.set_text_color(100, 130, 160)
    pdf.cell(lbl_w, 6.5, f"{label}:")
    pdf.set_font(pdf._font_family, "B", 10)
    pdf.set_text_color(30, 30, 30)
    pdf.cell(col_w - lbl_w, 6.5, _safe(value), new_x="LMARGIN", new_y="NEXT")


def _truncate(pdf: _DeliveryPDF, text: str, max_w: float) -> str:
    """Truncate text with '...' if it exceeds max_w (measured with current font)."""
    if pdf.get_string_width(text) <= max_w:
        return text
    ellipsis_w = pdf.get_string_width("...")
    result = ""
    for ch in text:
        if pdf.get_string_width(result + ch) + ellipsis_w <= max_w:
            result += ch
        else:
            break
    return result + "..."


def _split_text(pdf: _DeliveryPDF, text: str, max_w: float) -> list[str]:
    """Split text into lines that fit within max_w, measured with current font."""
    words = text.split(" ")
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = (current + " " + word).strip() if current else word
        if pdf.get_string_width(candidate) <= max_w:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines or [text]


def _two_col_info(
    pdf: _DeliveryPDF,
    left_title: str,
    left_rows: list[tuple[str, str]],
    right_title: str,
    right_rows: list[tuple[str, str]],
) -> None:
    W = pdf.w - 2 * MARGIN
    COL_W = W / 2 - 3
    LBL_W = 24.0
    right_x = MARGIN + COL_W + 6
    title_h = 7.0
    LINE_H = 6.0

    section_start_y = pdf.get_y()

    def _col_rows(col_x: float, rows: list[tuple[str, str]]) -> float:
        """Draw all rows for one column; returns y after the last row."""
        y = section_start_y + title_h
        val_w = COL_W - LBL_W
        for lbl, val in rows:
            safe_val = _safe(val)
            # Measure with bold font so line-splitting is accurate
            pdf.set_font(pdf._font_family, "B", 10)
            lines = _split_text(pdf, safe_val, val_w)
            row_h = LINE_H * len(lines)

            # Label — normal weight, top-aligned to this row
            pdf.set_xy(col_x, y)
            pdf.set_font(pdf._font_family, "", 10)
            pdf.set_text_color(100, 130, 160)
            pdf.cell(LBL_W, LINE_H, f"{lbl}:")

            # Value — bold, one cell per wrapped line (explicit xy prevents
            # multi_cell from resetting x to the page margin mid-column)
            pdf.set_font(pdf._font_family, "B", 10)
            pdf.set_text_color(30, 30, 30)
            for i, line in enumerate(lines):
                pdf.set_xy(col_x + LBL_W, y + i * LINE_H)
                pdf.cell(val_w, LINE_H, line)

            y += row_h
        return y

    # ── Left column ──────────────────────────────────────────────────────
    pdf.set_xy(MARGIN, section_start_y)
    pdf.set_font(pdf._font_family, "B", 11)
    pdf.set_text_color(26, 58, 92)
    pdf.cell(COL_W, title_h, left_title)
    left_end_y = _col_rows(MARGIN, left_rows)

    # ── Right column ─────────────────────────────────────────────────────
    pdf.set_xy(right_x, section_start_y)
    pdf.set_font(pdf._font_family, "B", 11)
    pdf.set_text_color(26, 58, 92)
    pdf.cell(COL_W, title_h, right_title)
    right_end_y = _col_rows(right_x, right_rows)

    pdf.set_y(max(left_end_y, right_end_y))
    pdf.ln(2)
    pdf.set_draw_color(200, 200, 200)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(3)


def _draw_logo_header(
    pdf: _DeliveryPDF,
    logo_path: str | None,
    title: str,
    subtitle: str,
    date_str: str,
    title_size: int = 16,
) -> None:
    """Logo + title block at top of a page. Aspect ratio of logo is preserved."""
    DESIRED_LOGO_W = 30.0
    top_y = 18.0

    logo_w, logo_h = DESIRED_LOGO_W, DESIRED_LOGO_W
    if logo_path and Path(logo_path).exists():
        logo_w, logo_h = _logo_dimensions(logo_path, DESIRED_LOGO_W)
        try:
            pdf.image(logo_path, x=MARGIN, y=top_y, w=logo_w, h=logo_h)
        except Exception:
            pass

    text_x = MARGIN + logo_w + 5
    text_w = pdf.w - text_x - MARGIN

    pdf.set_xy(text_x, top_y + 1)
    pdf.set_font(pdf._font_family, "B", title_size)
    pdf.set_text_color(26, 58, 92)
    pdf.cell(text_w, 8, title, align="R", new_x="LMARGIN", new_y="NEXT")

    pdf.set_x(text_x)
    pdf.set_font(pdf._font_family, "B", 10)
    pdf.set_text_color(37, 99, 235)
    pdf.cell(text_w, 5.5, subtitle, align="R", new_x="LMARGIN", new_y="NEXT")

    pdf.set_x(text_x)
    pdf.set_font(pdf._font_family, "", 9)
    pdf.set_text_color(100, 116, 139)
    pdf.cell(text_w, 5, f"Fecha de entrega: {date_str}", align="R", new_x="LMARGIN", new_y="NEXT")

    pdf.set_y(top_y + max(logo_h, 22.0) + 3)
    pdf.set_draw_color(26, 58, 92)
    pdf.set_line_width(0.5)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.set_line_width(0.2)
    pdf.ln(4)


def _draw_status_badge(pdf: _DeliveryPDF, x: float, y: float, w: float, h: float, has_damage: bool) -> None:
    if has_damage:
        pdf.set_fill_color(254, 243, 199)    # #fef3c7
        pdf.set_text_color(146, 64, 14)       # #92400e
        label = "En Atenci\xf3n"
    else:
        pdf.set_fill_color(220, 252, 231)     # #dcfce7
        pdf.set_text_color(22, 101, 52)       # #166534
        label = "Correcto"
    pdf.set_xy(x, y)
    pdf.set_font(pdf._font_family, "B", 8)
    pdf.cell(w, h, label, fill=True, align="C")
    pdf.set_text_color(30, 30, 30)


def _draw_checklist_badge(pdf: _DeliveryPDF, x: float, y: float, w: float, h: float, checked: bool) -> None:
    if checked:
        pdf.set_fill_color(220, 252, 231)    # #dcfce7
        pdf.set_text_color(22, 101, 52)      # #166534
        label = "S\xed"
    else:
        pdf.set_fill_color(243, 244, 246)    # #f3f4f6
        pdf.set_text_color(55, 65, 81)       # #374151
        label = "No"
    pdf.set_xy(x, y)
    pdf.set_font(pdf._font_family, "B", 8)
    pdf.cell(w, h, label, fill=True, align="C")
    pdf.set_text_color(30, 30, 30)


def _draw_signatures(
    pdf: _DeliveryPDF,
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
    _draw_one_sig_box(
        pdf, x=MARGIN, y=sig_y, w=COL_W,
        title="FIRMA DEL T\xc9CNICO",
        name=tech_name, role=None, sig_path=tech_sig_path,
    )
    _draw_one_sig_box(
        pdf, x=MARGIN + COL_W + 6, y=sig_y, w=COL_W,
        title="FIRMA DE CONFORMIDAD DEL CLIENTE",
        name=client_name, role=client_role, sig_path=client_sig_path,
    )


def _draw_one_sig_box(
    pdf: _DeliveryPDF,
    x: float,
    y: float,
    w: float,
    title: str,
    name: str,
    role: str | None,
    sig_path: str | None,
) -> None:
    LBL_W = 18.0
    row_h = 6.0
    pdf.set_xy(x, y)
    pdf.set_font(pdf._font_family, "B", 10)
    pdf.set_text_color(100, 130, 160)
    pdf.cell(w, row_h, title, new_x="LEFT", new_y="NEXT")
    pdf.set_x(x)
    pdf.set_draw_color(220, 220, 220)
    pdf.line(x, pdf.get_y(), x + w, pdf.get_y())
    pdf.ln(1)

    pdf.set_xy(x, pdf.get_y())
    pdf.set_font(pdf._font_family, "", 10)
    pdf.set_text_color(100, 130, 160)
    pdf.cell(LBL_W, row_h, "Nombre:")
    pdf.set_font(pdf._font_family, "B", 10)
    pdf.set_text_color(30, 30, 30)
    pdf.cell(w - LBL_W, row_h, _safe(name), new_x="LEFT", new_y="NEXT")
    pdf.set_x(x)

    if role is not None:
        pdf.set_font(pdf._font_family, "", 10)
        pdf.set_text_color(100, 130, 160)
        pdf.cell(LBL_W, row_h, "Cargo:")
        pdf.set_font(pdf._font_family, "B", 10)
        pdf.set_text_color(30, 30, 30)
        pdf.cell(w - LBL_W, row_h, _safe(role), new_x="LEFT", new_y="NEXT")
        pdf.set_x(x)
    else:
        pdf.ln(row_h)  # spacer to align signature box with client side

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
        pdf.set_font(pdf._font_family, "", 8)
        pdf.set_text_color(180, 180, 180)
        pdf.cell(w, 4, "Sin firma", align="C")
        pdf.set_text_color(30, 30, 30)

    pdf.set_y(box_y + box_h + 2)


def _draw_equipment_table(pdf: _DeliveryPDF, report_data: list[_ReportData]) -> None:
    _section_title(pdf, f"EQUIPOS ATENDIDOS ({len(report_data)})")

    # Column widths — total = 180 mm
    # #(10) | Modelo(32) | Serie(38) | Planta(30) | Área(20) | Tipo(28) | Estado(22)
    cols = [10.0, 32.0, 38.0, 30.0, 20.0, 28.0, 22.0]
    headers = ["#", "Modelo", "Serie", "Planta", "\xc1rea", "Tipo servicio", "Estado"]
    row_h = 6.5

    pdf.set_fill_color(245, 247, 250)
    pdf.set_draw_color(209, 213, 219)
    x = MARGIN
    header_y = pdf.get_y()
    for hdr, cw in zip(headers, cols):
        pdf.set_xy(x, header_y)
        pdf.set_font(pdf._font_family, "B", 10)
        pdf.set_text_color(26, 58, 92)
        pdf.cell(cw, row_h, hdr, border=1, fill=True, align="C")
        x += cw
    pdf.ln(row_h)

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
            # Serial (index 2) is bold; all others are normal
            style = "B" if i == 2 else ""
            pdf.set_font(pdf._font_family, style, 10)
            pdf.set_text_color(30, 30, 30)
            # Truncate if text is wider than the cell (leave 2 mm padding)
            display_val = _truncate(pdf, val, cw - 2)
            pdf.cell(cw, row_h, display_val, border=1, fill=True)
            x += cw

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


def _draw_checklist(pdf: _DeliveryPDF, checkboxes: dict) -> None:
    """Single-column checklist with badge aligned to the right — matching Flutter style."""
    W = pdf.w - 2 * MARGIN
    _section_title(pdf, "LISTA T\xc9CNICA DE VERIFICACI\xd3N")

    BADGE_W = 12.0
    ROW_H = 7.5
    ITEM_W = W - BADGE_W - 2.0
    BADGE_H = ROW_H - 2.0

    for item in _CHECKLIST_ITEMS:
        row_y = pdf.get_y()
        checked = checkboxes.get(item) is True
        pdf.set_xy(MARGIN, row_y)
        pdf.set_font(pdf._font_family, "", 10)
        pdf.set_text_color(30, 30, 30)
        pdf.cell(ITEM_W, ROW_H, item)
        _draw_checklist_badge(
            pdf,
            MARGIN + ITEM_W + 1,
            row_y + (ROW_H - BADGE_H) / 2,
            BADGE_W,
            BADGE_H,
            checked,
        )
        # Separator line at the bottom of each row
        pdf.set_draw_color(229, 231, 235)   # #e5e7eb
        pdf.line(MARGIN, row_y + ROW_H, pdf.w - MARGIN, row_y + ROW_H)
        pdf.ln(ROW_H)

    pdf.ln(2)
    pdf.set_draw_color(200, 200, 200)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(3)


def _draw_photos(pdf: _DeliveryPDF, photo_paths: list[str]) -> None:
    if not photo_paths:
        return
    W = pdf.w - 2 * MARGIN
    _section_title(pdf, "EVIDENCIA FOTOGR\xc1FICA")

    PHOTOS_PER_ROW = 2
    gap = 4.0
    img_w = min(85.0, (W - gap * (PHOTOS_PER_ROW - 1)) / PHOTOS_PER_ROW)

    for row_start in range(0, len(photo_paths), PHOTOS_PER_ROW):
        row = photo_paths[row_start: row_start + PHOTOS_PER_ROW]

        # Pre-compute corrected image sources and individual heights
        row_items: list[tuple[str | BytesIO, float]] = []
        for path in row:
            if not Path(path).exists():
                row_items.append((path, img_w * 0.75))
                continue
            corrected = _corrected_image_bytes(path)
            src: str | BytesIO = corrected if corrected is not None else path
            ratio = _image_aspect(src)
            h = img_w * ratio if ratio else img_w * 0.75
            row_items.append((src, h))

        max_row_h = max(h for _, h in row_items) if row_items else img_w * 0.75

        if pdf.get_y() + max_row_h + 5 > pdf.h - 20:
            pdf.add_page()
            pdf.ln(5)

        row_y = pdf.get_y()
        for j, (path, (src, ind_h)) in enumerate(zip(row, row_items)):
            if not Path(path).exists():
                continue
            try:
                x = MARGIN + j * (img_w + gap)
                if isinstance(src, BytesIO):
                    src.seek(0)
                pdf.image(src, x=x, y=row_y, w=img_w, h=ind_h)
                pdf.set_draw_color(200, 200, 200)
                pdf.rect(x, row_y, img_w, ind_h)
            except Exception:
                pass
        pdf.set_y(row_y + max_row_h + gap)

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

        # Resolve tech signature path — try User.signature_path first,
        # then fall back to EntityFile (signature_path is not always populated
        # when signatures sync via POST /api/files).
        tech_sig_path: str | None = None
        if tech and tech.signature_path:
            p = Path(tech.signature_path)
            if not p.is_absolute():
                p = Path(settings.upload_dir) / p
            if p.exists():
                tech_sig_path = str(p)

        if tech_sig_path is None and tech:
            ef_tech = (
                db.query(EntityFile)
                .filter(
                    EntityFile.entity_id == tech.id,
                    EntityFile.entity_type == "signature",
                )
                .join(EntityFile.file)
                .order_by(EntityFile.id.desc())
                .first()
            )
            if ef_tech and ef_tech.file and Path(ef_tech.file.storage_path).exists():
                tech_sig_path = ef_tech.file.storage_path

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
        pdf.setup_fonts()
        pdf.alias_nb_pages()
        pdf.set_auto_page_break(auto=True, margin=20)
        pdf.set_meta(logo_path, folio, date_str)
        pdf.set_margins(MARGIN, 15, MARGIN)

        # ── Page 1: Cover ────────────────────────────────────────────────────
        pdf.add_page()
        _draw_logo_header(
            pdf, logo_path,
            "ACTA DE ENTREGA DE P\xd3LIZA",
            f"P\xf3liza: {folio}",
            date_str,
            title_size=20,
        )

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
                ("Direcci\xf3n", client.address if client else "-"),
            ],
            right_title="DATOS DE LA P\xd3LIZA",
            right_rows=[
                ("Folio", folio),
                ("Cobertura", coverage),
                ("Vigencia", vigencia),
                ("T\xe9cnico", tech_name),
            ],
        )

        _draw_equipment_table(pdf, report_data)

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

            report_code = rd.report.code or f"R-{rd.report.id[:8].upper()}"
            _draw_logo_header(
                pdf,
                logo_path,
                f"RESUMEN DE SERVICIO - Equipo {i + 1}/{len(report_data)}",
                f"P\xf3liza: {folio}  |  {report_code}",
                date_str,
                title_size=14,
            )

            model_str = _safe(
                f"{rd.model.brand} {rd.model.model_name} {rd.model.dpi}dpi"
                if rd.model else None
            )
            printer_code = _safe(rd.printer.code if rd.printer else None)
            serial = _safe(rd.printer.serial_number if rd.printer else None)

            _two_col_info(
                pdf,
                left_title="INFORMACI\xd3N DEL CLIENTE",
                left_rows=[
                    ("Nombre", client.name if client else "-"),
                    ("RFC", client.rfc if client else "-"),
                    ("Direcci\xf3n", client.address if client else "-"),
                    ("Planta", rd.plant.name if rd.plant else "-"),
                    ("\xc1rea", rd.area.name if rd.area else "-"),
                ],
                right_title="DATOS DE LA IMPRESORA",
                right_rows=[
                    ("C\xf3digo", printer_code),
                    ("Serie", f"S/N: {serial}"),
                    ("Modelo", model_str),
                    ("Contador", f"{rd.report.linear_inches_counter} pulg." if rd.report.linear_inches_counter is not None else "-"),
                    ("Temperatura", str(rd.report.darkness_level) if rd.report.darkness_level is not None else "-"),
                ],
            )

            _draw_checklist(pdf, rd.checkboxes)

            if rd.report.notes:
                _section_title(pdf, "NOTAS DEL SERVICIO")
                pdf.set_font(pdf._font_family, "", 10)
                pdf.set_text_color(30, 30, 30)
                pdf.multi_cell(pdf.w - 2 * MARGIN, 5.5, _safe(rd.report.notes))
                pdf.ln(2)
                pdf.set_draw_color(200, 200, 200)
                pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
                pdf.ln(3)

            _draw_photos(pdf, rd.photo_paths)

            # Tech signature on report pages
            _section_title(pdf, "FIRMA DEL T\xc9CNICO")
            pdf.set_font(pdf._font_family, "", 10)
            pdf.set_text_color(100, 130, 160)
            pdf.cell(22, 6.0, "Nombre:")
            pdf.set_font(pdf._font_family, "B", 10)
            pdf.set_text_color(30, 30, 30)
            pdf.cell(0, 6.0, _safe(tech_name), new_x="LMARGIN", new_y="NEXT")
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
            else:
                pdf.set_xy(MARGIN, sig_box_y + sig_box_h / 2 - 2)
                pdf.set_font(pdf._font_family, "", 8)
                pdf.set_text_color(180, 180, 180)
                pdf.cell(sig_box_w, 4, "Sin firma", align="C")
                pdf.set_text_color(30, 30, 30)
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
