"""Correo único por entrega de póliza (ligas, idempotencia, diferido, destinatarios)."""
import re

import pytest

from app.models.policy import PolicyDelivery
from tests.conftest import Outbox
from tests.helpers import (
    post_delivery,
    post_report,
    sync_delivery,
    upload_report_pdf,
    upload_signature,
)

LINK_RE = re.compile(r"/api/public/files/([A-Za-z0-9_-]+)")


def _delivery(db, delivery_id) -> PolicyDelivery:
    db.expire_all()
    return db.get(PolicyDelivery, delivery_id)


def test_un_solo_correo_cuando_llega_el_ultimo_pdf(client, world, db, tech_headers, outbox):
    world.add_contact("cliente@vibra.com")
    reports = [post_report(client, tech_headers, world, p) for p in world.printers[:2]]
    delivery_id = post_delivery(client, tech_headers, world, reports)
    assert outbox.sent == []  # al crear la entrega aún no hay firma ni PDFs

    upload_signature(client, tech_headers, delivery_id)
    assert outbox.sent == []  # falta el PDF de ambos reportes
    upload_report_pdf(client, tech_headers, reports[0])
    assert outbox.sent == []  # falta el PDF del segundo (se difiere)
    assert _delivery(db, delivery_id).email_sent_at is None

    upload_report_pdf(client, tech_headers, reports[1])  # llega el último
    assert len(outbox.sent) == 1
    assert _delivery(db, delivery_id).email_sent_at is not None


def test_idempotente_no_reenvia(client, world, db, tech_headers, outbox):
    world.add_contact("cliente@vibra.com")
    delivery_id, reports = sync_delivery(client, tech_headers, world, world.printers[:2])
    assert len(outbox.sent) == 1
    # Un reintento de la app (mismo archivo otra vez) o de la firma no duplica.
    upload_report_pdf(client, tech_headers, reports[0])
    upload_signature(client, tech_headers, delivery_id)
    upload_report_pdf(client, tech_headers, reports[1])
    assert len(outbox.sent) == 1


def test_orden_invertido_archivos_antes_que_la_entrega(client, world, db, tech_headers, outbox):
    world.add_contact("cliente@vibra.com")
    reports = [post_report(client, tech_headers, world, p) for p in world.printers[:2]]
    # La app reintenta: la entrega llega al final.
    from tests.helpers import upload

    for rid in reports:
        upload_report_pdf(client, tech_headers, rid)
    delivery_id = "dddddddd-0000-0000-0000-000000000001"
    upload_signature(client, tech_headers, delivery_id)  # firma antes que la entrega
    assert outbox.sent == []
    post_body = {
        "id": delivery_id, "policy_id": world.policy.id, "delivery_date": "2026-10-22T10:00:00",
        "signature_name": "Cliente Uno", "signature_role": "Compras", "tech_id": world.tech.id,
        "report_ids": reports, "visit_id": world.visit1.id,
    }
    assert client.post("/api/policy-deliveries", json=post_body, headers=tech_headers).status_code == 201
    assert len(outbox.sent) == 1  # todo estaba en el servidor: sale al crear la entrega


def test_reportes_de_la_entrega_no_envian_correo_individual(client, world, tech_headers, outbox):
    world.add_contact("cliente@vibra.com")
    delivery_id, reports = sync_delivery(client, tech_headers, world, world.printers[:2])
    n = len(outbox.sent)
    # El disparo automático de la app (send-email sin manual) se omite para estos reportes.
    for rid in reports:
        res = client.post(f"/api/reports/{rid}/send-email", json={}, headers=tech_headers)
        assert res.status_code == 200
        assert res.json() == {"sent_to": [], "skipped": "policy_delivery"}
    assert len(outbox.sent) == n == 1


@pytest.mark.parametrize(
    "contacts,extra,expected",
    [
        (["a@x.com", "b@x.com"], None, ["a@x.com", "b@x.com"]),
        (["a@x.com", "b@x.com"], "c@y.com", ["a@x.com", "b@x.com", "c@y.com"]),
        (["a@x.com", "b@x.com"], "B@X.com", ["a@x.com", "b@x.com"]),  # duplicado (mayúsculas)
        (["a@x.com", "a@x.com"], None, ["a@x.com"]),
        ([], "solo@y.com", ["solo@y.com"]),
    ],
)
def test_destinatarios(client, world, tech_headers, outbox, contacts, extra, expected):
    for c in contacts:
        world.add_contact(c)
    world.add_contact("inactivo@x.com", active=False)
    sync_delivery(client, tech_headers, world, world.printers[:1], extra_email=extra)
    assert len(outbox.sent) == 1
    assert outbox.sent[0]["recipients"] == expected
    assert "inactivo@x.com" not in outbox.sent[0]["recipients"]


