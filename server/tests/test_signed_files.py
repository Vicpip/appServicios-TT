"""URLs firmadas a /uploads (H-19): firma, vigencia, rutas inseguras, alcance del portal
y saneamiento de nombres en POST /api/files."""
import time
import uuid
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import pytest

from app.api.routers.portal import _portal_token
from app.config import get_settings
from app.models.client import Client
from app.models.file import EntityFile, File
from app.models.portal import PortalUser
from app.services import file_signing_service as signing
from tests.conftest import PDF_BYTES, _PASSWORD_HASH, store_pdf
from tests.helpers import png_bytes, upload


def _upload_root() -> Path:
    return Path(get_settings().upload_dir)


@pytest.fixture()
def stored(db):
    """Archivo real en uploads: (ruta relativa a UPLOAD_DIR, bytes)."""
    rel = f"report/{uuid.uuid4()}/photo/photo_{uuid.uuid4()}.png"
    path = _upload_root() / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    data = png_bytes()
    path.write_bytes(data)
    return rel, data


def _signed(rel: str, ttl: int = 600) -> str:
    exp = int(time.time()) + ttl
    return f"/api/files/signed?p={rel}&e={exp}&s={signing.compute_signature(rel, exp)}"


def test_firma_valida_sirve_archivo_con_headers(client, stored):
    rel, data = stored
    res = client.get(_signed(rel))
    assert res.status_code == 200
    assert res.content == data
    assert res.headers["content-type"] == "image/png"
    assert res.headers["x-content-type-options"] == "nosniff"
    assert "private" in res.headers["cache-control"] and "no-store" in res.headers["cache-control"]
    assert res.headers["content-disposition"].startswith("inline")


def test_no_requiere_authorization(client, stored):
    assert client.get(_signed(stored[0])).status_code == 200


def test_pdf_content_type(client, db):
    path = store_pdf(db, "report", str(uuid.uuid4()))
    rel = path.relative_to(_upload_root()).as_posix()
    res = client.get(_signed(rel))
    assert res.status_code == 200 and res.headers["content-type"] == "application/pdf"


def test_expirada_403(client, stored):
    assert client.get(_signed(stored[0], ttl=-5)).status_code == 403


def test_firma_alterada_403(client, stored):
    rel, _ = stored
    url = _signed(rel)
    bad_sig = url[:-1] + ("0" if url[-1] != "0" else "1")
    assert client.get(bad_sig).status_code == 403
    # firma de otro archivo / otra expiración
    other = f"report/{uuid.uuid4()}/photo/otra.png"
    exp = int(time.time()) + 600
    assert client.get(
        f"/api/files/signed?p={rel}&e={exp}&s={signing.compute_signature(other, exp)}"
    ).status_code == 403
    sig = signing.compute_signature(rel, exp)
    assert client.get(f"/api/files/signed?p={rel}&e={exp + 100000}&s={sig}").status_code == 403


def test_sin_parametros_o_firma_vacia(client, stored):
    rel, _ = stored
    assert client.get(f"/api/files/signed?p={rel}").status_code == 422
    assert client.get(f"/api/files/signed?p={rel}&e={int(time.time()) + 60}&s=").status_code == 403


def test_403_no_revela_la_causa(client, stored):
    rel, _ = stored
    expired = client.get(_signed(rel, ttl=-5))
    tampered = client.get(_signed(rel)[:-1] + "x")
    assert expired.status_code == tampered.status_code == 403
    assert expired.json() == tampered.json()


def test_inexistente_con_firma_valida_404(client):
    assert client.get(_signed(f"report/{uuid.uuid4()}/nada.pdf")).status_code == 404


def test_rutas_inseguras_rechazadas_aun_con_firma_valida(client):
    """Aunque alguien lograra firmar la ruta, no se sirve nada fuera de UPLOAD_DIR."""
    secret = _upload_root().parent / f"secreto_{uuid.uuid4().hex}.txt"
    secret.write_text("fuera de uploads")
    try:
        candidates = [
            f"../{secret.name}",
            f"report/../../{secret.name}",
            str(secret),
            "/etc/passwd",
            "C:/Windows/win.ini",
            "report\\..\\..\\x.png",
            "report/x\x00.png",
            "",
        ]
        for rel in candidates:
            exp = int(time.time()) + 600
            res = client.get(
                "/api/files/signed",
                params={"p": rel, "e": exp, "s": signing.compute_signature(rel, exp)},
            )
            assert res.status_code in (403, 404, 422), (rel, res.status_code)
            assert b"fuera de uploads" not in res.content
    finally:
        secret.unlink()


