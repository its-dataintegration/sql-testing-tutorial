-- Lecture rooms must seat the whole class, and lab meetings must be in lab rooms.
select m.meeting_id, m.meeting_type, c.max_enrollment, r.room_type, r.capacity
from {{ source('school', 'class_meetings') }} m
join {{ source('school', 'classes') }} c on c.class_id = m.class_id
join {{ source('school', 'rooms') }} r on r.room_id = m.room_id
where (m.meeting_type = 'Lecture' and r.capacity < c.max_enrollment)
   or (m.meeting_type = 'Lab' and r.room_type <> 'Lab')
