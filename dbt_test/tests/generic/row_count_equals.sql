{#- Fails if the table does not have exactly the expected number of rows. -#}
{% test row_count_equals(model, expected) %}
select count(*) as actual_rows, {{ expected }} as expected_rows
from {{ model }}
having count(*) <> {{ expected }}
{% endtest %}
