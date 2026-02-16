# DataKnow — Prueba Técnica

---

## Estructura del proyecto

```
dataknow_prueba/
├── data/                          # Archivos fuente 
│   ├── OFEI1204.txt               # Ofertas iniciales del mercado eléctrico
│   ├── dDEC1204.TXT               # Declaraciones por central
│   └── Datos_Maestros_VF.xlsx     # Master Data de agentes y centrales
│
├── scripts/
│   ├── prueba_1_carga.py          # Prueba 1 — extracción Tipo D de OFEI
│   ├── prueba_2_manipulacion.py   # Prueba 2 — manipulación + merge
│   └── prueba_3_sql.sql           # Prueba 3 — diseño y optimización SQL
│
├── outputs/                       # Resultados generados
│   ├── resultado_prueba1_OFEI_TipoD.csv
│   └── resultado_prueba2_EMGESA_HT.csv
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

# Prueba 6 — PRUEBA DE MODELACIÓN ANALÍTICA 
python scripts/prueba_6_modelo_fraude.py
```

Los CSV de resultados se guardan automáticamente en la carpeta `outputs/`.

---

# Prueba Técnica SQL — Sistema Meteorológico

---

## Requisitos

- Azure SQL Database o SQL Server
- Cliente SQL (Azure Data Studio, SSMS, o portal de Azure)

---

## Ejecución

Conectarse a la base de datos y ejecutar el archivo `prueba_sql_meteorologia.sql` completo.

---

## Contenido

| Parte | Descripción |
|---|---|
| **1** | Tabla horaria con tipos de datos apropiados y datos de ejemplo |
| **2** | Tres mejoras para millones de registros: índices, particionamiento, vista materializada |
| **3** | Tabla diaria en Fahrenheit con migración automática desde tabla horaria |
| **4** | Columna delta retroactiva usando `LAG()` en ambas tablas |


## Dependencias

```
pandas==2.2.2       # Manipulación de DataFrames
openpyxl==3.1.2     # Lectura de archivos .xlsx
```

---
