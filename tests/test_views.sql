-- The convenience views return the right rows.
-- Every test prints: <test name>|PASS  or  <test name>|FAIL|<detail>

SELECT 'v_class_roster has one row per enrollment',
       CASE WHEN (SELECT count(*) FROM v_class_roster) = (SELECT count(*) FROM enrollments) THEN 'PASS'
            ELSE 'FAIL|roster ' || (SELECT count(*) FROM v_class_roster)
                 || ' vs enrollments ' || (SELECT count(*) FROM enrollments) END;

SELECT 'v_class_roster has no NULL instructor or course',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|' || count(*) || ' rows' END
FROM v_class_roster
WHERE instructor IS NULL OR course IS NULL OR student IS NULL;

SELECT 'v_class_roster: CS 201 Fall 2026 roster',
       CASE WHEN group_concat(student, ', ') = 'Ava Martinez, Daniel Walker, Liam Nguyen, Mia Anderson'
            THEN 'PASS' ELSE 'FAIL|got ' || ifnull(group_concat(student, ', '), '<none>') END
FROM (SELECT student FROM v_class_roster
      WHERE term = 'Fall 2026' AND course = 'CS 201' ORDER BY student);

-- Student 8 dropped CS 310 and student 6 is waitlisted for it.
SELECT 'v_student_schedule excludes dropped and waitlisted',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|' || count(*) || ' rows' END
FROM v_student_schedule
WHERE student_id IN (6, 8) AND term = 'Fall 2026' AND course = 'CS 310';

SELECT 'v_student_schedule row count matches meetings of active enrollments',
       CASE WHEN (SELECT count(*) FROM v_student_schedule) = expected THEN 'PASS'
            ELSE 'FAIL|expected ' || expected || ', got ' || (SELECT count(*) FROM v_student_schedule) END
FROM (SELECT count(*) AS expected
      FROM enrollments e JOIN class_meetings m ON m.class_id = e.class_id
      WHERE e.status IN ('Enrolled', 'Completed'));

SELECT 'v_student_schedule: day names match day_of_week',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|' || count(*) || ' rows' END
FROM v_student_schedule
WHERE day IS NOT substr('MonTueWedThuFriSatSun', (day_of_week - 1) * 3 + 1, 3);

SELECT 'v_student_schedule: Liam Nguyen Fall 2026 timetable',
       CASE WHEN group_concat(slot, '; ') =
                 'Mon 10:00 MATH 152 MTH 100; Mon 11:00 CS 201 SCI 205; '
              || 'Wed 10:00 MATH 152 MTH 100; Wed 11:00 CS 201 SCI 205; '
              || 'Fri 10:00 MATH 152 MTH 100; Fri 11:00 CS 201 SCI 205'
            THEN 'PASS' ELSE 'FAIL|got ' || ifnull(group_concat(slot, '; '), '<none>') END
FROM (SELECT day || ' ' || start_time || ' ' || course || ' ' || room AS slot
      FROM v_student_schedule
      WHERE student_id = 1 AND term = 'Fall 2026'
      ORDER BY day_of_week, start_time);
