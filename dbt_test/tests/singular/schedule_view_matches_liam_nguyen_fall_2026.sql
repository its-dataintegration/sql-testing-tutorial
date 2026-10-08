-- Compares the view against an exact expected timetable. Returns rows that are
-- missing from the view or that should not be there.
with expected(day, start_time, course, room) as (
    values ('Mon', '10:00', 'MATH 152', 'MTH 100'),
           ('Mon', '11:00', 'CS 201',   'SCI 205'),
           ('Wed', '10:00', 'MATH 152', 'MTH 100'),
           ('Wed', '11:00', 'CS 201',   'SCI 205'),
           ('Fri', '10:00', 'MATH 152', 'MTH 100'),
           ('Fri', '11:00', 'CS 201',   'SCI 205')
),
actual as (
    select day, start_time, course, room
    from {{ source('school', 'v_student_schedule') }}
    where student_id = 1 and term = 'Fall 2026'
)
select 'missing' as problem, * from (select * from expected except select * from actual)
union all
select 'unexpected', * from (select * from actual except select * from expected)