def test_symlink_fuera_de_uploads_no_se_sirve(client):
    outside = _upload_root().parent / f"fuera_{uuid.uuid4().hex}.png"
    outside.write_bytes(png_bytes())
    link = _upload_root() / "enlace.png"
    try:
        try:
            link.symlink_to(outside)
        except (OSError, NotImplementedError):
            pytest.skip("symlinks no disponibles en este sistema")
        assert client.get(_signed("enlace.png")).status_code == 404
    finally:
        link.unlink(missing_ok=True)
        outside.unlink(missing_ok=True)


@pytest.mark.parametrize("raw, esperado", [
    ("uploads/report/a/photo/x.jpg", "report/a/photo/x.jpg"),
    ("/uploads/report/a/photo/x.jpg", "report/a/photo/x.jpg"),
    ("logos/abc.png", "logos/abc.png"),
    ("uploads/delivery_pdf/d1/POL-2026-002-VC1.pdf", "delivery_pdf/d1/POL-2026-002-VC1.pdf"),
    ("/data/user/0/com.example.industrial_service_reports/app_flutter/signatures/x.png", None),
    ("uploads/../../etc/passwd", None),
    ("/etc/passwd", None),
    ("", None),
    (None, None),
])
def test_normalizacion_de_rutas_guardadas(raw, esperado):
    assert signing.to_relative_upload_path(raw) == esperado


def test_ruta_absoluta_dentro_de_uploads_se_relativiza(stored):
    rel, _ = stored
    assert signing.to_relative_upload_path(str(_upload_root() / rel)) == rel


def test_signed_upload_url_formato_relativo_para_fileurl():
    url = signing.signed_upload_url("uploads/report/a/photo/x.jpg")
    assert url.startswith("/api/files/signed?")
    q = parse_qs(urlparse(url).query)
    assert q["p"] == ["report/a/photo/x.jpg"]
    assert int(q["e"][0]) > time.time()
    assert signing.signed_upload_url("/data/user/0/app/x.png") is None


def test_ttl_por_defecto_una_hora():
    assert get_settings().file_url_ttl_seconds == 3600


# -- emisores: admin / portal / técnico ------------------------------------


def _register(db, entity_id, rel, category, entity_type="report"):
    f = File(id=str(uuid.uuid4()), file_hash=uuid.uuid4().hex, file_type="image/png",
             storage_path=f"uploads/{rel}", origin="mobile_sync")  # formato real de producción
    db.add(f)
    db.flush()
    db.add(EntityFile(id=str(uuid.uuid4()), file_id=f.id, entity_id=entity_id,
                      entity_type=entity_type, file_category=category))
    db.commit()


def _write_png(rel: str) -> None:
    p = _upload_root() / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(png_bytes())


def test_admin_report_files_devuelve_urls_firmadas_que_descargan(client, db, world, admin_headers):
    report = world.add_report(world.printers[0], status="signed")
    rel = f"report/{report.id}/photo/photo_1.png"
    _write_png(rel)
    _register(db, report.id, rel, "photo")

    res = client.get(f"/api/admin/reports/{report.id}/files", headers=admin_headers)
    assert res.status_code == 200
    (url,) = res.json()["photos"]
    assert url.startswith("/api/files/signed?")
    assert "/uploads/" not in url
    assert client.get(url).status_code == 200  # sin Authorization


def test_admin_files_requiere_admin(client, world, tech_headers):
    report = world.add_report(world.printers[0])
    assert client.get(f"/api/admin/reports/{report.id}/files").status_code == 401
    assert client.get(f"/api/admin/reports/{report.id}/files", headers=tech_headers).status_code == 403


def _portal_headers(db, client_id, email):
    u = PortalUser(id=str(uuid.uuid4()), client_id=client_id, email=email,
                   password_hash=_PASSWORD_HASH, name="Portal", is_active=True)
    db.add(u)
    db.commit()
    return {"Authorization": f"Bearer {_portal_token(u, db)}"}


