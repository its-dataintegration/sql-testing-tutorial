{#- Fails for every value that is not a valid YYYY-MM-DD date. -#}
{% test is_iso_date(model, column_name) %}
select {{ column_name }} as bad_value
from {{ model }}
where {{ column_name }} is null or date({{ column_name }}) is not {{ column_name }}
{% endtest %}
