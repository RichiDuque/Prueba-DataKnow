-- =============================================================
--  PRUEBA 3 – T-SQL  |  Azure SQL Database
--  DataKnow – Prueba Técnica de Conocimiento
-- =============================================================
-- PARTE 1 – DISEÑO DE LA TABLA METEOROLÓGICA HORARIA
-- =============================================================
/*
  DECISIONES DE DISEÑO
  ──────────────────────────────────────────────────────────────
  · IDENTITY(1,1)    → PK surrogate auto-incremental (= SERIAL)
  · DATETIMEOFFSET   → equivalente a TIMESTAMPTZ, guarda offset
                       de zona horaria en el valor mismo
  · UNIQUE (localidad, fecha_hora) → un registro por lugar/hora
  · NUMERIC vs FLOAT → evita errores de punto flotante en
                        cálculos de temperatura y conversiones
  · CHECK cobertura  → restringe a 'Mínima','Parcial','Total'
  · indice_uv NULL   → válido de noche (sin radiación solar)
*/

IF OBJECT_ID('dbo.meteorologia_horaria', 'U') IS NOT NULL
    DROP TABLE dbo.meteorologia_horaria;

CREATE TABLE dbo.meteorologia_horaria (
    id               INT             NOT NULL IDENTITY(1,1),
    localidad        NVARCHAR(100)   NOT NULL,
    pais             NVARCHAR(60)    NOT NULL DEFAULT 'Colombia',
    temperatura_c    NUMERIC(5,2)    NOT NULL,
    fecha_hora       DATETIMEOFFSET(0) NOT NULL,
    cobertura_nubes  NVARCHAR(10)    NOT NULL,
    indice_uv        NUMERIC(4,1)    NULL,        -- NULL válido de noche
    presion_atm      NUMERIC(7,2)    NULL,        -- hPa (ej: 1013.25)
    velocidad_viento NUMERIC(6,2)    NULL,        -- Nudos

    CONSTRAINT pk_meteorologia
        PRIMARY KEY (id),

    CONSTRAINT uq_localidad_hora                  -- Un registro por lugar + hora
        UNIQUE (localidad, fecha_hora),

    CONSTRAINT chk_cobertura
        CHECK (cobertura_nubes IN (N'Mínima', N'Parcial', N'Total')),

    CONSTRAINT chk_temp
        CHECK (temperatura_c BETWEEN -30 AND 60),

    CONSTRAINT chk_uv
        CHECK (indice_uv IS NULL OR indice_uv >= 0),

    CONSTRAINT chk_viento
        CHECK (velocidad_viento IS NULL OR velocidad_viento >= 0)
);

-- Documentación de columnas (equivalente a COMMENT ON en PostgreSQL)
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Registros meteorológicos horarios por localidad',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'meteorologia_horaria';

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Temperatura en grados Celsius',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'meteorologia_horaria',
    @level2type = N'COLUMN', @level2name = N'temperatura_c';

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Índice UV – NULL en horas nocturnas',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'meteorologia_horaria',
    @level2type = N'COLUMN', @level2name = N'indice_uv';
GO

-- Datos de prueba (9 registros: 5 localidades, 2 días)
-- DATETIMEOFFSET acepta el mismo literal ISO 8601 que TIMESTAMPTZ
INSERT INTO dbo.meteorologia_horaria
    (localidad, pais, temperatura_c, fecha_hora,
     cobertura_nubes, indice_uv, presion_atm, velocidad_viento)
VALUES
    (N'El Poblado', N'Colombia', 20.5, '2024-01-01 08:00:00 -05:00', N'Mínima',  4.2, 1012.3, 5.1),
    (N'El Poblado', N'Colombia', 22.1, '2024-01-01 09:00:00 -05:00', N'Parcial', 5.8, 1011.9, 6.3),
    (N'El Poblado', N'Colombia', 23.8, '2024-01-01 10:00:00 -05:00', N'Total',   3.1, 1011.0, 7.0),
    (N'Envigado',   N'Colombia', 21.0, '2024-01-01 08:00:00 -05:00', N'Mínima',  4.0, 1013.1, 4.8),
    (N'Sabaneta',   N'Colombia', 19.3, '2024-01-01 08:00:00 -05:00', N'Parcial', 3.9, 1013.5, 4.2),
    (N'Bello',      N'Colombia', 24.6, '2024-01-01 08:00:00 -05:00', N'Total',   5.0, 1010.8, 8.1),
    (N'El Centro',  N'Colombia', 18.2, '2024-01-01 08:00:00 -05:00', N'Mínima',  3.5, 1014.2, 3.6),
    (N'El Poblado', N'Colombia', 17.9, '2024-01-02 08:00:00 -05:00', N'Mínima',  4.1, 1012.8, 5.5),
    (N'Envigado',   N'Colombia', 20.4, '2024-01-02 08:00:00 -05:00', N'Parcial', 4.3, 1012.2, 4.9);
