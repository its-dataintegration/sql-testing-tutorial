-- Spring 2026 is over (nothing still open); Fall 2026 is current (nothing completed yet);
-- and students register before their term starts.
select e.enrollment_id, t.name as term, e.status, e.enrolled_on, t.start_date
from {{ source('school', 'enrollments') }} e
join {{ source('school', 'classes') }} c on c.class_id = e.class_id
join {{ source('school', 'terms') }} t on t.term_id = c.term_id
where (t.name = 'Spring 2026' and e.status in ('Enrolled', 'Waitlisted'))
   or (t.name = 'Fall 2026' and e.status = 'Completed')
   or e.enrolled_on >= t.start_date
