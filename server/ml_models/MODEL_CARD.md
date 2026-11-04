# Modelo de riesgo de piezas — `modelo_riesgo.joblib`

| | |
|---|---|
| Versión | `1df1bcd2` |
| Entrenado | 2026-10-27 (por Aurora, módulo `modulo_riesgo/`) |
| scikit-learn | **1.9.1** (el `.joblib` solo carga con esa versión; numpy 2.5.4, pandas 3.1.0) |
| Algoritmo | Random Forest (300 árboles, profundidad 4), 5 semillas por pieza, uno por pieza (cabezal, rodillo) |
| Objetivo | Pieza aparece dañada en alguna visita dentro de los 90 días posteriores a la última visita |
| Datos | 59 equipos / 426 visitas en la base; 54 equipos / 159 filas con etiqueta a 90 días |
| Artefacto | Se versiona en git. No se reentrena ni se regenera como parte de la integración |

## Métricas de referencia (README del módulo, validación agrupada por equipo)

| Pieza | PR-AUC [IC 95 %] | Recall con 30 % de alertas [IC 95 %] | Tasa base |
|---|---|---|---|
| Cabezal | 0.607 [0.478, 0.761] | 0.622 [0.466, 0.779] | 0.283 |
| Rodillo | 0.436 [0.304, 0.595] | 0.487 [0.376, 0.671] | 0.195 |

## Definición de las banderas `cabezal` y `rodillo` (criterio de Aurora)

Confirmado por quien armó el Excel de entrenamiento: la bandera de una pieza vale 1 cuando el reporte indica que
**esa pieza** fue reemplazada o estaba deteriorada, aunque el checkbox "dañado" no esté marcado. Se toma como daño o
desgaste previo.

- **Cuenta como positivo** (en las notas del reporte, referido al cabezal o al rodillo): reemplazo, cambio,
  sustitución, daño, desgaste, quemado o rotura.
- **No cuenta:** limpieza, revisión sin hallazgos, ni otras piezas (ribbon, spindle, sensores).
- `falla` = 1 si alguna pieza de daño (rodillo, cabezal, sensor ribbon, sensor papel) vale 1.

Evidencia (copia local, 152 visitas posteriores a 2026-04-28): en 16 visitas el Excel marca cabezal o rodillo y el
checklist de la app no (9 cabezal, 7 rodillo); en todas las notas mencionan el cambio o el daño. Nunca ocurre lo
contrario. `ReportPart` está vacío en la base, así que no interviene.

**Estado:** la derivación actual de la app (`server/app/risk/queries.py`) lee solo el checklist
(`technical_checkboxes`), por lo que subestima respecto de este criterio hasta que se alinee. Los demás campos
(mantenimiento, calibración, sensores, contador) no muestran diferencias de definición.

## Niveles

ALTO = puntaje en el 30 % más alto observado fuera de muestra; MEDIO = siguiente 20 %; BAJO = resto.
`indice_riesgo` es un percentil relativo (0–100), **no una probabilidad** ni una fecha de falla.

## Limitaciones

- **Rodillo:** evidencia débil; casi solo repite el daño actual. Mostrarlo como “en monitoreo”.
- Métricas medidas solo en visitas con revisita dentro de 90 días (sesgo de selección).
- Pocos equipos: intervalos de confianza amplios.
- **Desajuste de historial:** el modelo se entrenó con historial (2023 → 2026) que no está completo en la base de la app. Con pocas visitas, `n_visita`, `acum_*` y `fallas_previas_acum` salen bajos y el riesgo tiende a subestimarse (ver addendum, §1).
- Los sensores no se predicen (muy pocos casos).

## Nota sobre los umbrales

Los umbrales ALTO/MEDIO se calculan con puntajes fuera de muestra que usan 2 de las 5 semillas
(`_ajustar(...)[:2]` en `oof_scores`), mientras que el modelo final usa las 5. Se midió el efecto:
el porcentaje real de equipos en ALTO es 28.9 % (cabezal) y 32.7 % (rodillo) frente al 30 % objetivo,
con correlación de rangos 0.999. Es despreciable y **no se cambia**: cambiarlo exigiría reentrenar y
modificaría las métricas reportadas en el TT.

## Entorno

VPS: Python 3.12.3 (`venv313`). Local: Python 3.13. Instalar con `pip install -r requirements-ml.txt`.
Si `cargar()` lanza `ModeloNoDisponible` por versión, reentrenar en ese entorno con `python -m app.risk.entrenar_cli`.
