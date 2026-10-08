-- Referential integrity, uniqueness and value formats.
-- Every test prints: <test name>|PASS  or  <test name>|FAIL|<detail>

SELECT 'database integrity_check',
       CASE WHEN integrity_check = 'ok' THEN 'PASS' ELSE 'FAIL|' || integrity_check END
FROM pragma_integrity_check;

SELECT 'no foreign key violations',
       CASE WHEN count(*) = 0 THEN 'PASS'
            ELSE 'FAIL|' || count(*) || ' violations, e.g. ' || min("table") END
FROM pragma_foreign_key_check;

SELECT 'foreign keys are declared',
       CASE WHEN count(*) = 14 THEN 'PASS' ELSE 'FAIL|expected 14, found ' || count(*) END
FROM sqlite_schema s, pragma_foreign_key_list(s.name) fk
WHERE s.type = 'table';

-- ---------------------------------------------------------------------------
-- Uniqueness
-- ---------------------------------------------------------------------------

SELECT 'emails unique across students and instructors',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|duplicate: ' || group_concat(email, ', ') END
FROM (
    SELECT email FROM (SELECT email FROM students UNION ALL SELECT email FROM instructors)
    GROUP BY lower(email) HAVING count(*) > 1
);

SELECT 'student enrolled at most once per class',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|' || count(*) || ' duplicates' END
FROM (SELECT 1 FROM enrollments GROUP BY student_id, class_id HAVING count(*) > 1);

-- ---------------------------------------------------------------------------
-- Formats
-- ---------------------------------------------------------------------------

SELECT 'emails are well formed',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|' || group_concat(email, ', ') END
FROM (SELECT email FROM students UNION ALL SELECT email FROM instructors)
WHERE email NOT LIKE '_%@_%.edu' OR email <> lower(email) OR email LIKE '% %';

SELECT 'student emails use student domain',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|' || group_concat(email, ', ') END
FROM students WHERE email NOT LIKE '%@student.school.edu';

SELECT 'dates are valid ISO-8601',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|' || group_concat(src || '=' || d, ', ') END
FROM (
              SELECT 'instructors.hire_date' AS src, hire_date     AS d FROM instructors
    UNION ALL SELECT 'students.date_of_birth',       date_of_birth      FROM students
    UNION ALL SELECT 'terms.start_date',             start_date         FROM terms
    UNION ALL SELECT 'terms.end_date',               end_date           FROM terms
    UNION ALL SELECT 'enrollments.enrolled_on',      enrolled_on        FROM enrollments
)
WHERE d IS NULL OR date(d) IS NOT d;

SELECT 'meeting times are HH:MM',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|meeting_ids ' || group_concat(meeting_id) END
FROM class_meetings
WHERE start_time NOT GLOB '[0-2][0-9]:[0-5][0-9]'
   OR end_time   NOT GLOB '[0-2][0-9]:[0-5][0-9]'
   OR time(start_time) IS NULL
   OR time(end_time)   IS NULL;

SELECT 'student ages are plausible (16-30 at term start)',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|' || group_concat(student_id) END
FROM students
WHERE (julianday('2026-01-12') - julianday(date_of_birth)) / 365.25 NOT BETWEEN 16 AND 30;

SELECT 'enrollment year not in the future',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|' || group_concat(student_id) END
FROM students
WHERE enrollment_year > 2026 OR enrollment_year < CAST(strftime('%Y', date_of_birth) AS INTEGER) + 15;

-- ---------------------------------------------------------------------------
-- Orphans (rows nothing points to that should be used)
-- ---------------------------------------------------------------------------

SELECT 'every department has an instructor',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|' || group_concat(code) END
FROM departments d
WHERE NOT EXISTS (SELECT 1 FROM instructors i WHERE i.department_id = d.department_id);

SELECT 'every class has a meeting',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|class_ids ' || group_concat(class_id) END
FROM classes c
WHERE NOT EXISTS (SELECT 1 FROM class_meetings m WHERE m.class_id = c.class_id);

SELECT 'every class has an instructor',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|class_ids '
       || group_concat(class_id) END
FROM classes WHERE instructor_id IS NULL;

SELECT 'every class meeting has a room',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|meeting_ids '
       || group_concat(meeting_id) END
FROM class_meetings WHERE room_id IS NULL;