GO


-- =============================================================
-- PARTE 2 – TRES MEJORAS PARA MILLONES DE REGISTROS
-- =============================================================

-- ── MEJORA 1: ÍNDICES ────────────────────────────────────────
/*
  Sin índices: full-scan O(n) sobre millones de filas.
  Con índices B-tree: O(log n).

  · idx_met_fecha_hora   → filtros por rango de fecha
  · idx_met_localidad    → filtros por localidad
  · idx_met_loc_fecha    → consulta combinada más frecuente:
                           "registros de localidad X entre fecha A y B"
                           Este índice cubre ambas condiciones en uno.
*/
CREATE INDEX idx_met_fecha_hora
    ON dbo.meteorologia_horaria (fecha_hora DESC);

CREATE INDEX idx_met_localidad
    ON dbo.meteorologia_horaria (localidad);

CREATE INDEX idx_met_loc_fecha
    ON dbo.meteorologia_horaria (localidad, fecha_hora DESC);
GO


-- ── MEJORA 2: PARTICIONAMIENTO POR RANGO MENSUAL ─────────────

IF OBJECT_ID('dbo.meteorologia_horaria_part', 'U') IS NOT NULL
    DROP TABLE dbo.meteorologia_horaria_part;

IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'ps_meteorologia_mensual')
    DROP PARTITION SCHEME ps_meteorologia_mensual;

IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'pf_meteorologia_mensual')
    DROP PARTITION FUNCTION pf_meteorologia_mensual;

-- Función de partición: rangos mensuales de enero a marzo 2024
CREATE PARTITION FUNCTION pf_meteorologia_mensual (DATETIMEOFFSET(0))
AS RANGE RIGHT FOR VALUES (
    '2024-01-01 00:00:00 +00:00',   -- partición 1: antes de enero 2024
    '2024-02-01 00:00:00 +00:00',   -- partición 2: enero 2024
    '2024-03-01 00:00:00 +00:00'    -- partición 3: febrero 2024
);                                   -- partición 4: desde marzo 2024

-- Esquema de partición: todas al filegroup PRIMARY (Azure SQL)
CREATE PARTITION SCHEME ps_meteorologia_mensual
AS PARTITION pf_meteorologia_mensual
ALL TO ([PRIMARY]);

-- Tabla particionada
CREATE TABLE dbo.meteorologia_horaria_part (
    id               INT               NOT NULL IDENTITY(1,1),
    localidad        NVARCHAR(100)     NOT NULL,
    pais             NVARCHAR(60)      NOT NULL DEFAULT N'Colombia',
    temperatura_c    NUMERIC(5,2)      NOT NULL,
    fecha_hora       DATETIMEOFFSET(0) NOT NULL,
    cobertura_nubes  NVARCHAR(10)      NOT NULL,
    indice_uv        NUMERIC(4,1)      NULL,
    presion_atm      NUMERIC(7,2)      NULL,
    velocidad_viento NUMERIC(6,2)      NULL,
    CONSTRAINT pk_met_part  PRIMARY KEY (id, fecha_hora),
    CONSTRAINT chk_cob_part CHECK (cobertura_nubes IN (N'Mínima',N'Parcial',N'Total'))
) ON ps_meteorologia_mensual (fecha_hora);
GO


-- ── MEJORA 3: VISTA INDIZADA (= MATERIALIZED VIEW) ───────────

IF OBJECT_ID('dbo.vw_promedios_diarios', 'V') IS NOT NULL
    DROP VIEW dbo.vw_promedios_diarios;
GO

CREATE VIEW dbo.vw_promedios_diarios
WITH SCHEMABINDING
AS
SELECT
    localidad,
    -- Convertir DATETIMEOFFSET a fecha local Colombia (-05:00)
    CAST(SWITCHOFFSET(fecha_hora, '-05:00') AS DATE)         AS fecha,
    -- SUM / COUNT_BIG obligatorios para INDEX en vistas con GROUP BY
    SUM(temperatura_c)                                       AS suma_temp_c,
    SUM(ISNULL(velocidad_viento, 0))                         AS suma_viento,
    COUNT_BIG(*)                                             AS lecturas
