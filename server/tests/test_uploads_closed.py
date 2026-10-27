"""Etapa 2b de H-19: /uploads ya no se sirve; los logos salen por client-logo."""
import uuid
from pathlib import Path

from app.config import get_settings
from tests.helpers import png_bytes


def _root() -> Path:
    return Path(get_settings().upload_dir)


def test_uploads_ya_no_se_sirve(client):
    rel = f"report/{uuid.uuid4()}/photo/photo_x.png"
    path = _root() / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png_bytes())
    for url in (f"/uploads/{rel}", "/uploads/", "/uploads/logos/x.png", f"/uploads/uploads/{rel}"):
        assert client.get(url).status_code == 404, url


def test_static_sigue_disponible(client):
    assert client.get("/static/logo_smp.png").status_code == 200


def test_client_logo_sirve_el_archivo_directo_sin_redirigir(client, db, world):
    (_root() / "logos").mkdir(parents=True, exist_ok=True)
    data = png_bytes()
    (_root() / "logos" / f"{world.client_row.id}.png").write_bytes(data)
    world.client_row.logo_path = f"logos/{world.client_row.id}.png"
    db.commit()

    res = client.get(f"/api/portal/client-logo?client_id={world.client_row.id}", follow_redirects=False)
    assert res.status_code == 200
    assert res.content == data
    assert res.headers["content-type"] == "image/png"
    assert res.headers["x-content-type-options"] == "nosniff"


def test_client_logo_sin_logo_o_cliente_inexistente_404(client, world):
    assert client.get(f"/api/portal/client-logo?client_id={world.client_row.id}").status_code == 404
    assert client.get(f"/api/portal/client-logo?client_id={uuid.uuid4()}").status_code == 404


def test_client_logo_no_sirve_rutas_fuera_de_logos(client, db, world):
    """Aunque logo_path apunte a otro archivo de uploads o intente salir, responde 404."""
    other = _root() / "report" / "algo" / "photo" / "p.png"
    other.parent.mkdir(parents=True, exist_ok=True)
    other.write_bytes(png_bytes())
    for bad in ("report/algo/photo/p.png", "../fuera.png", "logos/../report/algo/photo/p.png", "/etc/passwd"):
        world.client_row.logo_path = bad
        db.commit()
        res = client.get(f"/api/portal/client-logo?client_id={world.client_row.id}")
        assert res.status_code == 404, bad
