{% macro first_value(column_name, partition_column, order_column) %}
    first_value({{ column_name }}) OVER
        (PARTITION BY {{ partition_column }} ORDER BY {{ order_column }} DESC)
{% endmacro %}
