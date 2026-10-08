-- Completed enrollments have a letter grade; enrolled/waitlisted have none; W only when dropped.
select enrollment_id, status, grade
from {{ source('school', 'enrollments') }}
where (status = 'Completed' and (grade is null or grade in ('W', 'I')))
   or (status in ('Enrolled', 'Waitlisted') and grade is not null)
   or (grade = 'W' and status <> 'Dropped')
