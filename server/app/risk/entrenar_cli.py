"""Reentrenamiento periodico (solo local/manual). Uso desde server/:
    python -m app.risk.entrenar_cli --visitas ruta.csv --salida ml_models/modelo_riesgo.joblib
El modelo nuevo reemplaza al anterior solo si su PR-AUC de validacion no cae mas de TOLERANCIA en ninguna pieza."""
import argparse, os, shutil, sys
from . import datos as D, modelo as M

TOLERANCIA = 0.03

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--visitas', required=True); ap.add_argument('--salida', default='ml_models/modelo_riesgo.joblib')
    ap.add_argument('--forzar', action='store_true')
    a = ap.parse_args()
    V = D.cargar_visitas(a.visitas)
    nuevo = M.entrenar(V)
    print(f"Candidato {nuevo['version']}: {nuevo['n_filas_entrenamiento']} filas / {nuevo['n_equipos_entrenamiento']} equipos")
    for pz, p in nuevo['piezas'].items():
        print(f"  {pz}: PR-AUC validacion {p['pr_auc_validacion']:.3f} (tasa base {p['tasa_base']:.3f}, {p['positivos']} positivos)")
    if os.path.exists(a.salida) and not a.forzar:
        ant = M.cargar(a.salida)
        peor = [pz for pz in nuevo['piezas'] if nuevo['piezas'][pz]['pr_auc_validacion'] < ant['piezas'][pz]['pr_auc_validacion'] - TOLERANCIA]
        if peor:
            print(f'NO se reemplaza el modelo vigente ({ant["version"]}): empeora en {peor}. Use --forzar para reemplazar.'); sys.exit(1)
        shutil.copy(a.salida, a.salida + '.' + ant['version'] + '.bak')
    M.guardar(nuevo, a.salida); print('Modelo guardado en', a.salida)

if __name__ == '__main__':
    main()
