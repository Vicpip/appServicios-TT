"""Inferencia de dano de cabezal y rodillo a partir de las notas del reporte (criterio de Aurora).

Criterio (confirmado por quien armo el Excel de entrenamiento; ver ml_models/MODEL_CARD.md): la bandera de una pieza
vale 1 si las notas indican reemplazo, cambio, sustitucion, dano, desgaste, quemado o rotura de ESA pieza (cabezal o
rodillo), aunque el checkbox "dañado" no este marcado. No cuentan limpieza, revision sin hallazgos ni otras piezas
(ribbon, spindle, sensores, palanca o seguro del cabezal, tarjeta).

Implementacion: el texto se normaliza (sin acentos, minusculas) y se parte en clausulas (salto de linea, punto, ';', ',',
vinetas con guion). Una clausula es positiva para una pieza si la menciona y trae un termino positivo sin negacion
("sin", "no", "ningun") inmediatamente antes (maximo 2 palabras de distancia). "no imprime/funciona/enciende/calibra/lee"
no cuenta como negacion. Sin numpy ni pandas: se puede importar en cualquier entorno.
"""
import re
import unicodedata

PIEZAS = ("cabezal", "rodillo")

_CLAUSULAS = re.compile(r"[\n\r.;,]+|(?:^|\s)-+\s*")
_MENCION = {"cabezal": re.compile(r"\bcabezal(?:es)?\b"), "rodillo": re.compile(r"\brodillos?\b")}
# El nombre de la pieza solo califica a otra pieza: "palanca de apertura de cabezal", "seguro del cabezal", ...
_ACCESORIO = re.compile(r"\b(?:palanca|seguro|tornillo|toggles?|perilla|liberador|mecanismo|tapa|cubierta|cable|flex|"
                        r"banda|sensor|tarjeta)\w*(?:\s+\w+){0,3}?\s+(?:de|del)\s+(?:apertura\s+)?(?:de\s+)?(?:el\s+)?$")
_POSITIVO = re.compile(r"\b(?:cambi\w*|reemplaz\w*|sustitu\w*|dan[oa]\w*|desgast\w*|quemad\w*|rot[oa]s?\b|rotur\w*|"
                       r"navaj\w*|deteriorad\w*)")
# Negacion que anula al termino positivo solo si lo precede de inmediato (hasta 2 palabras en medio). "no" seguido de
# imprime/funciona/enciende/calibra/lee describe la falla de la impresora, no niega el cambio de la pieza.
_NEGACION_PREVIA = re.compile(r"\b(?:sin|no(?!\s+(?:imprim|funcion|enciend|calibr|lee\b))|ningun[oa]?)\b(?:\s+\w+){0,2}\s*$")


def _normalizar(texto: str) -> str:
    base = unicodedata.normalize("NFKD", texto.casefold())
    return "".join(c for c in base if not unicodedata.combining(c))


def _menciona(clausula: str, pieza: str) -> bool:
    """La clausula nombra la pieza como tal (no como parte del nombre de un accesorio ni del rodillo del ribbon)."""
    for m in _MENCION[pieza].finditer(clausula):
        if _ACCESORIO.search(clausula[:m.start()]):
            continue
        if pieza == "rodillo" and "ribbon" in clausula and "principal" not in clausula:
            continue
        return True
    return False


def _positiva(clausula: str, pieza: str) -> bool:
    if not _menciona(clausula, pieza):
        return False
    return any(not _NEGACION_PREVIA.search(clausula[:m.start()]) for m in _POSITIVO.finditer(clausula))


def inferir_dano(notas: str | None, pieza: str) -> bool:
    """True si las notas indican cambio o dano de `pieza` ('cabezal' o 'rodillo'). Notas vacias o None -> False."""
    if pieza not in PIEZAS:
        raise ValueError(f"pieza desconocida: {pieza!r}")
    if not notas or not str(notas).strip():
        return False
    return any(_positiva(c, pieza) for c in _CLAUSULAS.split(_normalizar(str(notas))) if c.strip())
