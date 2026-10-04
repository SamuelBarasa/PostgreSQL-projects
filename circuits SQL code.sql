--1. Create the table
CREATE TABLE circuits (
    circuit_id   integer PRIMARY KEY,
    circuit_ref  varchar(90),
    name         varchar(90),
    location     varchar(90),
    country      varchar(90),
    latitude     float,
    longitude    float,
    altitude     integer,
    url          text
)
;

--2. Load the CSV

--use the Import/Export tool in pgAdmin or DBeaver with format `csv`, header on, and a comma delimiter. The column **order** in the file must match the table.

--3. Verify the load
SELECT COUNT(*) FROM circuits;    
SELECT * FROM circuits LIMIT 5;

--Analysis

--Q1: Which circuits sit at the highest altitude?
SELECT name, altitude
FROM circuits
ORDER BY altitude DESC NULLS LAST
LIMIT 10;

--Q2: Which countries host the most circuits?

SELECT country, COUNT(*) AS circuits
FROM circuits
GROUP BY country
HAVING COUNT(*) > 3
ORDER BY circuits DESC;

--Cleaning the USA label: one circuit is labeled `United States` rather than `USA`.

SELECT CASE WHEN country = 'United States' THEN 'USA' ELSE country END AS country,
       COUNT(*) AS circuits
FROM circuits
GROUP BY 1
HAVING COUNT(*) > 3
ORDER BY circuits DESC;

--Q3: Which circuits have "Grand Prix" in their name?
-- The list
SELECT name
FROM circuits
WHERE name LIKE '%Grand Prix%'
ORDER BY name;

-- The count
SELECT COUNT(*) AS grand_prix_circuits
FROM circuits
WHERE name LIKE '%Grand Prix%';

-- Both in one result
SELECT name,
       COUNT(*) OVER () AS total_matches
FROM circuits
WHERE name LIKE '%Grand Prix%';

--Q4: How are circuits split across hemispheres?

SELECT CASE WHEN latitude  > 0 THEN 'North' ELSE 'South' END AS lat_side,
       CASE WHEN longitude > 0 THEN 'East'  ELSE 'West'  END AS long_side,
       COUNT(*) AS circuits
FROM circuits
GROUP BY 1, 2
;
-- Q5: What is the altitude profile of each country's circuits?

SELECT country,
       COUNT(*)                AS circuits,
       ROUND(AVG(altitude), 1) AS avg_altitude,
       MIN(altitude)           AS min_altitude,
       MAX(altitude)           AS max_altitude
FROM circuits
GROUP BY country
HAVING COUNT(*) >= 2
ORDER BY avg_altitude DESC;

--Q6: Which circuits are below sea level or very high?

-- Label every circuit and see the distribution
SELECT CASE WHEN altitude < 0    THEN 'Below sea level'
            WHEN altitude < 500  THEN 'Low'
            WHEN altitude < 1000 THEN 'Mid'
            ELSE 'High'
       END AS altitude_level,
       COUNT(*) AS circuits
FROM circuits
GROUP BY 1
ORDER BY MIN(altitude);

-- Show only the extremes
SELECT name,
       altitude,
       CASE WHEN altitude < 0    THEN 'Below sea level'
            WHEN altitude < 500  THEN 'Low'
            WHEN altitude < 1000 THEN 'Mid'
            ELSE 'High'
       END AS altitude_level
FROM circuits
WHERE altitude < 0 OR altitude > 1000

--Q7: What is the highest circuit in each country?

WITH cleaned AS (
    SELECT name,
           CASE WHEN country = 'United States' THEN 'USA' ELSE country END AS country,
           altitude
    FROM circuits
),
ranked AS (
    SELECT name,
           country,
           altitude,
           RANK() OVER (PARTITION BY country ORDER BY altitude DESC) AS altitude_rank
    FROM cleaned
)
SELECT country, name, altitude
FROM ranked
WHERE altitude_rank = 1
ORDER BY altitude DESC;

--Q8: How do altitude quartiles break down?

WITH quartiles AS (
    SELECT name,
           altitude,
           NTILE(4) OVER (ORDER BY altitude) AS quartile
    FROM circuits
)
SELECT quartile,
       COUNT(*)      AS circuits,
       MIN(altitude) AS min_altitude,
       MAX(altitude) AS max_altitude
FROM quartiles
GROUP BY quartile
ORDER BY quartile;

--Q9: Do Wikipedia page names match the circuit references?


SELECT circuit_ref,
       SPLIT_PART(SPLIT_PART(url, '#', 1), '/', -1) AS page_name
FROM circuits;

SELECT circuit_ref,
       SUBSTRING(url FROM POSITION('/wiki/' IN url) + 6) AS page_name
FROM circuits;

WITH pages AS (
    SELECT name,
           circuit_ref,
           SPLIT_PART(SPLIT_PART(url, '#', 1), '/', -1) AS page_name
    FROM circuits
)
SELECT name, circuit_ref, page_name
FROM pages
WHERE LOWER(REPLACE(page_name, '_', '')) <> LOWER(REPLACE(circuit_ref, '_', ''))
ORDER BY name;

WITH pages AS (
    SELECT name,
           circuit_ref,
           SPLIT_PART(SPLIT_PART(url, '#', 1), '/', -1) AS page_name
    FROM circuits
)
SELECT name, circuit_ref, page_name
FROM pages
WHERE POSITION(LOWER(REPLACE(circuit_ref, '_', ''))
               IN LOWER(REPLACE(page_name, '_', ''))) = 0
ORDER BY name;


--Q10: Which circuits are closest to each other?

WITH pairs AS (
    SELECT a.name AS circuit_a,
           b.name AS circuit_b,
           RADIANS(a.latitude)                 AS lat1,
           RADIANS(b.latitude)                 AS lat2,
           RADIANS(b.latitude - a.latitude)    AS dlat,
           RADIANS(b.longitude - a.longitude)  AS dlon
    FROM circuits a
    JOIN circuits b ON a.circuit_id < b.circuit_id
)
SELECT circuit_a,
       circuit_b,
       ROUND((2 * 6371 * ASIN(SQRT(LEAST(1,
           POWER(SIN(dlat / 2), 2)
           + COS(lat1) * COS(lat2) * POWER(SIN(dlon / 2), 2)
       ))))::numeric, 2) AS distance_km
FROM pairs
ORDER BY distance_km
LIMIT 5;
