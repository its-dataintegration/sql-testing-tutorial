{#- Fails for every value that does not match the SQL LIKE pattern. -#}
{% test matches_like(model, column_name, pattern) %}
select {{ column_name }} as bad_value
from {{ model }}
where {{ column_name }} not like '{{ pattern }}'
{% endtest %}
