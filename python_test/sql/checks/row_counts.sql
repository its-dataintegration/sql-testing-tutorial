-- Checks: each "-- @test <name>" block is one test.
-- A check returns the rows that BREAK the rule. No rows = pass.

-- @test each table has the expected number of rows
SELECT tbl, expected, actual
FROM (
              SELECT 'departments'          AS tbl, 5  AS expected, (SELECT count(*) FROM departments)          AS actual
    UNION ALL SELECT 'instructors',                 10,             (SELECT count(*) FROM instructors)
    UNION ALL SELECT 'students',                    15,             (SELECT count(*) FROM students)
    UNION ALL SELECT 'terms',                       2,              (SELECT count(*) FROM terms)
    UNION ALL SELECT 'buildings',                   3,              (SELECT count(*) FROM buildings)
    UNION ALL SELECT 'rooms',                       8,              (SELECT count(*) FROM rooms)
    UNION ALL SELECT 'courses',                     12,             (SELECT count(*) FROM courses)
    UNION ALL SELECT 'course_prerequisites',        8,              (SELECT count(*) FROM course_prerequisites)
    UNION ALL SELECT 'classes',                     14,             (SELECT count(*) FROM classes)
    UNION ALL SELECT 'class_meetings',              41,             (SELECT count(*) FROM class_meetings)
    UNION ALL SELECT 'enrollments',                 48,             (SELECT count(*) FROM enrollments)
)
WHERE actual <> expected;

-- @test all tables and views exist
SELECT expected.type, expected.name AS missing
FROM (
              SELECT 'table' AS type, 'departments' AS name
    UNION ALL SELECT 'table', 'instructors'
    UNION ALL SELECT 'table', 'students'
    UNION ALL SELECT 'table', 'terms'
    UNION ALL SELECT 'table', 'buildings'
    UNION ALL SELECT 'table', 'rooms'
    UNION ALL SELECT 'table', 'courses'
    UNION ALL SELECT 'table', 'course_prerequisites'
    UNION ALL SELECT 'table', 'classes'
    UNION ALL SELECT 'table', 'class_meetings'
    UNION ALL SELECT 'table', 'enrollments'
    UNION ALL SELECT 'view',  'v_class_roster'
    UNION ALL SELECT 'view',  'v_student_schedule'
) AS expected
LEFT JOIN sqlite_schema s ON s.type = expected.type AND s.name = expected.name
WHERE s.name IS NULL;
