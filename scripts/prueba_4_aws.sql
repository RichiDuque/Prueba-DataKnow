-- 1. Tabla de Usuarios
CREATE TABLE users (
    userid     INTEGER NOT NULL,
    username   CHAR(8),
    firstname  VARCHAR(30),
    lastname   VARCHAR(30),
    city       VARCHAR(30),
    state      CHAR(2),
    email      VARCHAR(100),
    phone      CHAR(14),
    likesports  BOOLEAN,
    liketheatre BOOLEAN,
    likeconcerts BOOLEAN,
    likejazz    BOOLEAN,
    likeclassical BOOLEAN,
    likeopera   BOOLEAN,
    likerock    BOOLEAN,
    likevegas   BOOLEAN,
    likebroadway BOOLEAN,
    likemusicals BOOLEAN
);

-- Cargar Usuarios
COPY users FROM 's3://prueba-dk/tickitdb/allusers_pipe.txt'
IAM_ROLE 'arn:aws:iam::182399692063:role/service-role/AmazonRedshift-CommandsAccessRole-20260215T141004'
DELIMITER '|' REGION 'us-east-1';


-- 2. Tabla de Venues
CREATE TABLE venue (
    venueid    SMALLINT NOT NULL,
    venuename  VARCHAR(100),
    venuecity  VARCHAR(30),
    venuestate CHAR(2),
    venueseats INTEGER
);

-- Cargar Venues
COPY venue FROM 's3://prueba-dk/tickitdb/venue_pipe.txt'
IAM_ROLE 'arn:aws:iam::182399692063:role/service-role/AmazonRedshift-CommandsAccessRole-20260215T141004'
DELIMITER '|' REGION 'us-east-1';

-- 3. Tabla de Categorias
CREATE TABLE category (
    catid      SMALLINT NOT NULL,
    catgroup   VARCHAR(10),
    catname    VARCHAR(10),
    catdesc    VARCHAR(50)
);

-- Cargar Categorias
COPY category FROM 's3://prueba-dk/tickitdb/category_pipe.txt'
IAM_ROLE 'arn:aws:iam::182399692063:role/service-role/AmazonRedshift-CommandsAccessRole-20260215T141004'
DELIMITER '|' REGION 'us-east-1';

-- 4. Tabla de Fechas
CREATE TABLE date (
    dateid     SMALLINT NOT NULL,
    caldate    DATE NOT NULL,
    day        CHARACTER(3) NOT NULL,
    week       SMALLINT NOT NULL,
    month      CHARACTER(5) NOT NULL,
    qtr        CHARACTER(5) NOT NULL,
    year       SMALLINT NOT NULL,
    holiday    BOOLEAN DEFAULT('N')
);

-- Cargar Fechas
COPY date FROM 's3://prueba-dk/tickitdb/date2008_pipe.txt'
IAM_ROLE 'arn:aws:iam::182399692063:role/service-role/AmazonRedshift-CommandsAccessRole-20260215T141004'
DELIMITER '|' REGION 'us-east-1';

-- 5. Tabla de Eventos
CREATE TABLE event (
    eventid    INTEGER NOT NULL,
    venueid    SMALLINT NOT NULL,
    catid      SMALLINT NOT NULL,
    dateid     SMALLINT NOT NULL,
    eventname  VARCHAR(200),
    starttime  TIMESTAMP
);

-- Cargar Eventos
COPY event FROM 's3://prueba-dk/tickitdb/allevents_pipe.txt'
IAM_ROLE 'arn:aws:iam::182399692063:role/service-role/AmazonRedshift-CommandsAccessRole-20260215T141004'
DELIMITER '|' TIMEFORMAT 'auto' REGION 'us-east-1';

-- 6. Tabla de Listados
CREATE TABLE listing (
    listid     INTEGER NOT NULL,
    sellerid   INTEGER NOT NULL,
    eventid    INTEGER NOT NULL,
    dateid     SMALLINT NOT NULL,
    numtickets SMALLINT NOT NULL,
    priceperticket DECIMAL(8,2),
    totalprice DECIMAL(8,2),
    listtime   TIMESTAMP
);

-- Cargar Listados
COPY listing FROM 's3://prueba-dk/tickitdb/listings_pipe.txt'
IAM_ROLE 'arn:aws:iam::182399692063:role/service-role/AmazonRedshift-CommandsAccessRole-20260215T141004'
DELIMITER '|' REGION 'us-east-1';

-- 7. Tabla de Ventas
CREATE TABLE sales (
    salesid    INTEGER NOT NULL,
    listid     INTEGER NOT NULL,
    sellerid   INTEGER NOT NULL,
    buyerid    INTEGER NOT NULL,
    eventid    INTEGER NOT NULL,
    dateid     SMALLINT NOT NULL,
    qtysold    SMALLINT NOT NULL,
    pricepaid  DECIMAL(8,2),
    commission DECIMAL(8,2),
    saletime   TIMESTAMP
);