FROM dbo.meteorologia_horaria
GROUP BY
    localidad,
    CAST(SWITCHOFFSET(fecha_hora, '-05:00') AS DATE);
GO

-- Índice clustered que materializa la vista
CREATE UNIQUE CLUSTERED INDEX idx_vw_promedios_diarios
    ON dbo.vw_promedios_diarios (localidad, fecha);
GO

-- Consultar la vista con promedios calculados:
-- SELECT localidad, fecha,
--        ROUND(suma_temp_c * 1.0 / lecturas, 2) AS temp_prom_c,
--        ROUND(suma_viento * 1.0 / lecturas, 2) AS viento_prom_nudos,
--        lecturas
-- FROM dbo.vw_promedios_diarios
-- ORDER BY localidad, fecha;


-- =============================================================
-- PARTE 3 – TABLA DIARIA EN FAHRENHEIT + MIGRACIÓN
-- =============================================================
/*
  DIFERENCIAS VS TABLA HORARIA
  ──────────────────────────────────────────────────────────────
  · fecha DATE         → granularidad diaria
  · temperatura_f      → promedio diario en °F, no °C
  · temp_max_f / min   → rango del día en Fahrenheit
  · indice_uv          → máximo del día

  FÓRMULA: °F = °C × (9.0/5.0) + 32
  Ejemplo: 22.13°C → 71.83°F
*/

IF OBJECT_ID('dbo.meteorologia_diaria_f', 'U') IS NOT NULL
    DROP TABLE dbo.meteorologia_diaria_f;

CREATE TABLE dbo.meteorologia_diaria_f (
    id               INT          NOT NULL IDENTITY(1,1),
    localidad        NVARCHAR(100) NOT NULL,
    pais             NVARCHAR(60)  NOT NULL DEFAULT N'Colombia',
    fecha            DATE          NOT NULL,
    temperatura_f    NUMERIC(6,2)  NOT NULL,
    temp_max_f       NUMERIC(6,2)  NULL,
    temp_min_f       NUMERIC(6,2)  NULL,
    cobertura_nubes  NVARCHAR(10)  NULL,
    indice_uv        NUMERIC(4,1)  NULL,
    presion_atm      NUMERIC(7,2)  NULL,
    velocidad_viento NUMERIC(6,2)  NULL,

    CONSTRAINT pk_diaria
        PRIMARY KEY (id),

    CONSTRAINT uq_diaria_loc_fecha
        UNIQUE (localidad, fecha),

    CONSTRAINT chk_cob_diaria
        CHECK (cobertura_nubes IN (N'Mínima',N'Parcial',N'Total')
               OR cobertura_nubes IS NULL)
);
GO

-- Migración con CTE en T-SQL
-- REGLA T-SQL: el WITH (CTE) debe ir ANTES del INSERT INTO, no después.
-- SWITCHOFFSET convierte DATETIMEOFFSET al offset de Colombia (-05:00)
-- CAST(...AS DATE) extrae la fecha local
WITH base AS (
    -- Paso 1: calcular fecha local Colombia para cada registro
    SELECT
        localidad,
        pais,
        temperatura_c,
        cobertura_nubes,
        indice_uv,
        presion_atm,
        velocidad_viento,
        fecha_hora,
        CAST(SWITCHOFFSET(fecha_hora, '-05:00') AS DATE) AS fecha
    FROM dbo.meteorologia_horaria
),
agg AS (
    -- Paso 2: agregar por localidad + fecha y convertir a Fahrenheit
    -- °F = °C × (9.0/5.0) + 32
    SELECT
        localidad,
        pais,
        fecha,
        ROUND(AVG(temperatura_c) * 9.0/5.0 + 32, 2)  AS temperatura_f,
        ROUND(MAX(temperatura_c) * 9.0/5.0 + 32, 2)  AS temp_max_f,
        ROUND(MIN(temperatura_c) * 9.0/5.0 + 32, 2)  AS temp_min_f,
        MAX(indice_uv)                                AS indice_uv,
        ROUND(AVG(presion_atm), 2)                    AS presion_atm,
        ROUND(AVG(velocidad_viento), 2)               AS velocidad_viento
    FROM base
    GROUP BY localidad, pais, fecha
),
primera_cob AS (
    -- Paso 3: primera cobertura del día por localidad
    -- ROW_NUMBER reemplaza DISTINCT ON de PostgreSQL
    SELECT localidad, fecha, cobertura_nubes
    FROM (
        SELECT
            localidad, fecha, cobertura_nubes,
            ROW_NUMBER() OVER (
                PARTITION BY localidad, fecha
                ORDER BY     fecha_hora
            ) AS rn
        FROM base
    ) x
    WHERE rn = 1
)
INSERT INTO dbo.meteorologia_diaria_f
    (localidad, pais, fecha, temperatura_f, temp_max_f, temp_min_f,
     cobertura_nubes, indice_uv, presion_atm, velocidad_viento)
