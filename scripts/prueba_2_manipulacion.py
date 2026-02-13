"""
PRUEBA 2 - MANIPULACIÓN DE DATOS
==================================
Pasos:
  1. Carga Master Data (4 columnas seleccionadas)
  2. Filtra agente EMGESA / EMGESA S.A. con Tipo 'H' o 'T'
  3. Carga dDEC1204.TXT (declaración por central, 24 horas)
  4. Merge inner por columna 'Central'
  5. Calcula suma horizontal de las 24 horas
  6. Retiene solo plantas con suma > 0

Uso:
    python scripts/prueba_2_manipulacion.py
"""

from pathlib import Path

import pandas as pd

# ── Rutas ────────────────────────────────────────────────────────────────────
ROOT      = Path(__file__).resolve().parent.parent
DATA_DIR  = ROOT / "data"
OUT_DIR   = ROOT / "outputs"
OUT_DIR.mkdir(exist_ok=True)

FILE_MASTER = DATA_DIR / "Datos_Maestros_VF.xlsx"
FILE_DDEC   = DATA_DIR / "dDEC1204.TXT"
FILE_OUTPUT = OUT_DIR  / "resultado_prueba2_EMGESA_HT.csv"

HORA_COLS = [f"Hora_{i}" for i in range(1, 25)]


# ─────────────────────────────────────────────────────────────────────────────
def load_master_data(filepath: Path) -> pd.DataFrame:
    """Carga las 4 columnas requeridas de la hoja 'Master Data Oficial'."""
    df = pd.read_excel(
        filepath,
        sheet_name="Master Data Oficial",
        usecols=[
            "Nombre visible Agente",
            "AGENTE (OFEI)",
            "CENTRAL (dDEC, dSEGDES, dPRU\u2026)",   # carácter … original
            "Tipo de central (Hidro, Termo, Filo, Menor)",
        ],
    )
    df.columns = ["Nombre_Agente", "Agente_OFEI", "Central", "Tipo_Central"]
    return df


def filter_emgesa_ht(df: pd.DataFrame) -> pd.DataFrame:
    """Filtra registros de EMGESA (o EMGESA S.A.) con Tipo H o T."""
    agents_ok = {"EMGESA", "EMGESA S.A."}

    mask_agente = (
        df["Nombre_Agente"].str.strip().str.upper().isin(agents_ok)
        | df["Agente_OFEI"].str.strip().str.upper().isin(agents_ok)
    )
    mask_tipo = df["Tipo_Central"].str.strip().str.upper().isin({"H", "T"})

    return (
        df[mask_agente & mask_tipo]
        .drop_duplicates(subset=["Central"])
        .reset_index(drop=True)
    )


def load_ddec(filepath: Path) -> pd.DataFrame:
    """Parsea dDEC1204.TXT (CSV sin encabezado: central + 24 valores)."""
    rows = []
    with open(filepath, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            parts = [p.strip().strip('"') for p in line.split(",")]
            if len(parts) < 25:
                continue
            central = parts[0]
            if central.upper() == "TOTAL":      # ignorar fila de totales
                continue
            nums = []
            for v in parts[1:25]:
                try:
                    nums.append(float(v))
                except ValueError:
                    nums.append(0.0)
            row = {"Central": central}
            for i, val in enumerate(nums, start=1):
                row[f"Hora_{i}"] = val
            rows.append(row)
    return pd.DataFrame(rows)


# ─────────────────────────────────────────────────────────────────────────────
def main():
    # ── Paso 1: cargar Master Data ────────────────────────────────────────
    print("=" * 60)
    print("PASO 1 — Cargando Master Data")
    print("=" * 60)
    df_master = load_master_data(FILE_MASTER)
    print(f"Registros totales: {len(df_master)}")

    # ── Paso 2: filtrar EMGESA con H o T ─────────────────────────────────
    print("\n" + "=" * 60)
    print("PASO 2 — Filtrando EMGESA (H | T)")
    print("=" * 60)
    df_emgesa = filter_emgesa_ht(df_master)
    print(f"Centrales encontradas: {len(df_emgesa)}")
    print(df_emgesa[["Nombre_Agente", "Agente_OFEI", "Central", "Tipo_Central"]].to_string(index=False))

    # ── Paso 3: cargar dDEC ───────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("PASO 3 — Cargando dDEC1204.TXT")
    print("=" * 60)
    df_ddec = load_ddec(FILE_DDEC)
    print(f"Registros en dDEC: {len(df_ddec)}")

    # ── Paso 4: merge por Central ─────────────────────────────────────────
    print("\n" + "=" * 60)
    print("PASO 4 — Merge por Central (inner join)")
    print("=" * 60)
    df_merged = df_emgesa.merge(df_ddec, on="Central", how="inner")
    print(f"Registros tras el merge: {len(df_merged)}")

    # ── Paso 5: suma horizontal de horas ──────────────────────────────────
    print("\n" + "=" * 60)
    print("PASO 5 — Suma horizontal de las 24 horas")
    print("=" * 60)
    cols_presentes = [c for c in HORA_COLS if c in df_merged.columns]
    df_merged["Suma_Horas"] = df_merged[cols_presentes].sum(axis=1)
    print(df_merged[["Central", "Tipo_Central", "Suma_Horas"]].to_string(index=False))

    # ── Paso 6: filtrar plantas con suma > 0 ──────────────────────────────
    print("\n" + "=" * 60)
    print("PASO 6 — Plantas con Suma_Horas > 0")
    print("=" * 60)
    df_result = df_merged[df_merged["Suma_Horas"] > 0].reset_index(drop=True)
    print(f"Plantas finales: {len(df_result)}")
    print(
        df_result[["Nombre_Agente", "Agente_OFEI", "Central", "Tipo_Central", "Suma_Horas"]]
        .to_string(index=False)
    )

    # ── Exportar ──────────────────────────────────────────────────────────
    df_result.to_csv(FILE_OUTPUT, index=False, encoding="utf-8-sig")
    print(f"\n✅  Resultado guardado en: {FILE_OUTPUT}")


if __name__ == "__main__":
    main()