def test_sin_destinatarios_no_marca_enviado_y_sale_despues(client, world, db, tech_headers, outbox):
    delivery_id, reports = sync_delivery(client, tech_headers, world, world.printers[:1])
    assert outbox.sent == []
    assert _delivery(db, delivery_id).email_sent_at is None
    world.add_contact("nuevo@vibra.com")
    upload_report_pdf(client, tech_headers, reports[0])  # cualquier archivo posterior reintenta
    assert len(outbox.sent) == 1


def test_contenido_con_ligas_y_sin_adjuntos(client, world, db, tech_headers, outbox):
    world.add_contact("cliente@vibra.com")
    delivery_id, reports = sync_delivery(client, tech_headers, world, world.printers)
    item = outbox.sent[0]
    html = Outbox.html(item)
    assert not Outbox.has_attachment(item)
    assert "POL-2026-001" in html            # folio de póliza
    assert "Vibracoustic &amp; Co" in html   # cliente (escapado)
    assert "22/10/2026" in html              # fecha
    assert "Cliente Uno" in html and "Compras" in html  # quién firmó
    for p in world.printers:
        assert p.serial_number in html
    assert html.count("ZT411") == 3 and "Preventivo" in html
    tokens = LINK_RE.findall(html)
    # 3 ligas de equipo + 1 de resumen (+ la repetida en el texto de respaldo)
    assert len(set(tokens)) == 4
    assert all(len(t) >= 43 for t in tokens)
    assert "https://api.test.local/api/public/files/" in html
    assert "30 d" in html  # vigencia en el texto
    # Todas las ligas funcionan sin login.
    for t in set(tokens):
        res = client.get(f"/api/public/files/{t}")
        assert res.status_code == 200 and res.content.startswith(b"%PDF")


def test_falla_smtp_libera_el_reclamo(client, world, db, tech_headers, outbox):
    world.add_contact("cliente@vibra.com")
    outbox.fail = True
    delivery_id, reports = sync_delivery(client, tech_headers, world, world.printers[:1])
    assert outbox.sent == []
    assert _delivery(db, delivery_id).email_sent_at is None
    outbox.fail = False
    upload_report_pdf(client, tech_headers, reports[0])
    assert len(outbox.sent) == 1


def test_reenvio_manual_incluye_extra_y_regenera_ligas(client, world, db, tech_headers, admin_headers, outbox):
    world.add_contact("cliente@vibra.com")
    delivery_id, _ = sync_delivery(
        client, tech_headers, world, world.printers[:2], extra_email="quien.firmo@cliente.com"
    )
    assert len(outbox.sent) == 1
    old_tokens = set(LINK_RE.findall(Outbox.html(outbox.sent[0])))

    # Reenvío manual (mismas ligas vigentes)
    url = f"/api/admin/policy-deliveries/{delivery_id}/send-email"
    res = client.post(url, headers=admin_headers)
    assert res.status_code == 200
    assert res.json()["sent_to"] == ["cliente@vibra.com", "quien.firmo@cliente.com"]
    assert len(outbox.sent) == 2
    assert set(LINK_RE.findall(Outbox.html(outbox.sent[1]))) == old_tokens

    # Regenerar ligas y reenviar: las anteriores dejan de servir.
    res = client.post(url, json={"regenerate_links": True}, headers=admin_headers)
    assert res.status_code == 200
    new_tokens = set(LINK_RE.findall(Outbox.html(outbox.sent[2])))
    assert new_tokens and new_tokens.isdisjoint(old_tokens)
    for t in old_tokens:
        assert client.get(f"/api/public/files/{t}").status_code == 404
    for t in new_tokens:
        assert client.get(f"/api/public/files/{t}").status_code == 200


def test_reenvio_manual_requiere_login(client, world, tech_headers):
    delivery_id, _ = sync_delivery(client, tech_headers, world, world.printers[:1])
    assert client.post(f"/api/admin/policy-deliveries/{delivery_id}/send-email").status_code in (401, 403)


