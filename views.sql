-- 1. Relatório de Receita
--     - Qual foi o total de receitas no ano de 1997?
CREATE VIEW total_receitas_1997 AS
WITH orders_1997 AS (
	SELECT order_id
	FROM orders
	WHERE EXTRACT(YEAR FROM order_date) = 1997
)
SELECT
	ROUND(CAST(SUM((od.unit_price * od.quantity)  * (1.0 - od.discount)) AS numeric), 2) AS receitas_totais
FROM
	order_details od
	INNER JOIN  orders_1997 o_97
	ON o_97.order_id = od.order_id
;

--     - Faça uma análise de crescimento mensal e o cálculo de YTD
CREATE VIEW analise_avanco_mensal_e_ytd AS
WITH receitas_mensais AS (
	SELECT
		EXTRACT(YEAR FROM o.order_date) AS ano,
		EXTRACT(MONTH FROM o.order_date) AS mes,
		ROUND(CAST(SUM((od.unit_price * od.quantity)  * (1.0 - od.discount)) AS numeric), 2) AS total
	FROM
		orders o
		INNER JOIN order_details od ON od.order_id = o.order_id
	GROUP BY
		EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)
	ORDER BY
		1, 2
)
SELECT
	ano,
	mes,
	total AS receita_mensal,
	ROUND(CAST(
	COALESCE(total - LAG(total) OVER (PARTITION BY ano ORDER BY mes), 0)
	AS NUMERIC), 2) AS delta_anterior,
	ROUND(CAST(
	100 * COALESCE(total - LAG(total) OVER (PARTITION BY ano ORDER BY mes), 0) / COALESCE(LAG(total) OVER (PARTITION BY ano ORDER BY mes), 1)
	AS NUMERIC), 2)  AS delta_anterior_pct,
	SUM(total) OVER (PARTITION BY ano ORDER BY mes) AS receita_YTD
FROM
	receitas_mensais
;


-- 2. Segmentação de clientes
--     - Qual é o valor total que cada cliente já pagou até agora?
CREATE VIEW total_por_cliente AS
SELECT
	cs.company_name AS cliente,
	ROUND(CAST(SUM((od.unit_price * od.quantity)  * (1.0 - od.discount)) AS numeric), 2) AS total
FROM
	customers cs
	INNER JOIN orders o ON o.customer_id = cs.customer_id
	INNER JOIN order_details od ON od.order_id = o.order_id
GROUP BY cs.company_name
ORDER BY 2 DESC
;
--     - Separe os clientes em 5 grupos de acordo com o valor pago por cliente
CREATE VIEW cliente_agrupados AS
WITH cliente_total AS (
	SELECT
		cs.company_name AS cliente,
		ROUND(CAST(SUM((od.unit_price * od.quantity)  * (1.0 - od.discount)) AS numeric), 2) AS total
	FROM
		customers cs
		INNER JOIN orders o ON o.customer_id = cs.customer_id
		INNER JOIN order_details od ON od.order_id = o.order_id
	GROUP BY cs.company_name
	ORDER BY 2 DESC
)
SELECT
	cliente,
	total,
	NTILE(5) OVER (ORDER BY total DESC) AS grupo
FROM
	cliente_total
;
--     - Agora somente os clientes que estão nos grupos 3, 4 e 5 para que seja feita uma análise de Marketing especial com eles
CREATE VIEW grupos_3_4_5 AS
WITH cliente_total AS (
	SELECT
		cs.company_name AS cliente,
		ROUND(CAST(SUM((od.unit_price * od.quantity)  * (1.0 - od.discount)) AS numeric), 2) AS total,
		NTILE(5) OVER (ORDER BY SUM((od.unit_price * od.quantity)  * (1.0 - od.discount)) DESC) AS grupo
	FROM
		customers cs
		INNER JOIN orders o ON o.customer_id = cs.customer_id
		INNER JOIN order_details od ON od.order_id = o.order_id
	GROUP BY cs.company_name
	ORDER BY 2 DESC
)
SELECT
	cliente,
	total,
	grupo
FROM
	cliente_total
WHERE
	grupo >= 3
;

-- 3. Top 10 Produtos Mais Vendidos
--     - Identificar os 10 produtos mais vendidos.
CREATE VIEW top_10_produtos_por_receita AS
WITH top_10_prod AS (
	SELECT
		od.product_id as product_id,
		ROUND(CAST(SUM((od.unit_price * od.quantity)  * (1.0 - od.discount)) AS numeric), 2) AS total
	FROM order_details od
	GROUP BY od.product_id
	ORDER BY 2 DESC
	LIMIT 10	
)
SELECT
	ps.product_name AS produto,
	t10.total AS total_receita,
	RANK() OVER (ORDER BY t10.total DESC) AS "rank"
FROM
	products ps
	INNER JOIN top_10_prod t10 ON t10.product_id = ps.product_id
;

-- 4. Clientes do Reino Unido que Pagaram Mais de 1000 Dólares
--     - Quais clientes do Reino Unido pagaram mais de 1000 dólares?
CREATE VIEW clietnes_britanicos_acima_1k_usd AS
SELECT
	cs.company_name AS cliente,
	ROUND(CAST(SUM((od.unit_price * od.quantity)  * (1.0 - od.discount)) AS numeric), 2) AS total
FROM
	customers cs
	INNER JOIN orders o ON o.customer_id = cs.customer_id
	INNER JOIN order_details od ON od.order_id = o.order_id
WHERE LOWER(cs.country) = 'uk'
GROUP BY cs.company_name
HAVING SUM((od.unit_price * od.quantity)  * (1.0 - od.discount)) > 1e3
ORDER BY 2 DESC
;