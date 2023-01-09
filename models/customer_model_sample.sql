{{ config(schema='preprocess') }}

WITH customer_orders AS (SELECT DISTINCT customer.customer_unique_id,
                                         #Macro for: first_value(column_name) OVER (PARTITION BY partition_column ORDER BY order_column DESC
                                         {{ first_value('zip_code_prefix', 'customer_unique_id', 'order_purchase_timestamp') }}          AS zip_code,
                                         {{ first_value('initcap(city)', 'customer_unique_id', 'order_purchase_timestamp') }}            AS city,
                                         {{ first_value('state', 'customer_unique_id', 'order_purchase_timestamp') }}                    AS state,
                                         {{ first_value('order_id', 'customer_unique_id', 'order_purchase_timestamp') }}                 AS first_order_id,
                                         {{ first_value('order_purchase_timestamp', 'customer_unique_id', 'order_purchase_timestamp') }} AS first_order_date,
                                         {{ first_value('order_id', 'customer_unique_id', 'order_purchase_timestamp') }}                 AS last_order_id,
                                         TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),
                                                        (MIN(PARSE_TIMESTAMP('%F %T', order_purchase_timestamp))
                                                             OVER (PARTITION BY customer_unique_id)),
                                                        DAY)                                                                             AS days_since_first_order,
                                         TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),
                                                        (MAX(PARSE_TIMESTAMP('%F %T', order_purchase_timestamp))
                                                             OVER (PARTITION BY customer_unique_id)),
                                                        DAY)                                                                             AS days_since_last_order,
--                                          CURRENT_TIMESTAMP() - MIN(PARSE_TIMESTAMP('c', order_purchase_timestamp))
--                                                                    OVER (PARTITION BY customer_unique_id) AS days_since_first_order,
                                         order_purchase_timestamp
                         FROM {{ source ('postgres', 'order') }}
                                  LEFT JOIN {{ source ('postgres', 'customer')}} customer USING (customer_id))


-- Customers get different ids for different orders -> Deduplication on customer_unique_id
-- Keep the last order's customer data across distinct customer_unique_id
-- If there is no order data (this is because the order data was not sampled), keep the first_value
SELECT DISTINCT customer.customer_unique_id                                   AS customer_id,
                {{ first_value('coalesce(customer_orders.zip_code, customer.zip_code_prefix)',
                               'customer_unique_id',
                               'order_purchase_timestamp') }} AS zip_code,
                customer_orders.first_order_id                                AS first_order_id,
                customer_orders.first_order_date                              AS first_order_date,
                customer_orders.last_order_id                                 AS last_order_id,
                {{ first_value('coalesce(customer_orders.city, customer.city)',
                               'customer_unique_id',
                               'order_purchase_timestamp') }} AS city,
                {{ first_value('coalesce(customer_orders.state, customer.state)',
                               'customer_unique_id',
                               'order_purchase_timestamp') }} AS state,
                customer_orders.days_since_first_order                        AS days_since_first_order,
                customer_orders.days_since_last_order                         AS days_since_last_order
FROM {{ source ('postgres', 'customer') }} customer
         LEFT JOIN customer_orders USING (customer_unique_id)
