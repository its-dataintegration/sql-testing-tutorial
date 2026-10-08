-- Meetings are on weekdays, between 07:00 and 22:00, and last 30 minutes to 3 hours.
select meeting_id, day_of_week, start_time, end_time
from {{ source('school', 'class_meetings') }}
where day_of_week > 5
   or start_time < '07:00'
   or end_time > '22:00'
   or (julianday('2000-01-01 ' || end_time) - julianday('2000-01-01 ' || start_time)) * 24 * 60
      not between 30 and 180
