# DataKnow — Prueba Técnica

---

## Estructura del proyecto
```
dataknow_prueba/
├── data/                          # Archivos fuente (no modificar)
│   ├── OFEI1204.txt               # Ofertas iniciales del mercado eléctrico
│   ├── dDEC1204.TXT               # Declaraciones por central (24 h)
│   ├── Datos_Maestros_VF.xlsx     # Master Data de agentes y centrales
│   ├── train.csv                  # Dataset de entrenamiento (fraude)
│   ├── test.csv                   # Dataset de evaluación (fraude)
│   └── diccionario_variables.xlsx # Descripción de variables
│
├── scripts/
│   ├── prueba_1_carga.py          # Prueba 1 — extracción Tipo D de OFEI
│   ├── prueba_2_manipulacion.py   # Prueba 2 — manipulación + merge
│   ├── prueba_3_sql.sql           # Prueba 3 — diseño y optimización SQL
│   └── prueba_6_modelo_fraude.py  # Prueba 6 — modelo de detección de fraude
│
├── outputs/                       # Resultados generados (se crea automáticamente)
│   ├── resultado_prueba1_OFEI_TipoD.csv
│   ├── resultado_prueba2_EMGESA_HT.csv
│   └── test_evaluado.csv          # Predicciones del modelo (probabilidad 0-1)
│
├── requirements.txt
└── README.md
```

---

## Requisitos previos

| Herramienta | Versión mínima |
|---|---|
| Python | 3.9+ |
| pip | 23+ |

---

## Configuración del entorno (VS Code + venv)

### 1. Clonar / descomprimir el proyecto
```bash
# Si tienes el ZIP:
unzip dataknow_prueba.zip
cd dataknow_prueba
```

### 2. Crear el entorno virtual
```bash
# Windows
python -m venv .venv
.venv\Scripts\activate

# macOS / Linux
python3 -m venv .venv
source .venv/bin/activate
```

### 3. Instalar dependencias
```bash
pip install -r requirements.txt
```

### 4. Seleccionar el intérprete en VS Code

Abre la paleta de comandos (`Ctrl+Shift+P` / `Cmd+Shift+P`) y ejecuta:
```
Python: Select Interpreter
```

Selecciona `.venv` (aparece como `('.venv': venv)`).

---

## Ejecución

Desde la raíz del proyecto con el venv activo:
```bash
# Prueba 1 — Carga de OFEI1204.txt (registros Tipo D)
python scripts/prueba_1_carga.py

# Prueba 2 — Manipulación de datos + merge con dDEC1204
python scripts/prueba_2_manipulacion.py

# Prueba 6 — Detección de fraude (Random Forest)
python scripts/prueba_6_modelo_fraude.py
```

Los CSV de resultados se guardan automáticamente en la carpeta `outputs/`.

---

## Prueba Técnica SQL — Sistema Meteorológico

---

### Requisitos

- Azure SQL Database o SQL Server
- Cliente SQL (Azure Data Studio, SSMS, o portal de Azure)

---

### Ejecución

Conectarse a la base de datos y ejecutar el archivo `prueba_sql_meteorologia.sql` completo.

---

### Contenido

| Parte | Descripción |
|---|---|
| **1** | Tabla horaria con tipos de datos apropiados y datos de ejemplo |
| **2** | Tres mejoras para millones de registros: índices, particionamiento, vista materializada |
| **3** | Tabla diaria en Fahrenheit con migración automática desde tabla horaria |
| **4** | Columna delta retroactiva usando `LAG()` en ambas tablas |

---

## Prueba 6 — Modelación Analítica (Detección de Fraude)

### Objetivo
Construir un modelo que prediga la probabilidad de fraude (0-1) para transacciones de tarjetas de crédito/débito en el exterior.

### Datos
- **train.csv**: 2.965 transacciones (75% legítimas, 25% fraudes)
- **test.csv**: 100 transacciones a evaluar
- **26 variables**: valor, hora, distancias, perfil del cliente, canal, país

### Modelo implementado
- **Algoritmo**: Random Forest (300 árboles)
- **Preprocesamiento**: Imputación (mediana/moda) + One-Hot Encoding
- **Manejo de desbalanceo**: `class_weight='balanced'`
- **Métrica de validación**: ROC-AUC = **0.9673 ± 0.0122** (5-fold CV)

### Salida
El archivo `outputs/test_evaluado.csv` contiene las 100 transacciones con su columna `FRAUDE` poblada con valores entre 0 y 1, donde:
- **0** = transacción legítima (baja probabilidad de fraude)
- **1** = transacción fraudulenta (alta probabilidad de fraude)

**Resultado**: 37 transacciones clasificadas como fraude probable (P > 0.5), 63 como legítimas.

---


## Dependencias
```
pandas==2.2.2       # Manipulación de DataFrames
openpyxl==3.1.2     # Lectura de archivos .xlsx
scikit-learn==1.5.1 # Machine learning (Random Forest, preprocesamiento)
```