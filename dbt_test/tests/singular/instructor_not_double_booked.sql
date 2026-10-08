-- An instructor cannot teach two overlapping meetings in the same term.
select ca.instructor_id, a.day_of_week, a.meeting_id, b.meeting_id as clashes_with
from {{ source('school', 'class_meetings') }} a
join {{ source('school', 'class_meetings') }} b
  on b.meeting_id > a.meeting_id and b.day_of_week = a.day_of_week
join {{ source('school', 'classes') }} ca on ca.class_id = a.class_id
join {{ source('school', 'classes') }} cb
  on cb.class_id = b.class_id and cb.term_id = ca.term_id and cb.instructor_id = ca.instructor_id
where a.start_time < b.end_time and b.start_time < a.end_time
