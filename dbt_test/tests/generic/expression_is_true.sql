{#- Fails for every row where the SQL expression is not true.
    Usage in YAML:  - expression_is_true: {expression: "credits between 1 and 6"} -#}
{% test expression_is_true(model, expression, column_name=None) %}
select *
from {{ model }}
where not coalesce(({{ expression }}), 0)
{% endtest %}
