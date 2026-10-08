{#- Fails for every value that is not a valid 24-hour HH:MM time. -#}
{% test is_hhmm_time(model, column_name) %}
select {{ column_name }} as bad_value
from {{ model }}
where {{ column_name }} not glob '[0-2][0-9]:[0-5][0-9]' or time({{ column_name }}) is null
{% endtest %}