-- Cargar Ventas (delimitado por TAB)
COPY sales FROM 's3://prueba-dk/tickitdb/sales_tab.txt'
IAM_ROLE 'arn:aws:iam::182399692063:role/service-role/AmazonRedshift-CommandsAccessRole-20260215T141004'
DELIMITER '\t' TIMEFORMAT 'MM/DD/YYYY HH:MI:SS'
REGION 'us-east-1';

-- Verificar numero de registros en cada tabla
SELECT 'users'    AS tabla, COUNT(*) AS filas FROM users    UNION ALL
SELECT 'venue'    AS tabla, COUNT(*) AS filas FROM venue    UNION ALL
SELECT 'category' AS tabla, COUNT(*) AS filas FROM category UNION ALL
SELECT 'date'     AS tabla, COUNT(*) AS filas FROM date     UNION ALL
SELECT 'event'    AS tabla, COUNT(*) AS filas FROM event    UNION ALL
SELECT 'listing'  AS tabla, COUNT(*) AS filas FROM listing  UNION ALL
SELECT 'sales'    AS tabla, COUNT(*) AS filas FROM sales
ORDER BY tabla;

--PREGUNTAS

-- a. Usuarios que gustan del Jazz
SELECT COUNT(*) AS usuarios_jazz
FROM users
WHERE likejazz = TRUE;

-- b. Usuarios que gustan de Opera Y Rock al mismo tiempo
SELECT COUNT(*) AS usuarios_opera_y_rock
FROM users
WHERE likeopera = TRUE
  AND likerock = TRUE;

-- c. Promedio, Moda y Mediana del total de ventas (pricepaid)
-- PROMEDIO
SELECT
    ROUND(AVG(pricepaid), 2)         AS promedio_ventas,
    ROUND(STDDEV(pricepaid), 2)       AS desviacion_std,
    MIN(pricepaid)                    AS minimo,
    MAX(pricepaid)                    AS maximo,
    COUNT(*)                          AS total_ventas
FROM sales;


-- MEDIANA (PERCENTILE_CONT)
SELECT
    PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY pricepaid) AS mediana_ventas
FROM sales;


-- MODA (valor mas frecuente)
SELECT pricepaid AS moda_ventas, COUNT(*) AS frecuencia
FROM sales
GROUP BY pricepaid
ORDER BY frecuencia DESC
LIMIT 1;


-- Consulta unificada con las 3 metricas
SELECT
    ROUND(AVG(pricepaid), 2) AS promedio,
    (SELECT PERCENTILE_CONT(0.5)
         WITHIN GROUP (ORDER BY pricepaid) FROM sales) AS mediana,
    (SELECT pricepaid FROM sales
         GROUP BY pricepaid
         ORDER BY COUNT(*) DESC LIMIT 1) AS moda
FROM sales;

-- d. Promedio de ventas de compradores que gustan de Rock PERO NO de Jazz
SELECT
    ROUND(AVG(s.pricepaid), 2)  AS promedio_ventas,
    COUNT(s.salesid)             AS total_ventas,
    COUNT(DISTINCT s.buyerid)    AS total_compradores
FROM sales s
JOIN users u ON u.userid = s.buyerid
WHERE u.likerock  = TRUE
  AND u.likejazz  = FALSE;

--Punto 5
-- Crear tabla consolidada con toda la informacion requerida
CREATE TABLE ventas_consolidado AS
SELECT
    u.firstname           AS nombre_usuario,
    u.lastname            AS apellido_usuario,
    u.email               AS correo_usuario,
    e.eventname           AS nombre_evento,
    v.venuename           AS lugar_evento,
    d.caldate             AS fecha_evento,
    SUM(s.qtysold)        AS cantidad_vendida,
    SUM(s.pricepaid)      AS total_vendido
FROM sales s
JOIN users  u ON u.userid  = s.buyerid
JOIN event  e ON e.eventid = s.eventid
JOIN venue  v ON v.venueid = e.venueid
JOIN date   d ON d.dateid  = s.dateid
GROUP BY
    u.firstname, u.lastname, u.email,
    e.eventname, v.venuename, d.caldate
ORDER BY total_vendido DESC;


-- Verificar la tabla
SELECT COUNT(*) FROM ventas_consolidado;
SELECT * FROM ventas_consolidado LIMIT 10;

-- Exportar la tabla consolidada a S3 en formato CSV con encabezados
UNLOAD (
  'SELECT
      nombre_usuario,
      apellido_usuario,
      correo_usuario,
      nombre_evento,
      lugar_evento,
      fecha_evento,
      cantidad_vendida,
      total_vendido
   FROM ventas_consolidado'
)
TO 's3://prueba-dk/tickitdb/export/ventas_consolidado_'
IAM_ROLE 'arn:aws:iam::182399692063:role/service-role/AmazonRedshift-CommandsAccessRole-20260215T141004'
FORMAT AS CSV
HEADER
PARALLEL OFF
ALLOWOVERWRITE;