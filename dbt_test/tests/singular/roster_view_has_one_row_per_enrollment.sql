select roster_rows, enrollment_rows
from (select (select count(*) from {{ source('school', 'v_class_roster') }}) as roster_rows,
             (select count(*) from {{ source('school', 'enrollments') }}) as enrollment_rows)
where roster_rows <> enrollment_rows
