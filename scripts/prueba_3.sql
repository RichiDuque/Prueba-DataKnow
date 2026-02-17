-- ============================================================
--  PRUEBA SQL – Azure SQL Database (T-SQL)
--  Datos meteorológicos horarios y diarios
-- ============================================================


-- ============================================================
-- PARTE 1 – TABLA METEOROLÓGICA HORARIA
-- ============================================================
-- UNIQUE (localidad, fecha_hora) garantiza un registro por lugar/hora
-- DATETIMEOFFSET guarda la zona horaria en el valor (Colombia -05:00)
-- NUMERIC evita errores de punto flotante en temperaturas
-- indice_uv permite NULL (no hay radiación solar de noche)

CREATE TABLE meteorologia_horaria (
    id               INT               NOT NULL IDENTITY(1,1) PRIMARY KEY,
    localidad        NVARCHAR(100)     NOT NULL,
    pais             NVARCHAR(60)      NOT NULL DEFAULT N'Colombia',
    temperatura_c    NUMERIC(5,2)      NOT NULL,
    fecha_hora       DATETIMEOFFSET(0) NOT NULL,
    cobertura_nubes  NVARCHAR(10)      NOT NULL CHECK (cobertura_nubes IN (N'Mínima', N'Parcial', N'Total')),
    indice_uv        NUMERIC(4,1)      NULL CHECK (indice_uv IS NULL OR indice_uv >= 0),
    presion_atm      NUMERIC(7,2)      NULL,   -- hPa
    velocidad_viento NUMERIC(6,2)      NULL,   -- Nudos
    CONSTRAINT uq_localidad_hora UNIQUE (localidad, fecha_hora)
);

-- Datos de ejemplo: 5 localidades, 2 días
INSERT INTO meteorologia_horaria (localidad, temperatura_c, fecha_hora, cobertura_nubes, indice_uv, presion_atm, velocidad_viento)
VALUES
    (N'El Poblado', 20.5, '2024-01-01 08:00:00 -05:00', N'Mínima',  4.2, 1012.3, 5.1),
    (N'El Poblado', 22.1, '2024-01-01 09:00:00 -05:00', N'Parcial', 5.8, 1011.9, 6.3),
    (N'El Poblado', 23.8, '2024-01-01 10:00:00 -05:00', N'Total',   3.1, 1011.0, 7.0),
    (N'Envigado',   21.0, '2024-01-01 08:00:00 -05:00', N'Mínima',  4.0, 1013.1, 4.8),
    (N'Sabaneta',   19.3, '2024-01-01 08:00:00 -05:00', N'Parcial', 3.9, 1013.5, 4.2),
    (N'Bello',      24.6, '2024-01-01 08:00:00 -05:00', N'Total',   5.0, 1010.8, 8.1),
    (N'El Centro',  18.2, '2024-01-01 08:00:00 -05:00', N'Mínima',  3.5, 1014.2, 3.6),
    (N'El Poblado', 17.9, '2024-01-02 08:00:00 -05:00', N'Mínima',  4.1, 1012.8, 5.5),
    (N'Envigado',   20.4, '2024-01-02 08:00:00 -05:00', N'Parcial', 4.3, 1012.2, 4.9);


-- ============================================================
-- PARTE 2 – TRES MEJORAS PARA MILLONES DE REGISTROS
-- ============================================================

-- MEJORA 1: ÍNDICES
-- Aceleran filtros por fecha y por localidad de O(n) a O(log n).
-- El índice compuesto (localidad, fecha_hora) cubre la consulta más
-- frecuente: "registros de localidad X en rango de fechas".
CREATE INDEX idx_met_fecha_hora ON meteorologia_horaria (fecha_hora DESC);
CREATE INDEX idx_met_localidad  ON meteorologia_horaria (localidad);
CREATE INDEX idx_met_loc_fecha  ON meteorologia_horaria (localidad, fecha_hora DESC);


-- MEJORA 2: PARTICIONAMIENTO POR MES
-- Divide la tabla en segmentos mensuales. Las consultas por rango de
-- fechas solo acceden a las particiones relevantes (partition pruning),
-- reduciendo drasticamente el I/O.
CREATE PARTITION FUNCTION pf_met_mensual (DATETIMEOFFSET(0))
AS RANGE RIGHT FOR VALUES (
    '2024-01-01 00:00:00 +00:00',
    '2024-02-01 00:00:00 +00:00',
    '2024-03-01 00:00:00 +00:00'
);

CREATE PARTITION SCHEME ps_met_mensual
AS PARTITION pf_met_mensual ALL TO ([PRIMARY]);

-- Nota: para aplicar particionamiento a la tabla existente se recrea
-- con la cláusula ON ps_met_mensual (fecha_hora). En producción se
-- haría mediante ALTER TABLE ... SWITCH o recreando la tabla.


-- MEJORA 3: VISTA INDIZADA (Materialized View)
-- Pre-calcula promedios diarios por localidad y los almacena físicamente.
-- Las consultas de resumen leen el índice en lugar de agregar millones de filas.
GO
CREATE VIEW vw_promedios_diarios WITH SCHEMABINDING AS
SELECT
    localidad,
    CAST(SWITCHOFFSET(fecha_hora, '-05:00') AS DATE) AS fecha,
    SUM(temperatura_c)          AS suma_temp_c,
    SUM(ISNULL(velocidad_viento, 0)) AS suma_viento,
    COUNT_BIG(*)                AS lecturas
FROM dbo.meteorologia_horaria
GROUP BY localidad, CAST(SWITCHOFFSET(fecha_hora, '-05:00') AS DATE);
GO

CREATE UNIQUE CLUSTERED INDEX idx_vw_promedios ON vw_promedios_diarios (localidad, fecha);
GO

