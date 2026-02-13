"""
PRUEBA 1 - CARGA DE INFORMACIÓN
================================
Carga y depuración del archivo OFEI1204.txt.
Extrae únicamente los registros de Tipo D y genera una
tabla con columnas: Agente, Planta, Hora_1 ... Hora_24

Uso:
    python scripts/prueba_1_carga.py
"""

import re
from pathlib import Path

import pandas as pd

# ── Rutas ────────────────────────────────────────────────────────────────────
ROOT      = Path(__file__).resolve().parent.parent
DATA_DIR  = ROOT / "data"
OUT_DIR   = ROOT / "outputs"
OUT_DIR.mkdir(exist_ok=True)

FILE_INPUT  = DATA_DIR / "OFEI1204.txt"
FILE_OUTPUT = OUT_DIR  / "resultado_prueba1_OFEI_TipoD.csv"


def parse_ofei(filepath: Path) -> pd.DataFrame:
    """Lee OFEI1204.txt y retorna un DataFrame con los registros Tipo D."""

    records       = []
    current_agent = None

    with open(filepath, "r", encoding="utf-8", errors="replace") as fh:
        for raw_line in fh:
            line = raw_line.strip()

            # ── Detectar encabezado de agente ────────────────────────────
            if line.upper().startswith("AGENTE:"):
                current_agent = line.split(":", 1)[1].strip()
                continue

            # ── Filtrar registros Tipo D ──────────────────────────────────
            # Formato:  PLANTA , D,  val1, val2, ..., val24
            if not re.search(r",\s*D\s*,", line):
                continue

            parts = [p.strip() for p in line.split(",")]

            # Validar: tipo en posición 1 == 'D' y al menos 26 campos
            if len(parts) < 26 or parts[1].strip().upper() != "D":
                continue

            planta = parts[0].strip()
            raw_vals = parts[2:26]          # exactamente 24 valores horarios

            # Convertir a float con manejo seguro de valores no numéricos
            horas_num = []
            for v in raw_vals:
                try:
                    horas_num.append(float(v))
                except ValueError:
                    horas_num.append(0.0)

            row = {"Agente": current_agent, "Planta": planta}
            for i, val in enumerate(horas_num, start=1):
                row[f"Hora_{i}"] = val
            records.append(row)

    cols = ["Agente", "Planta"] + [f"Hora_{i}" for i in range(1, 25)]
    return pd.DataFrame(records, columns=cols)


def main():
    print("=" * 60)
    print("PRUEBA 1 — CARGA DE INFORMACIÓN (OFEI1204.txt, Tipo D)")
    print("=" * 60)

    df = parse_ofei(FILE_INPUT)

    print(f"\nRegistros Tipo D extraídos : {len(df)}")
    print(f"Agentes únicos             : {df['Agente'].nunique()}")
    print(f"Columnas                   : {df.columns.tolist()}")
    print("\nPrimeras 5 filas:")
    print(df.head(5).to_string(index=False))

    df.to_csv(FILE_OUTPUT, index=False, encoding="utf-8-sig")
    print(f"\n✅  Resultado guardado en: {FILE_OUTPUT}")


if __name__ == "__main__":
    main()
