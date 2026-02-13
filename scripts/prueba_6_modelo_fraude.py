"""
PRUEBA 6 - MODELACIÓN ANALÍTICA (Detección de Fraude)
======================================================
Estrategia: Random Forest con preprocesamiento mínimo.
  - Imputación numérica con mediana, categórica con moda
  - Encoding one-hot de variables categóricas
  - class_weight='balanced' para manejar desbalanceo 75/25
  - Salida: probabilidad de fraude (0-1) por transacción

Uso:
    python scripts/prueba_6_modelo_fraude.py
"""

from pathlib import Path

import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import classification_report, roc_auc_score
from sklearn.model_selection import cross_val_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

# ── Rutas ────────────────────────────────────────────────────────────────────
ROOT        = Path(__file__).resolve().parent.parent
DATA_DIR    = ROOT / "data"
OUT_DIR     = ROOT / "outputs"
OUT_DIR.mkdir(exist_ok=True)

TRAIN_FILE  = DATA_DIR / "train.csv"
TEST_FILE   = DATA_DIR / "test.csv"
OUTPUT_FILE = OUT_DIR  / "test_evaluado.csv"

# Columnas a descartar (IDs, fechas, target)
DROP_COLS = {"ID", "id", "FRAUDE", "FECHA", "FECHA_VIN", "OFICINA_VIN", "FECHA_FRAUDE"}


# ─────────────────────────────────────────────────────────────────────────────
def load_clean(path: Path) -> pd.DataFrame:
    """
    Carga CSV y elimina columnas duplicadas que solo difieren en mayúsculas.
    Conserva la primera aparición de cada nombre normalizado.
    """
    df = pd.read_csv(path)
    # Deduplicar por nombre en uppercase: quedarse con la primera ocurrencia
    seen = {}
    keep = []
    for col in df.columns:
        key = col.upper()
        if key not in seen:
            seen[key] = col
            keep.append(col)
    df = df[keep]
    # Ahora normalizar a uppercase
    df.columns = df.columns.str.upper()
    return df


# ─────────────────────────────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("PRUEBA 6 — DETECCIÓN DE FRAUDE (Random Forest)")
    print("=" * 60)

    # ── 1. Cargar y limpiar ───────────────────────────────────────────────
    train = load_clean(TRAIN_FILE)
    test  = load_clean(TEST_FILE)

    print(f"\nTrain: {train.shape}  |  Test: {test.shape}")
    vc = train["FRAUDE"].value_counts()
    print(f"Distribución — 0 legítimo: {vc[0]}  |  1 fraude: {vc[1]}  "
          f"|  tasa fraude: {vc[1]/len(train):.1%}")

    # ── 2. Separar target ─────────────────────────────────────────────────
    y_train = train["FRAUDE"]

    # ── 3. Construir features: eliminar columnas no útiles ────────────────
    drop_train = [c for c in DROP_COLS if c in train.columns]
    drop_test  = [c for c in DROP_COLS if c in test.columns]
    X_train_all = train.drop(columns=drop_train)
    X_test_all  = test.drop(columns=drop_test)

    # Usar solo columnas comunes entre train y test (en el mismo orden)
    common_cols = [c for c in X_train_all.columns if c in X_test_all.columns]
    X_train = X_train_all[common_cols].copy()
    X_test  = X_test_all[common_cols].copy()

    print(f"\nFeatures comunes train/test: {len(common_cols)}")

    # ── 4. Separar numéricas y categóricas ────────────────────────────────
    num_cols = X_train.select_dtypes(include="number").columns.tolist()
    cat_cols = X_train.select_dtypes(exclude="number").columns.tolist()
    print(f"Numéricas ({len(num_cols)}):   {num_cols}")
    print(f"Categóricas ({len(cat_cols)}): {cat_cols}")

    # ── 5. Pipeline ───────────────────────────────────────────────────────
    preprocessor = ColumnTransformer([
        ("num", SimpleImputer(strategy="median"), num_cols),
        ("cat", Pipeline([
            ("imp", SimpleImputer(strategy="most_frequent")),
            ("ohe", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
        ]), cat_cols),
    ])

    model = Pipeline([
        ("prep", preprocessor),
        ("clf",  RandomForestClassifier(
            n_estimators=300,
            class_weight="balanced",
            random_state=42,
            n_jobs=-1,
        )),
    ])

    # ── 6. Validación cruzada ─────────────────────────────────────────────
    print("\n── Validación cruzada 5-fold (ROC-AUC) ──")
    auc_cv = cross_val_score(model, X_train, y_train,
                             cv=5, scoring="roc_auc", n_jobs=-1)
    print(f"  ROC-AUC: {auc_cv.mean():.4f}  ±  {auc_cv.std():.4f}")

    # ── 7. Entrenamiento final ────────────────────────────────────────────
    print("\n── Entrenando sobre train completo ──")
    model.fit(X_train, y_train)

    y_prob_train = model.predict_proba(X_train)[:, 1]
    y_pred_train = (y_prob_train >= 0.5).astype(int)
    print("\nMétricas en train (referencia):")
    print(classification_report(y_train, y_pred_train,
                                 target_names=["Legítimo", "Fraude"]))
    print(f"ROC-AUC train: {roc_auc_score(y_train, y_prob_train):.4f}")

    # ── 8. Predicción en test ─────────────────────────────────────────────
    print("\n── Predicción sobre test ──")
    y_prob_test = model.predict_proba(X_test)[:, 1]

    # ── 9. Exportar test_evaluado.csv ─────────────────────────────────────
    # Cargar test original para conservar columnas y orden tal cual
    result = pd.read_csv(TEST_FILE)
    result["FRAUDE"] = y_prob_test
    result.to_csv(OUTPUT_FILE, index=False)

    print(f"\n✅  test_evaluado.csv → {OUTPUT_FILE}")
    print(f"   Filas exportadas:           {len(result)}")
    print(f"   P(fraude) media:            {y_prob_test.mean():.4f}")
    print(f"   Transacciones con P > 0.5: {(y_prob_test >= 0.5).sum()}")
    print(f"\nPrimeras predicciones:")
    preview = result[["id", "FRAUDE"]].head(10)
    print(preview.to_string(index=False))


if __name__ == "__main__":
    main()