def test_correo_adicional_se_guarda_en_la_entrega(client, world, db, tech_headers, admin_headers):
    delivery_id, _ = sync_delivery(
        client, tech_headers, world, world.printers[:1], extra_email="  Extra@Cliente.com "
    )
    assert _delivery(db, delivery_id).extra_email == "Extra@Cliente.com"
    items = client.get(f"/api/admin/policies/{world.policy.id}/deliveries", headers=admin_headers).json()["items"]
    assert items[0]["extra_email"] == "Extra@Cliente.com"


def test_correo_adicional_invalido_rechazado_por_el_schema(client, world, tech_headers):
    rid = post_report(client, tech_headers, world, world.printers[0])
    for bad in ("sin-arroba", "a@b", "a b@c.com"):
        body = {
            "policy_id": world.policy.id, "delivery_date": "2026-10-22T10:00:00",
            "signature_name": "X", "signature_role": "Y", "tech_id": world.tech.id,
            "report_ids": [rid], "extra_email": bad,
        }
        assert client.post("/api/policy-deliveries", json=body, headers=tech_headers).status_code == 422


# -- reportes sueltos / agrupados fuera de póliza ----------------------------


def _loose_report(client, world, db, tech_headers):
    from tests.conftest import store_pdf

    # Impresora fuera de la póliza: reporte suelto con firma individual.
    from app.models.printer import Printer
    import uuid

    base = world.printers[0]
    p = Printer(
        id=str(uuid.uuid4()), qr_uuid=str(uuid.uuid4()), serial_number="SN-SUELTA",
        client_id=base.client_id, plant_id=base.plant_id, area_id=base.area_id,
        model_id=base.model_id, is_active=True,
    )
    db.add(p)
    db.commit()
    r = world.add_report(p, status="Signed")
    store_pdf(db, "report", r.id)
    return r


def test_reporte_suelto_envia_liga_sin_adjunto(client, world, db, tech_headers, outbox):
    world.add_contact("cliente@vibra.com")
    r = _loose_report(client, world, db, tech_headers)
    res = client.post(
        f"/api/reports/{r.id}/send-email",
        json={"extra_email": "otro@cliente.com"},
        headers=tech_headers,
    )
    assert res.status_code == 200
    assert res.json()["sent_to"] == ["cliente@vibra.com", "otro@cliente.com"]
    item = outbox.sent[0]
    html = Outbox.html(item)
    assert not Outbox.has_attachment(item)
    token = LINK_RE.search(html).group(1)
    assert client.get(f"/api/public/files/{token}").status_code == 200
    assert "SN-SUELTA" in html and r.code in html


def test_reporte_suelto_correo_adicional_invalido_422(client, world, db, tech_headers, outbox):
    r = _loose_report(client, world, db, tech_headers)
    res = client.post(f"/api/reports/{r.id}/send-email", json={"extra_email": "mal"}, headers=tech_headers)
    assert res.status_code == 422 and outbox.sent == []


def test_boton_enviar_manual_de_reporte_en_entrega_si_envia(client, world, tech_headers, outbox):
    world.add_contact("cliente@vibra.com")
    _, reports = sync_delivery(client, tech_headers, world, world.printers[:1])
    n = len(outbox.sent)
    res = client.post(
        f"/api/reports/{reports[0]}/send-email", json={"manual": True}, headers=tech_headers
    )
    assert res.status_code == 200 and res.json()["sent_to"] == ["cliente@vibra.com"]
    assert len(outbox.sent) == n + 1
    assert not Outbox.has_attachment(outbox.sent[-1])


def test_reenvio_con_liga_regenerada_de_reporte(client, world, db, tech_headers, outbox):
    world.add_contact("cliente@vibra.com")
    r = _loose_report(client, world, db, tech_headers)
    client.post(f"/api/reports/{r.id}/send-email", json={}, headers=tech_headers)
    old = LINK_RE.search(Outbox.html(outbox.sent[0])).group(1)
    client.post(f"/api/reports/{r.id}/send-email", json={"regenerate_link": True}, headers=tech_headers)
    new = LINK_RE.search(Outbox.html(outbox.sent[1])).group(1)
    assert old != new
    assert client.get(f"/api/public/files/{old}").status_code == 404
    assert client.get(f"/api/public/files/{new}").status_code == 200
