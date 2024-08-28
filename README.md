# Relatórios Avançados em SQL Northwind

## Objetivo

Este repositório tem como objetivo apresentar relatórios avançados construídos em SQL. As análises disponibilizadas aqui podem ser aplicadas em empresas de todos os tamanhos que desejam se tornar mais analíticas. Através destes relatórios, organizações poderão extrair insights valiosos de seus dados, ajudando na tomada de decisões estratégicas.

## Relatórios que vamos criar

1. **Relatórios de Receita**
    
    * Qual foi o total de receitas no ano de 1997?

    ```sql
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
    ```

    * Faça uma análise de crescimento mensal e o cálculo de YTD

    ```sql
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
    ```

2. **Segmentação de clientes**
    
    * Qual é o valor total que cada cliente já pagou até agora?

    ```sql
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
    ```

    * Separe os clientes em 5 grupos de acordo com o valor pago por cliente

    ```sql
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
    ```


    * Agora somente os clientes que estão nos grupos 3, 4 e 5 para que seja feita uma análise de Marketing especial com eles

    ```sql
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
    ```

3. **Top 10 Produtos Mais Vendidos**
    
    * Identificar os 10 produtos mais vendidos.

    ```sql
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
    ```

4. **Clientes do Reino Unido que Pagaram Mais de 1000 Dólares**
    
    * Quais clientes do Reino Unido pagaram mais de 1000 dólares?

    ```sql
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
    ```

## Contexto

O banco de dados `Northwind` contém os dados de vendas de uma empresa  chamada `Northwind Traders`, que importa e exporta alimentos especiais de todo o mundo. 

O banco de dados Northwind é ERP com dados de clientes, pedidos, inventário, compras, fornecedores, remessas, funcionários e contabilidade.

O conjunto de dados Northwind inclui dados de amostra para o seguinte:

* **Fornecedores:** Fornecedores e vendedores da Northwind
* **Clientes:** Clientes que compram produtos da Northwind
* **Funcionários:** Detalhes dos funcionários da Northwind Traders
* **Produtos:** Informações do produto
* **Transportadoras:** Os detalhes dos transportadores que enviam os produtos dos comerciantes para os clientes finais
* **Pedidos e Detalhes do Pedido:** Transações de pedidos de vendas ocorrendo entre os clientes e a empresa

O banco de dados `Northwind` inclui 14 tabelas e os relacionamentos entre as tabelas são mostrados no seguinte diagrama de relacionamento de entidades.

![northwind](https://github.com/pthom/northwind_psql/blob/master/ER.png?raw=true)

## Objetivo

O objetivo desse 

## Configuração Inicial

### Manualmente

Utilize o arquivo SQL fornecido, `nortwhind.sql`, para popular o seu banco de dados.

### Com Docker e Docker Compose

**Pré-requisito**: Instale o Docker e Docker Compose

* [Começar com Docker](https://www.docker.com/get-started)
* [Instalar Docker Compose](https://docs.docker.com/compose/install/)

### Passos para configuração com Docker:

1. **Iniciar o Docker Compose** Execute o comando abaixo para subir os serviços:
    
    ```
    docker-compose up
    ```
    
    Aguarde as mensagens de configuração, como:
    
    ```csharp
    Creating network "northwind_psql_db" with driver "bridge"
    Creating volume "northwind_psql_db" with default driver
    Creating volume "northwind_psql_pgadmin" with default driver
    Creating pgadmin ... done
    Creating db      ... done
    ```
       
2. **Conectar o PgAdmin** Acesse o PgAdmin pelo URL: [http://localhost:5050](http://localhost:5050), com a senha `postgres`. 

Configure um novo servidor no PgAdmin:
    
    * **Aba General**:
        * Nome: db
    * **Aba Connection**:
        * Nome do host: db
        * Nome de usuário: postgres
        * Senha: postgres Em seguida, selecione o banco de dados "northwind".

3. **Parar o Docker Compose** Pare o servidor iniciado pelo comando `docker-compose up` usando Ctrl-C e remova os contêineres com:
    
    ```
    docker-compose down
    ```
    
4. **Arquivos e Persistência** Suas modificações nos bancos de dados Postgres serão persistidas no volume Docker `postgresql_data` e podem ser recuperadas reiniciando o Docker Compose com `docker-compose up`. Para deletar os dados do banco, execute:
    
    ```
    docker-compose down -v
    ```