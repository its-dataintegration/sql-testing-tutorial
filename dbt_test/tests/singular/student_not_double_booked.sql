-- A student cannot be in two overlapping classes in the same term.
select ea.student_id, ma.day_of_week, ma.class_id, mb.class_id as clashes_with
from {{ source('school', 'enrollments') }} ea
join {{ source('school', 'enrollments') }} ec
  on ec.student_id = ea.student_id and ec.class_id > ea.class_id
join {{ source('school', 'classes') }} ca on ca.class_id = ea.class_id
join {{ source('school', 'classes') }} cc on cc.class_id = ec.class_id and cc.term_id = ca.term_id
join {{ source('school', 'class_meetings') }} ma on ma.class_id = ea.class_id
join {{ source('school', 'class_meetings') }} mb
  on mb.class_id = ec.class_id and mb.day_of_week = ma.day_of_week
where ea.status in ('Enrolled', 'Completed')
  and ec.status in ('Enrolled', 'Completed')
  and ma.start_time < mb.end_time and mb.start_time < ma.end_time
