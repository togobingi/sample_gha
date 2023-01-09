{% macro first_value_asc(column_name, partition_column, order_column) %}
    first_value({{ column_name }}) OVER
        (PARTITION BY {{ partition_column }} ORDER BY {{ order_column }} ASC)
{% endmacro %}
