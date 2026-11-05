"""Inferencia de dano de cabezal/rodillo por notas (app/risk/notas.py). No necesita numpy ni pandas.
Los textos son inventados (no son notas reales de clientes)."""
import pytest

from app.risk.notas import inferir_dano


@pytest.mark.parametrize("texto,cabezal,rodillo", [
    ("Cabezal dañado, se cotiza para cambio", True, False),
    ("-Se realiza cambio de cabezal de impresión y rodillo -Impresora Ok", True, True),
    ("-Se realiza cambio de Cabezal\n-Se realiza cambio de Rodillo", True, True),
    ("Rodillo principal dañado por navaja", False, True),
    ("Se notan pequeños daños en el rodillo", False, True),
    ("Desgaste del cabezal, quemado en la zona central", True, False),
    ("Cabezal de impresión presenta daño prematuro, se ajustan toggles", True, False),
    ("Se realiza cambio de tarjeta lógica. Cabezal dañado anteriormente", True, False),
    ("Impresora no imprime se cambia cabezal", True, False),
    ("No imprime, se reemplaza rodillo", False, True),
    # no cuentan
    ("Se realiza limpieza de cabezal y rodillo", False, False),
    ("Revisión de cabezal sin daño. Rodillo en buen estado", False, False),
    ("Cabezal sin desgaste, no requiere cambio de rodillo", False, False),
    ("Spindle rebobinador de ribbon dañado -Sensor de papel dañado", False, False),
    ("-Palanca de apertura de cabezal rota", False, False),
    ("Ajuste de tornillo de palanca de apertura de cabezal", False, False),
    ("Rodillo de arrastre de ribbon dañado", False, False),
    ("Impresora Funcionando Ok, se realiza pruebas de cabezal y sensores en buen estado", False, False),
    ("Visita de Servicio 3 de 4 19-08-2026. Cabezal ok", False, False),
    ("Sin daño en cabezal", False, False),
    ("Cabezal en buen estado", False, False),
    ("Se limpia rodillo", False, False),
    ("No requiere cambio", False, False),
    ("No requiere cambio de cabezal ni de rodillo", False, False),
    ("Cabezal y rodillo en buen estado, sin daño ni desgaste", False, False),
    ("Cabezal no presenta daño", False, False),
    ("", False, False),
    (None, False, False),
])
def test_inferir_dano(texto, cabezal, rodillo):
    assert inferir_dano(texto, "cabezal") is cabezal
    assert inferir_dano(texto, "rodillo") is rodillo


def test_pieza_desconocida():
    with pytest.raises(ValueError):
        inferir_dano("cambio de sensor", "sensor")