def test_portal_alcance_por_cliente(client, db, world):
    report = world.add_report(world.printers[0], status="signed")
    rel = f"report/{report.id}/photo/photo_2.png"
    _write_png(rel)
    _register(db, report.id, rel, "photo")

    own = _portal_headers(db, world.client_row.id, "mio@cliente.test")
    res = client.get(f"/api/portal/reports/{report.id}/files", headers=own)
    assert res.status_code == 200
    (url,) = res.json()["photos"]
    assert url.startswith("/api/files/signed?") and client.get(url).status_code == 200

    other_client = Client(id=str(uuid.uuid4()), name="Otro Cliente", is_active=True)
    db.add(other_client)
    db.commit()
    other = _portal_headers(db, other_client.id, "otro@cliente.test")
    assert client.get(f"/api/portal/reports/{report.id}/files", headers=other).status_code == 403
    assert client.get(f"/api/portal/reports/{report.id}/files").status_code in (401, 403)


def test_entregas_traen_pdf_url_firmado_y_conservan_pdf_path(client, db, world, admin_headers):
    from app.models.policy import PolicyDelivery

    rel = "deliveries/POL-2026-001_Cliente_20261027_V1-2.pdf"
    p = _upload_root() / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(PDF_BYTES)
    d = PolicyDelivery(id=str(uuid.uuid4()), policy_id=world.policy.id, tech_id=world.tech.id,
                       delivery_date=world.policy.start_date, signature_name="Fulano",
                       signature_role="Gerente", pdf_path=f"uploads/{rel}")
    db.add(d)
    db.commit()

    res = client.get(f"/api/admin/policies/{world.policy.id}/deliveries", headers=admin_headers)
    assert res.status_code == 200
    item = res.json()["items"][0]
    assert item["pdf_path"] == f"uploads/{rel}"  # intacto por compatibilidad
    assert item["pdf_url"].startswith("/api/files/signed?")
    got = client.get(item["pdf_url"])
    assert got.status_code == 200 and got.headers["content-type"] == "application/pdf"


# -- POST /api/files: nombres maliciosos ------------------------------------


@pytest.mark.parametrize("nombre", [
    "../../evil.png", "..\\..\\evil.png", "/etc/evil.png", "a/b/../../../evil.png",
    "....//evil.png", "x" * 400 + ".png",
])
def test_filename_malicioso_no_escribe_fuera_de_uploads(client, tech_headers, nombre):
    root = _upload_root().resolve()
    outside = lambda: {  # noqa: E731
        p for p in root.parent.glob("*") if p.is_file()
    }
    before = outside()
    rid = str(uuid.uuid4())
    res = upload(client, tech_headers, "report", rid, "photo", png_bytes(), nombre)
    assert res.status_code == 200, res.text
    stored_path = Path(res.json()["message"]).resolve()
    assert stored_path.is_relative_to(root)
    assert stored_path.parent == root / "report" / rid / "photo"
    assert len(stored_path.name) <= 120
    assert outside() == before  # nada nuevo junto a uploads
    assert not (root.parent.parent / "evil.png").exists()


@pytest.mark.parametrize("campo, valor", [
    ("entity_id", "../../../fuera"), ("entity_id", "a/b"), ("entity_type", ".."),
    ("file_category", "../x"), ("entity_id", ""),
])
def test_segmentos_maliciosos_rechazados(client, tech_headers, campo, valor):
    data = {"entity_type": "report", "entity_id": str(uuid.uuid4()), "file_category": "photo"}
    data[campo] = valor
    res = client.post("/api/files", data=data,
                      files={"file": ("ok.png", png_bytes() + valor.encode(), "image/png")},
                      headers=tech_headers)
    assert res.status_code in (400, 422), (campo, valor, res.status_code)


def test_filename_normal_se_conserva(client, tech_headers):
    rid = str(uuid.uuid4())
    for name in ("R-VC1-010.pdf", f"report_{rid}.pdf", "POL-2026-002-VC1.pdf", "photo_x.jpg"):
        res = upload(client, tech_headers, "report", rid, "pdf", name=name)
        assert Path(res.json()["message"]).name == name


# -- configuración: el secreto es obligatorio en producción -----------------


@pytest.mark.parametrize("secret", ["", "cambiar-este-secreto", "change-me", "corto-" * 2])
def test_arranque_falla_en_produccion_sin_secreto_valido(secret):
    from pydantic import ValidationError

    from app.config import Settings

    with pytest.raises(ValidationError):
        Settings(_env_file=None, app_env="production", file_signing_secret=secret)


def test_secreto_valido_y_desarrollo_arrancan():
    from app.config import Settings

    Settings(_env_file=None, app_env="production", file_signing_secret="a1" * 20)
    Settings(_env_file=None, app_env="development", file_signing_secret="")
