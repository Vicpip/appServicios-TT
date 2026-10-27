"""Extremo a extremo: póliza de 3 equipos y dos visitas.

reporte de 2 equipos -> entrega parcial -> la visita sigue en curso ->
reporte del tercero -> entrega -> visita completada -> un correo por entrega
con ligas -> se activa la visita 2.
"""
import re

from app.models.policy import PolicyDelivery, PolicyVisit
from tests.conftest import Outbox
from tests.helpers import sync_delivery

LINK_RE = re.compile(r"/api/public/files/([A-Za-z0-9_-]+)")


def _visit(db, vid):
    db.expire_all()
    return db.get(PolicyVisit, vid)


def test_flujo_completo_de_poliza(client, world, db, tech_headers, admin_headers, outbox):
    world.add_contact("cliente@vibra.com")
    world.add_contact("compras@vibra.com")
    visits_url = f"/api/admin/policies/{world.policy.id}/visits"

    # 1) Reporte de 2 equipos -> entrega parcial
    d1, _ = sync_delivery(client, tech_headers, world, world.printers[:2], extra_email="firma1@vibra.com")
    assert _visit(db, world.visit1.id).status == "in_progress"      # sigue en curso
    assert len(outbox.sent) == 1                                     # un correo por la entrega 1
    # Visita 2 no se puede activar mientras la 1 sigue en curso
    assert client.patch(f"{visits_url}/{world.visit2.id}", json={"status": "in_progress"}, headers=admin_headers).status_code == 409

    # 2) Reporte del tercero -> entrega que completa la póliza
    d2, _ = sync_delivery(client, tech_headers, world, world.printers[2:], extra_email=None)
    assert _visit(db, world.visit1.id).status == "completed"         # visita completada
    assert len(outbox.sent) == 2                                     # un correo por cada entrega

    # 3) Contenido de cada correo
    mail1, mail2 = outbox.sent
    assert mail1["recipients"] == ["cliente@vibra.com", "compras@vibra.com", "firma1@vibra.com"]
    assert mail2["recipients"] == ["cliente@vibra.com", "compras@vibra.com"]
    for mail, n_equipos in ((mail1, 2), (mail2, 1)):
        html = Outbox.html(mail)
        assert not Outbox.has_attachment(mail)
        assert f">{n_equipos}</td>" in html            # número de equipos entregados
        tokens = set(LINK_RE.findall(html))
        assert len(tokens) == n_equipos + 1             # una por equipo + resumen
        for t in tokens:
            assert client.get(f"/api/public/files/{t}").status_code == 200
    # Ninguna liga se comparte entre correos
    t1 = set(LINK_RE.findall(Outbox.html(mail1)))
    t2 = set(LINK_RE.findall(Outbox.html(mail2)))
    assert t1.isdisjoint(t2)

    # 4) Ambas entregas quedaron marcadas como enviadas
    db.expire_all()
    for did in (d1, d2):
        assert db.get(PolicyDelivery, did).email_sent_at is not None

    # 5) Ya completada la visita 1, se puede activar la 2
    res = client.patch(f"{visits_url}/{world.visit2.id}", json={"status": "in_progress"}, headers=admin_headers)
    assert res.status_code == 200 and res.json()["status"] == "in_progress"
