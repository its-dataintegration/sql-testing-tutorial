-- Active enrollments in a class must not exceed its max_enrollment.
select c.class_id, c.max_enrollment, count(*) as enrolled
from {{ source('school', 'classes') }} c
join {{ source('school', 'enrollments') }} e
  on e.class_id = c.class_id and e.status in ('Enrolled', 'Completed')
group by c.class_id, c.max_enrollment
having count(*) > c.max_enrollment
