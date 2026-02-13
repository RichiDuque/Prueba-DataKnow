# DataKnow — Prueba Técnica

---

## Estructura del proyecto

```
dataknow_prueba/
├── data/                          # Archivos fuente (no modificar)
│   ├── OFEI1204.txt               # Ofertas iniciales del mercado eléctrico
│   ├── dDEC1204.TXT               # Declaraciones por central (24 h)
│   └── Datos_Maestros_VF.xlsx     # Master Data de agentes y centrales
│
├── scripts/
│   ├── prueba_1_carga.py          # Prueba 1 — extracción Tipo D de OFEI
│   ├── prueba_2_manipulacion.py   # Prueba 2 — manipulación + merge
│   └── prueba_3_sql.sql           # Prueba 3 — diseño y optimización SQL
│
├── outputs/                       # Resultados generados (se crea automáticamente)
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

## Prueba 3 — SQL

El script `scripts/prueba_3_sql.sql` está escrito en **PostgreSQL** (ANSI SQL compatible).  
Se puede ejecutar en:

- **pgAdmin 4** — pegar el contenido en el Query Tool
- **DBeaver** — abrir el archivo y ejecutar por secciones (`F5` o `Ctrl+Enter`)
- **psql** — `psql -U usuario -d basededatos -f scripts/prueba_3_sql.sql`
- **SQLite** — las Partes 1 y 4 funcionan directamente; las Partes 2 y 3 requieren ajustes menores (sin `PARTITION BY` nativo)

El script cubre **cuatro partes**:

| Parte | Contenido |
|---|---|
| 1 | Diseño de tabla `meteorologia_horaria` con tipos correctos, PK y constraints |
| 2 | Tres mejoras para escalar a millones de registros (índices, particionamiento, vistas materializadas) |
| 3 | Tabla diaria en Fahrenheit con migración automática desde la tabla horaria |
| 4 | Columna `delta_temp` retroactiva usando `LAG()` en ambas tablas |

---

## Resultados esperados

### Prueba 1

| Métrica | Valor |
|---|---|
| Registros Tipo D | 305 |
| Agentes únicos | 54 |
| Columnas de salida | 26 (Agente, Planta, Hora\_1…Hora\_24) |

### Prueba 2

| Central | Tipo | Suma Horas |
|---|---|---|
| BETANIA | H | 8,736 |
| ELQUIMBO | H | 2,040 |
| GUAVIO | H | 4,325 |
| PAGUA | H | 14,400 |

> Las 7 centrales térmicas (CTGEMG1/2/3, ZIPAEMG2/3/4/5) se descartan por tener suma = 0.

---

## Dependencias

```
pandas==2.2.2       # Manipulación de DataFrames
openpyxl==3.1.2     # Lectura de archivos .xlsx
```

---

## Autor

Solución desarrollada para la convocatoria **DataKnow** — Perfil Analítico / Ingeniero de Datos / Científico de Datos.
