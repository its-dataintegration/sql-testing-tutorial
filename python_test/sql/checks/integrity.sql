-- Checks: each "-- @test <name>" block is one test.
-- A check returns the rows that BREAK the rule. No rows = pass.

-- @test database passes integrity_check
SELECT integrity_check FROM pragma_integrity_check WHERE integrity_check <> 'ok';

-- @test no foreign key violations
SELECT "table", rowid, parent, fkid FROM pragma_foreign_key_check;

-- @test all 14 foreign keys are declared
SELECT count(*) AS declared_foreign_keys
FROM sqlite_schema s, pragma_foreign_key_list(s.name) fk
WHERE s.type = 'table'
HAVING count(*) <> 14;

-- ---------------------------------------------------------------------------
-- Uniqueness
-- ---------------------------------------------------------------------------

-- @test emails are unique across students and instructors
SELECT lower(email) AS email, count(*) AS times_used
FROM (SELECT email FROM students UNION ALL SELECT email FROM instructors)
GROUP BY lower(email)
HAVING count(*) > 1;

-- @test a student is enrolled at most once per class
SELECT student_id, class_id, count(*) AS times_enrolled
FROM enrollments
GROUP BY student_id, class_id
HAVING count(*) > 1;

-- ---------------------------------------------------------------------------
-- Formats
-- ---------------------------------------------------------------------------

-- @test emails are well formed
SELECT email
FROM (SELECT email FROM students UNION ALL SELECT email FROM instructors)
WHERE email NOT LIKE '_%@_%.edu' OR email <> lower(email) OR email LIKE '% %';

-- @test student emails use the student domain
SELECT student_id, email FROM students WHERE email NOT LIKE '%@student.school.edu';

-- @test dates are valid ISO-8601 (YYYY-MM-DD)
SELECT src, d AS bad_value
FROM (
              SELECT 'instructors.hire_date' AS src, hire_date     AS d FROM instructors
    UNION ALL SELECT 'students.date_of_birth',       date_of_birth      FROM students
    UNION ALL SELECT 'terms.start_date',             start_date         FROM terms
    UNION ALL SELECT 'terms.end_date',               end_date           FROM terms
    UNION ALL SELECT 'enrollments.enrolled_on',      enrolled_on        FROM enrollments
)
WHERE d IS NULL OR date(d) IS NOT d;

-- @test meeting times are HH:MM
SELECT meeting_id, start_time, end_time
FROM class_meetings
WHERE start_time NOT GLOB '[0-2][0-9]:[0-5][0-9]'
   OR end_time   NOT GLOB '[0-2][0-9]:[0-5][0-9]'
   OR time(start_time) IS NULL
   OR time(end_time)   IS NULL;

-- @test student ages are 16-30 at the start of Spring 2026
SELECT student_id, date_of_birth
FROM students
WHERE (julianday('2026-01-12') - julianday(date_of_birth)) / 365.25 NOT BETWEEN 16 AND 30;

-- @test enrollment year is not in the future or before age 15
SELECT student_id, date_of_birth, enrollment_year
FROM students
WHERE enrollment_year > 2026
   OR enrollment_year < CAST(strftime('%Y', date_of_birth) AS INTEGER) + 15;

-- ---------------------------------------------------------------------------
-- Missing pieces
-- ---------------------------------------------------------------------------

-- @test every department has an instructor
SELECT d.code
FROM departments d
WHERE NOT EXISTS (SELECT 1 FROM instructors i WHERE i.department_id = d.department_id);

-- @test every class has at least one meeting
SELECT c.class_id
FROM classes c
WHERE NOT EXISTS (SELECT 1 FROM class_meetings m WHERE m.class_id = c.class_id);

-- @test every class has an instructor
SELECT class_id FROM classes WHERE instructor_id IS NULL;

-- @test every class meeting has a room
SELECT meeting_id, class_id FROM class_meetings WHERE room_id IS NULL;
