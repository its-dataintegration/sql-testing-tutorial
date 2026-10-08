-- Checks: each "-- @test <name>" block is one test.
-- A check returns the rows that BREAK the rule. No rows = pass.
--
-- To compare against an exact expected result, list the expected rows and use
-- (expected EXCEPT actual) UNION ALL (actual EXCEPT expected): any row returned
-- is either missing or unexpected.

-- @test v_class_roster has one row per enrollment
SELECT (SELECT count(*) FROM v_class_roster) AS roster_rows,
       (SELECT count(*) FROM enrollments)    AS enrollment_rows
WHERE roster_rows <> enrollment_rows;

-- @test v_class_roster has no blank instructor, course or student
SELECT * FROM v_class_roster
WHERE instructor IS NULL OR course IS NULL OR student IS NULL;

-- @test v_class_roster lists the CS 201 Fall 2026 students
WITH expected(student) AS (
    VALUES ('Ava Martinez'), ('Daniel Walker'), ('Liam Nguyen'), ('Mia Anderson')
),
actual AS (
    SELECT student FROM v_class_roster WHERE term = 'Fall 2026' AND course = 'CS 201'
)
SELECT 'missing' AS problem, student FROM (SELECT student FROM expected EXCEPT SELECT student FROM actual)
UNION ALL
SELECT 'unexpected', student FROM (SELECT student FROM actual EXCEPT SELECT student FROM expected);

-- @test v_student_schedule leaves out dropped and waitlisted classes
-- Student 8 dropped CS 310 and student 6 is waitlisted for it.
SELECT student_id, course, day
FROM v_student_schedule
WHERE student_id IN (6, 8) AND term = 'Fall 2026' AND course = 'CS 310';

-- @test v_student_schedule has one row per meeting of each active enrollment
SELECT (SELECT count(*) FROM v_student_schedule) AS schedule_rows, expected
FROM (SELECT count(*) AS expected
      FROM enrollments e JOIN class_meetings m ON m.class_id = e.class_id
      WHERE e.status IN ('Enrolled', 'Completed'))
WHERE schedule_rows <> expected;

-- @test v_student_schedule day names match day_of_week
SELECT day_of_week, day
FROM v_student_schedule
WHERE day IS NOT substr('MonTueWedThuFriSatSun', (day_of_week - 1) * 3 + 1, 3);

-- @test v_student_schedule shows Liam Nguyen's Fall 2026 timetable
WITH expected(day, start_time, course, room) AS (
    VALUES ('Mon', '10:00', 'MATH 152', 'MTH 100'),
           ('Mon', '11:00', 'CS 201',   'SCI 205'),
           ('Wed', '10:00', 'MATH 152', 'MTH 100'),
           ('Wed', '11:00', 'CS 201',   'SCI 205'),
           ('Fri', '10:00', 'MATH 152', 'MTH 100'),
           ('Fri', '11:00', 'CS 201',   'SCI 205')
),
actual AS (
    SELECT day, start_time, course, room
    FROM v_student_schedule
    WHERE student_id = 1 AND term = 'Fall 2026'
)
SELECT 'missing' AS problem, * FROM (SELECT * FROM expected EXCEPT SELECT * FROM actual)
UNION ALL
SELECT 'unexpected', * FROM (SELECT * FROM actual EXCEPT SELECT * FROM expected);