-- Uso de la vista: AVG = SUM / COUNT_BIG (requerido por la vista indizada)
-- SELECT localidad, fecha,
--        ROUND(CAST(suma_temp_c AS FLOAT) / lecturas, 2) AS temp_prom_c
-- FROM vw_promedios_diarios ORDER BY localidad, fecha;


-- ============================================================
-- PARTE 3 – TABLA DIARIA EN FAHRENHEIT + MIGRACIÓN
-- ============================================================
-- Granularidad diaria, temperatura en °F (°C × 9/5 + 32)
-- Incluye máximo y mínimo del día

CREATE TABLE meteorologia_diaria_f (
    id               INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    localidad        NVARCHAR(100) NOT NULL,
    pais             NVARCHAR(60)  NOT NULL DEFAULT N'Colombia',
    fecha            DATE          NOT NULL,
    temperatura_f    NUMERIC(6,2)  NOT NULL,   -- promedio diario en °F
    temp_max_f       NUMERIC(6,2)  NULL,
    temp_min_f       NUMERIC(6,2)  NULL,
    cobertura_nubes  NVARCHAR(10)  NULL CHECK (cobertura_nubes IN (N'Mínima', N'Parcial', N'Total') OR cobertura_nubes IS NULL),
    indice_uv        NUMERIC(4,1)  NULL,
    presion_atm      NUMERIC(7,2)  NULL,
    velocidad_viento NUMERIC(6,2)  NULL,
    CONSTRAINT uq_diaria_loc_fecha UNIQUE (localidad, fecha)
);

-- Migración desde la tabla horaria con CTE
-- CTE "base"       → extrae la fecha local Colombia (SWITCHOFFSET a -05:00)
-- CTE "agg"        → agrega por día y convierte °C → °F
-- CTE "primera_cob"→ toma la cobertura del primer registro del día
--                    (ROW_NUMBER reemplaza DISTINCT ON de PostgreSQL)
;WITH base AS (
    SELECT *, CAST(SWITCHOFFSET(fecha_hora, '-05:00') AS DATE) AS fecha
    FROM meteorologia_horaria
),
agg AS (
    SELECT
        localidad, pais, fecha,
        ROUND(AVG(temperatura_c) * 9.0/5.0 + 32, 2) AS temperatura_f,
        ROUND(MAX(temperatura_c) * 9.0/5.0 + 32, 2) AS temp_max_f,
        ROUND(MIN(temperatura_c) * 9.0/5.0 + 32, 2) AS temp_min_f,
        MAX(indice_uv)                               AS indice_uv,
        ROUND(AVG(presion_atm), 2)                   AS presion_atm,
        ROUND(AVG(velocidad_viento), 2)              AS velocidad_viento
    FROM base
    GROUP BY localidad, pais, fecha
),
primera_cob AS (
    SELECT localidad, fecha, cobertura_nubes
    FROM (
        SELECT localidad, fecha, cobertura_nubes,
               ROW_NUMBER() OVER (PARTITION BY localidad, fecha ORDER BY fecha_hora) AS rn
        FROM base
    ) x WHERE rn = 1
)
INSERT INTO meteorologia_diaria_f
    (localidad, pais, fecha, temperatura_f, temp_max_f, temp_min_f,
     cobertura_nubes, indice_uv, presion_atm, velocidad_viento)
SELECT a.localidad, a.pais, a.fecha,
       a.temperatura_f, a.temp_max_f, a.temp_min_f,
       pc.cobertura_nubes, a.indice_uv, a.presion_atm, a.velocidad_viento
FROM agg a
JOIN primera_cob pc ON a.localidad = pc.localidad AND a.fecha = pc.fecha;


-- ============================================================
-- PARTE 4 – COLUMNA DELTA DE TEMPERATURA (RETROACTIVA)
-- ============================================================
-- LAG() devuelve el valor del registro anterior dentro de la misma
-- localidad. El primer registro de cada localidad queda delta = NULL.

-- 4a. Horario: diferencia vs hora anterior (en °C)
ALTER TABLE meteorologia_horaria ADD delta_temp_c NUMERIC(6,2) NULL;
GO

UPDATE h SET h.delta_temp_c = sub.delta
FROM meteorologia_horaria h
JOIN (
    SELECT id,
           temperatura_c - LAG(temperatura_c) OVER (PARTITION BY localidad ORDER BY fecha_hora) AS delta
    FROM meteorologia_horaria
) sub ON h.id = sub.id;


-- 4b. Diario: diferencia vs día anterior (en °F)
ALTER TABLE meteorologia_diaria_f ADD delta_temp_f NUMERIC(6,2) NULL;
GO

UPDATE d SET d.delta_temp_f = sub.delta
FROM meteorologia_diaria_f d
JOIN (
    SELECT id,
           temperatura_f - LAG(temperatura_f) OVER (PARTITION BY localidad ORDER BY fecha) AS delta
    FROM meteorologia_diaria_f
) sub ON d.id = sub.id;


-- ============================================================
-- VERIFICACIÓN
-- ============================================================

-- Tabla horaria: delta esperado El Poblado 08→09h: +1.60°C, 09→10h: +1.70°C
SELECT localidad, fecha_hora, temperatura_c,
       delta_temp_c AS [Delta °C], cobertura_nubes, indice_uv
FROM meteorologia_horaria
ORDER BY localidad, fecha_hora;

-- Tabla diaria: El Poblado 01-ene 71.84°F, 02-ene 64.22°F (delta -7.62°F)
SELECT localidad, fecha,
       temperatura_f AS [°F prom], temp_max_f, temp_min_f,
       delta_temp_f  AS [Delta °F], cobertura_nubes
FROM meteorologia_diaria_f
ORDER BY localidad, fecha;