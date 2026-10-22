"""Ligas públicas: generación y consumo (válida, vencida, revocada, inexistente, headers)."""
from datetime import timedelta

import pytest

from app.config import get_settings
from app.models.share_link import TARGET_DELIVERY_PDF, TARGET_REPORT_PDF, FileShareLink
from app.services import share_link_service as links
from tests.conftest import now, store_pdf


@pytest.fixture()
def report_link(db, world):
    report = world.add_report(world.printers[0], status="signed")
    path = store_pdf(db, "report", report.id)
    link = links.create_link(db, TARGET_REPORT_PDF, report.id)
    db.commit()
    return report, path, link


def test_token_largo_aleatorio_y_distinto_del_id(db, report_link):
    report, _, link = report_link
    other = links.create_link(db, TARGET_REPORT_PDF, report.id)
    assert len(link.token) >= 43  # token_urlsafe(32) = 256 bits
    assert link.token != other.token
    assert report.id not in link.token


def test_vigencia_por_defecto_30_dias(report_link):
    _, _, link = report_link
    assert get_settings().public_link_expire_days == 30
    assert timedelta(days=29, hours=23) < link.expires_at - link.created_at <= timedelta(days=30, minutes=1)


def test_liga_valida_sirve_pdf_con_headers(client, db, report_link):
    _, path, link = report_link
    res = client.get(f"/api/public/files/{link.token}")
    assert res.status_code == 200
    assert res.content.startswith(b"%PDF")
    assert res.headers["content-type"] == "application/pdf"
    assert res.headers["content-disposition"].startswith("inline")
    assert "noindex" in res.headers["x-robots-tag"]
    assert "private" in res.headers["cache-control"]
    # Registro de acceso
    db.expire_all()
    row = db.get(FileShareLink, link.id)
    assert row.access_count == 1 and row.last_access_at is not None
    client.get(f"/api/public/files/{link.token}")
    db.expire_all()
    assert db.get(FileShareLink, link.id).access_count == 2


def test_no_requiere_login(client, report_link):
    _, _, link = report_link
    assert client.get(f"/api/public/files/{link.token}").status_code == 200  # sin Authorization


def test_404_identico_para_inexistente_vencida_y_revocada(client, db, world, report_link):
    report, _, link = report_link
    expired = links.create_link(db, TARGET_REPORT_PDF, report.id)
    expired.expires_at = now() - timedelta(seconds=1)
    revoked = links.create_link(db, TARGET_REPORT_PDF, report.id)
    revoked.revoked_at = now()
    db.commit()

    responses = [
        client.get("/api/public/files/token-que-no-existe"),
        client.get(f"/api/public/files/{expired.token}"),
        client.get(f"/api/public/files/{revoked.token}"),
    ]
    assert [r.status_code for r in responses] == [404, 404, 404]
    assert len({r.text for r in responses}) == 1  # no distingue la causa
    for r in responses:
        assert r.headers.get("content-type", "").startswith("application/json")


def test_404_si_el_archivo_ya_no_existe(client, report_link):
    _, path, link = report_link
    path.unlink()
    assert client.get(f"/api/public/files/{link.token}").status_code == 404


def test_regenerar_revoca_la_anterior(client, db, report_link):
    report, _, link = report_link
    new = links.regenerate_link(db, TARGET_REPORT_PDF, report.id)
    db.commit()
    assert client.get(f"/api/public/files/{link.token}").status_code == 404
    assert client.get(f"/api/public/files/{new.token}").status_code == 200


def test_get_or_create_reutiliza_la_vigente(db, report_link):
    report, _, link = report_link
    assert links.get_or_create_active_link(db, TARGET_REPORT_PDF, report.id).id == link.id
    link.revoked_at = now()
    db.commit()
    assert links.get_or_create_active_link(db, TARGET_REPORT_PDF, report.id).id != link.id


def test_liga_de_entrega_sigue_al_pdf_vigente(client, db, world):
    delivery_dir = links.resolve_upload_path("deliveries")
    delivery_dir.mkdir(parents=True, exist_ok=True)
    pdf = delivery_dir / "resumen.pdf"
    pdf.write_bytes(b"%PDF-1.4 v1")
    from app.models.policy import PolicyDelivery

    d = PolicyDelivery(
        id="d-1", policy_id=world.policy.id, delivery_date=now(), signature_name="X",
        signature_role="Y", tech_id=world.tech.id, pdf_path="deliveries/resumen.pdf",
    )
    db.add(d)
    db.commit()
    link = links.create_link(db, TARGET_DELIVERY_PDF, d.id)
    db.commit()
    assert client.get(f"/api/public/files/{link.token}").content == b"%PDF-1.4 v1"
    pdf.write_bytes(b"%PDF-1.4 v2")  # PDF regenerado: la misma liga entrega el nuevo
    assert client.get(f"/api/public/files/{link.token}").content == b"%PDF-1.4 v2"


def test_limite_por_ip(client, report_link, monkeypatch):
    _, _, link = report_link
    monkeypatch.setattr(get_settings(), "public_link_rate_limit", 3)
    codes = [client.get(f"/api/public/files/{link.token}").status_code for _ in range(5)]
    assert codes == [200, 200, 200, 429, 429]
    assert "retry-after" in client.get(f"/api/public/files/{link.token}").headers
