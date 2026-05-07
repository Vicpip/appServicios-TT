"""Server-side PDF generation for service reports using fpdf2."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from fpdf import FPDF

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


def _fmt_date(dt: Any) -> str:
    if dt is None:
        return "—"
    return f"{dt.day:02d} {_MONTHS[dt.month - 1]} {dt.year}"


class _ReportPDF(FPDF):
    def footer(self) -> None:
        self.set_y(-12)
        self.set_font("Helvetica", "I", 7)
        self.set_text_color(160, 160, 160)
        self.cell(0, 5, f"Pág. {self.page_no()}", align="C")


def generate_report_pdf(
    *,
    report: Any,
    printer: Any,
    client: Any,
    plant: Any,
    area: Any,
    tech: Any,
    catalog_model: Any,
    upload_dir: str,
) -> bytes:
    """Generate a PDF for a service report and return the raw bytes."""
    pdf = _ReportPDF(orientation="P", unit="mm", format="A4")
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()

    MARGIN = 15.0
    W = pdf.w - 2 * MARGIN  # ~180 mm usable width

    # ── Header ────────────────────────────────────────────────────────────────
    pdf.set_font("Helvetica", "B", 16)
    pdf.set_text_color(30, 80, 160)
    pdf.cell(
        W, 9,
        "REPORTE DE SERVICIO TÉCNICO",
        align="C",
        new_x="LMARGIN",
        new_y="NEXT",
    )

    code_str = report.code or f"R-{report.id[:8].upper()}"
    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(
        W, 6,
        f"{code_str}   |   {report.service_type}   |   {_fmt_date(report.service_date)}",
        align="C",
        new_x="LMARGIN",
        new_y="NEXT",
    )
    pdf.ln(1)
    pdf.set_draw_color(200, 200, 200)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(4)

    # ── Two-column: Client | Printer ──────────────────────────────────────────
    COL_W = W / 2 - 2.0
    LBL_W = 26.0

    # Column headers
    pdf.set_font("Helvetica", "B", 8)
    pdf.set_text_color(100, 130, 160)
    pdf.cell(COL_W, 5, "INFORMACIÓN DEL CLIENTE", new_x="RIGHT", new_y="TOP")
    pdf.set_x(MARGIN + COL_W + 4)
    pdf.cell(COL_W, 5, "DATOS DE LA IMPRESORA", new_x="LMARGIN", new_y="NEXT")
    pdf.set_draw_color(220, 220, 220)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(1)

    model_str: str | None = None
    if catalog_model:
        model_str = (
            f"{catalog_model.brand} {catalog_model.model_name} {catalog_model.dpi}dpi"
        )

    client_rows: list[tuple[str, str | None]] = [
        ("Cliente", client.name if client else None),
        ("RFC", client.rfc if client else None),
        ("Dirección", client.address if client else None),
        ("Planta", plant.name if plant else None),
        ("Área", area.name if area else None),
    ]
    printer_rows: list[tuple[str, str | None]] = [
        ("Serie", printer.serial_number if printer else None),
        ("Código", printer.code if printer else None),
        ("Modelo", model_str),
        ("Técnico", tech.name if tech else None),
        (
            "Contador",
            f"{report.linear_inches_counter} pulg."
            if report.linear_inches_counter is not None
            else None,
        ),
        (
            "Oscuridad",
            str(report.darkness_level)
            if report.darkness_level is not None
            else None,
        ),
    ]

    for i in range(max(len(client_rows), len(printer_rows))):
        row_y = pdf.get_y()

        if i < len(client_rows):
            lbl, val = client_rows[i]
            pdf.set_xy(MARGIN, row_y)
            pdf.set_font("Helvetica", "B", 8)
            pdf.set_text_color(100, 130, 160)
            pdf.cell(LBL_W, 5, f"{lbl}:")
            pdf.set_font("Helvetica", "", 8)
            pdf.set_text_color(30, 30, 30)
            pdf.cell(COL_W - LBL_W, 5, val or "—")

        if i < len(printer_rows):
            lbl, val = printer_rows[i]
            pdf.set_xy(MARGIN + COL_W + 4, row_y)
            pdf.set_font("Helvetica", "B", 8)
            pdf.set_text_color(100, 130, 160)
            pdf.cell(LBL_W, 5, f"{lbl}:")
            pdf.set_font("Helvetica", "", 8)
            pdf.set_text_color(30, 30, 30)
            pdf.cell(COL_W - LBL_W, 5, val or "—")

        pdf.ln(5)

    pdf.ln(2)
    pdf.set_draw_color(200, 200, 200)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(3)

    # ── Technical Checklist ───────────────────────────────────────────────────
    pdf.set_font("Helvetica", "B", 8)
    pdf.set_text_color(100, 130, 160)
    pdf.cell(W, 5, "LISTA TÉCNICA", new_x="LMARGIN", new_y="NEXT")
    pdf.set_draw_color(220, 220, 220)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(1)

    try:
        checkboxes: dict = (
            json.loads(report.technical_checkboxes)
            if isinstance(report.technical_checkboxes, str)
            else (report.technical_checkboxes or {})
        )
    except (json.JSONDecodeError, TypeError):
        checkboxes = {}

    ITEM_COL_W = W / 2
    for i in range(0, len(_CHECKLIST_ITEMS), 2):
        row_y = pdf.get_y()
        for j in range(2):
            idx = i + j
            if idx >= len(_CHECKLIST_ITEMS):
                break
            item = _CHECKLIST_ITEMS[idx]
            checked = checkboxes.get(item) is True
            pdf.set_xy(MARGIN + j * ITEM_COL_W, row_y)
            pdf.set_font("Helvetica", "B" if checked else "", 8)
            pdf.set_text_color(30, 150, 80) if checked else pdf.set_text_color(60, 60, 60)
            mark = "[X] " if checked else "[ ] "
            pdf.cell(ITEM_COL_W, 5, mark + item)
        pdf.ln(5)

    pdf.ln(2)
    pdf.set_draw_color(200, 200, 200)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(3)

    # ── Notes ─────────────────────────────────────────────────────────────────
    if report.notes:
        pdf.set_font("Helvetica", "B", 8)
        pdf.set_text_color(100, 130, 160)
        pdf.cell(W, 5, "NOTAS DEL SERVICIO", new_x="LMARGIN", new_y="NEXT")
        pdf.set_draw_color(220, 220, 220)
        pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
        pdf.ln(1)
        pdf.set_font("Helvetica", "", 9)
        pdf.set_text_color(30, 30, 30)
        pdf.multi_cell(W, 5, report.notes)
        pdf.ln(2)
        pdf.set_draw_color(200, 200, 200)
        pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
        pdf.ln(3)

    # ── Signature ─────────────────────────────────────────────────────────────
    pdf.set_font("Helvetica", "B", 8)
    pdf.set_text_color(100, 130, 160)
    pdf.cell(W, 5, "FIRMA DE CONFORMIDAD", new_x="LMARGIN", new_y="NEXT")
    pdf.set_draw_color(220, 220, 220)
    pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
    pdf.ln(1)

    for lbl, val in [("Nombre", report.signature_name), ("Cargo", report.signature_role)]:
        pdf.set_font("Helvetica", "B", 8)
        pdf.set_text_color(100, 130, 160)
        pdf.cell(25, 5, f"{lbl}:")
        pdf.set_font("Helvetica", "", 8)
        pdf.set_text_color(30, 30, 30)
        pdf.cell(W - 25, 5, val or "—", new_x="LMARGIN", new_y="NEXT")

    # Signature image
    if report.signature_image_path:
        sig_path = Path(report.signature_image_path)
        if not sig_path.is_absolute():
            sig_path = Path(upload_dir) / sig_path
        if sig_path.exists():
            try:
                pdf.ln(2)
                pdf.image(str(sig_path), x=MARGIN, w=60, h=30)
            except Exception:
                pass

    return bytes(pdf.output())