SELECT
    a.localidad, a.pais, a.fecha,
    a.temperatura_f, a.temp_max_f, a.temp_min_f,
    pc.cobertura_nubes,
    a.indice_uv, a.presion_atm, a.velocidad_viento
FROM agg a
JOIN primera_cob pc
    ON  a.localidad = pc.localidad
    AND a.fecha     = pc.fecha;
GO


-- =============================================================
-- PARTE 4 – COLUMNA DELTA DE TEMPERATURA (RETROACTIVA)
-- =============================================================
/*
  LAG(col) OVER (PARTITION BY localidad ORDER BY tiempo)
  devuelve el valor del registro anterior de la misma localidad.

  El primer registro de cada localidad queda delta = NULL.
*/

-- ── 4a. Tabla horaria: Δ vs hora anterior ───────────────────
IF COL_LENGTH('dbo.meteorologia_horaria', 'delta_temp_c') IS NULL
    ALTER TABLE dbo.meteorologia_horaria
        ADD delta_temp_c NUMERIC(6,2) NULL;
GO

UPDATE mh
SET mh.delta_temp_c = sub.delta
FROM dbo.meteorologia_horaria AS mh
JOIN (
    SELECT
        id,
        temperatura_c
            - LAG(temperatura_c) OVER (
                PARTITION BY localidad
                ORDER BY     fecha_hora
              ) AS delta
    FROM dbo.meteorologia_horaria
) AS sub ON mh.id = sub.id;
GO

-- ── 4b. Tabla diaria: Δ vs día anterior ─────────────────────
IF COL_LENGTH('dbo.meteorologia_diaria_f', 'delta_temp_f') IS NULL
    ALTER TABLE dbo.meteorologia_diaria_f
        ADD delta_temp_f NUMERIC(6,2) NULL;
GO

UPDATE mdf
SET mdf.delta_temp_f = sub.delta
FROM dbo.meteorologia_diaria_f AS mdf
JOIN (
    SELECT
        id,
        temperatura_f
            - LAG(temperatura_f) OVER (
                PARTITION BY localidad
                ORDER BY     fecha
              ) AS delta
    FROM dbo.meteorologia_diaria_f
) AS sub ON mdf.id = sub.id;
GO


-- =============================================================
-- VERIFICACIÓN DE RESULTADOS
-- =============================================================

-- Ver 1: tabla horaria completa con delta
--   Resultado esperado:
--   · El Poblado 08h→09h: Δ = +1.60°C
--   · El Poblado 09h→10h: Δ = +1.70°C
--   · El Poblado 01-ene→02-ene: Δ = -5.90°C
--   · Primer registro de cada localidad: Δ = NULL
SELECT
    localidad,
    fecha_hora,
    temperatura_c,
    delta_temp_c             AS [Δ°C vs hora anterior],
    cobertura_nubes,
    indice_uv,
    presion_atm,
    velocidad_viento
FROM dbo.meteorologia_horaria
ORDER BY localidad, fecha_hora;
GO

-- Ver 2: tabla diaria con delta y rango de temperatura en °F
--   Resultado esperado:
--   · El Poblado 01-ene: 71.84°F (promedio 20.5+22.1+23.8 = 22.13°C)
--   · El Poblado 02-ene: 64.22°F, Δ = -7.62°F
--   · Primer registro de cada localidad: Δ = NULL
SELECT
    localidad,
    fecha,
    temperatura_f            AS [°F promedio],
    temp_max_f               AS [°F máx del día],
    temp_min_f               AS [°F mín del día],
    delta_temp_f             AS [Δ°F vs día anterior],
    cobertura_nubes,
    indice_uv,
    presion_atm,
    velocidad_viento
FROM dbo.meteorologia_diaria_f
ORDER BY localidad, fecha;
GO

-- Ver 3: vista indizada de promedios diarios
SELECT
    localidad,
    fecha,
    ROUND(CAST(suma_temp_c AS FLOAT) / lecturas, 2)  AS temp_prom_c,
    ROUND(CAST(suma_viento AS FLOAT) / lecturas, 2)  AS viento_prom_nudos,
    lecturas
FROM dbo.vw_promedios_diarios
ORDER BY localidad, fecha;
GO