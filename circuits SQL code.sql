SELECT *
FROM circuits
;
--(Q1)Which 10 circuits are at the highest altitude, and how high are they?
SELECT name, altitude
FROM circuits
ORDER BY altitude DESC
LIMIT 10
;

--(2)How many circuits are in each country, and which countries have more than 3?
SELECT DISTINCT country, COUNT(name) AS circuits
FROM circuits
GROUP BY country
HAVING COUNT(name)> 3
ORDER BY circuits DESC
;
--(3)Which circuits have "Grand Prix" in their name, and how many are there?
SELECT name
FROM circuits
WHERE name ILIKE '%Grand Prix%'
;
--(4)How many circuits are in the northern hemisphere versus the southern, 
--and east versus west? Use latitude and longitude to classify them

SELECT CASE WHEN latitude > 0 THEN 'Northern'
			WHEN latitude < 0 THEN 'Southern'
			ELSE 'Equator'
		END AS lat_hemisphere,
		COUNT(*) AS circuits
FROM circuits
GROUP BY 1
ORDER BY circuits DESC
;

SELECT CASE WHEN longitude > 0 THEN 'eastern'
			WHEN longitude < 0 THEN 'western'
			ELSE 'Prime Meridian'
		END AS long_hemisphere,
		COUNT (*) AS circuits
FROM circuits
GROUP BY 1
ORDER BY circuits DESC
;
--(5)For each country, what are the average, minimum, 
--and maximum altitude of its circuits? Show only countries with at least 2 circuits

SELECT  country,
		COUNT(*) AS circuits,
		ROUND(AVG(altitude), 1) AS avg_altitude,
		MIN(altitude) AS min_altitude,
		MAX(altitude) AS max_altitude
FROM circuits
GROUP BY country 
HAVING COUNT(*) >= 2
ORDER BY avg_altitude DESC
;
--(6)Rank circuits by altitude within each country, 
--and show only the highest circuit in each country.
WITH cleaned AS(
	SELECT name,
	CASE WHEN country = 'United States' THEN 'USA'
	ELSE country
END AS country,
	altitude
FROM circuits
),
ranked AS(
	SELECT name, 
	country, 
	altitude,
	RANK()OVER(PARTITION BY country ORDER BY altitude DESC) AS altitude_rank
FROM cleaned
)
SELECT country, name ,altitude
FROM ranked
WHERE altitude_rank = 1
ORDER BY altitude DESC
;
--(7)Which circuits are below sea level (negative altitude) or above 1,000 meters? 
--Label each as "Below sea level," "Low," "Mid," or "High."

 SELECT name,
 		altitude,
		 CASE 
 				WHEN altitude < 0 THEN 'Below sea level'
				WHEN altitude < 500 THEN 'Low'
				WHEN altitude < 1000 THEN 'Mid'
				ELSE 'High'
		END AS altitude_level
 FROM circuits
 WHERE altitude < 0 OR altitude > 1000
 ORDER BY altitude DESC
 ;
-- how many circuits are in each category
SELECT CASE 
 				WHEN altitude < 0 THEN 'Below sea level'
				WHEN altitude < 500 THEN 'Low'
				WHEN altitude < 1000 THEN 'Mid'
				ELSE 'High'
		END AS altitude_level,
		COUNT(*) AS circuits
FROM circuits
GROUP BY 1
ORDER BY MIN(altitude)
;

--(8)Split all circuits into four altitude quartiles. What is the altitude range of each quartile, 
--and how many circuits does it hold? (CTE, NTILE(4), MIN/MAX/COUNT per bucket)

SELECT  MIN(altitude), MAX(altitude), COUNT(altitude)
FROM circuits
;

WITH quartiles AS (
	SELECT  name,
			altitude,
			NTILE(4)OVER(ORDER BY altitude ASC) AS quartile
	FROM circuits
)
SELECT  quartile,
		COUNT(*) AS circuits,
		MIN(altitude) AS min_altitude,
		MAX(altitude) AS max_altitude
FROM quartiles
GROUP BY quartile
ORDER BY quartile
;

--(9)Extract the Wikipedia page name from each circuit's url (the text after the last /), and 
--find circuits whose page name differs from their circuit_ref.
--(SPLIT_PART or SUBSTRING with POSITION, REPLACE, string comparison)		

WITH pages AS (
    SELECT name,
           circuit_ref,
           SPLIT_PART(SPLIT_PART(url, '#', 1), '/', -1) AS page_name
    FROM circuits
)
SELECT name, circuit_ref, page_name
FROM pages
WHERE POSITION(LOWER(REPLACE(circuit_ref, '_' , ''))
				IN LOWER(REPLACE(page_name, '_', ''))) = 0
ORDER BY name;

--This version drops the list to 15 circuits, which are the genuinely interesting mismatches, 
--like albert_park / Melbourne_Grand_Prix_Circuit and imola / Autodromo_Enzo_e_Dino_Ferrari.


--(10)Which two circuits are closest to each other geographically? Compute the distance between 
--every pair using the haversine formula on latitude and longitude, and list the 5 closest pairs. 
--(self join with a.circuit_id < b.circuit_id to avoid duplicates, math functions like RADIANS, SIN, COS, ASIN, SQRT)

--The haversine formula gives the distance along the Earth's surface between two points:
--Convert latitude and longitude differences to radians.
--a = sin²(Δlat / 2) + cos(lat1) × cos(lat2) × sin²(Δlon / 2)
--distance = 2 × R × asin(√a), where R is the Earth's radius, about 6,371 km.

SELECT  a.name AS circuit_a,
		b.name AS circuit_b
FROM circuits a
JOIN circuits b ON a.circuit_id < b.circuit_id
;
--A self join combines the table with itself. Joining on a.circuit_id < b.circuit_id does two 
--jobs: it stops a circuit from pairing with itself, and it keeps each pair only once
-- Computing the distance

WITH pairs AS(
	SELECT a.name AS circuit_a,
		   b.name AS circuit_b,
		   RADIANS(a.latitude) AS lat1,
		   RADIANS(b.latitude) AS lat2,
		   RADIANS(b.latitude - a.latitude) AS dlat,
		   RADIANS(b.longitude - a.longitude) AS dlon
	FROM circuits a
	JOIN circuits b ON a.circuit_id < b.circuit_id
)
SELECT circuit_a,
	   circuit_b,
	   ROUND((2*6371 *ASIN(SQRT(LEAST(1,
	   POWER(SIN(dlat/2), 2)
	   +COS(lat1) * COS(lat2) * POWER(SIN(dlon / 2),2)
	   ))))::numeric, 2) AS distance_km
FROM pairs
ORDER BY distance_km
LIMIT 5
;

--POWER(x, 2) squares the sine values.
--LEAST(1, ...) protects against floating-point rounding. ASIN fails if its input is even slightly above 1, which can happen for circuits at nearly the same spot.
--::numeric is needed because PostgreSQL's two-argument ROUND doesn't accept double precision. Without the cast, you get an error about a missing function.
--ORDER BY distance_km sorts ascending, so the closest pairs come first.