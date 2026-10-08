-- Each table holds the expected number of seeded rows.
-- Every test prints: <test name>|PASS  or  <test name>|FAIL|<detail>

SELECT 'row_count: ' || tbl,
       CASE WHEN actual = expected THEN 'PASS'
            ELSE 'FAIL|expected ' || expected || ', got ' || actual END
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
);

SELECT 'all schema objects exist',
       CASE WHEN count(*) = 13 THEN 'PASS'
            ELSE 'FAIL|found ' || count(*) || ' of 13 tables/views' END
FROM sqlite_schema
WHERE (type = 'table' AND name IN ('departments', 'instructors', 'students', 'terms', 'buildings', 'rooms',
                                   'courses', 'course_prerequisites', 'classes', 'class_meetings', 'enrollments'))
   OR (type = 'view'  AND name IN ('v_class_roster', 'v_student_schedule'));
