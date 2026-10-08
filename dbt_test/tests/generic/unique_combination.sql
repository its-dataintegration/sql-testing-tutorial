{#- Fails for every combination of the listed columns that appears more than once. -#}
{% test unique_combination(model, columns) %}
select {{ columns | join(', ') }}, count(*) as times_used
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1
{% endtest %}
