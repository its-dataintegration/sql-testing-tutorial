-- Rules the seed data should obey: no double-booking, capacity, grading, etc.
-- Every test prints: <test name>|PASS  or  <test name>|FAIL|<detail>

-- ---------------------------------------------------------------------------
-- Scheduling conflicts (two meetings overlap if a.start < b.end AND b.start < a.end)
-- ---------------------------------------------------------------------------

SELECT 'no room double-booked',
       CASE WHEN count(*) = 0 THEN 'PASS'
            ELSE 'FAIL|meeting pairs ' || group_concat(a.meeting_id || '/' || b.meeting_id, ', ') END
FROM class_meetings a
JOIN class_meetings b ON b.meeting_id > a.meeting_id
                     AND b.room_id = a.room_id
                     AND b.day_of_week = a.day_of_week
JOIN classes ca ON ca.class_id = a.class_id
JOIN classes cb ON cb.class_id = b.class_id AND cb.term_id = ca.term_id
WHERE a.start_time < b.end_time AND b.start_time < a.end_time;

SELECT 'no instructor double-booked',
       CASE WHEN count(*) = 0 THEN 'PASS'
            ELSE 'FAIL|meeting pairs ' || group_concat(a.meeting_id || '/' || b.meeting_id, ', ') END
FROM class_meetings a
JOIN class_meetings b ON b.meeting_id > a.meeting_id AND b.day_of_week = a.day_of_week
JOIN classes ca ON ca.class_id = a.class_id
JOIN classes cb ON cb.class_id = b.class_id
               AND cb.term_id = ca.term_id
               AND cb.instructor_id = ca.instructor_id
WHERE a.start_time < b.end_time AND b.start_time < a.end_time;

SELECT 'no student double-booked',
       CASE WHEN count(*) = 0 THEN 'PASS'
            ELSE 'FAIL|' || group_concat(ea.student_id || ':' || ma.class_id || '/' || mb.class_id, ', ') END
FROM enrollments ea
JOIN enrollments ec ON ec.student_id = ea.student_id AND ec.class_id > ea.class_id
JOIN classes ca ON ca.class_id = ea.class_id
JOIN classes cc ON cc.class_id = ec.class_id AND cc.term_id = ca.term_id
JOIN class_meetings ma ON ma.class_id = ea.class_id
JOIN class_meetings mb ON mb.class_id = ec.class_id AND mb.day_of_week = ma.day_of_week
WHERE ea.status IN ('Enrolled', 'Completed')
  AND ec.status IN ('Enrolled', 'Completed')
  AND ma.start_time < mb.end_time AND mb.start_time < ma.end_time;

SELECT 'meetings are on weekdays during 07:00-22:00',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|meeting_ids ' || group_concat(meeting_id) END
FROM class_meetings
WHERE day_of_week > 5 OR start_time < '07:00' OR end_time > '22:00';

SELECT 'meetings last 30 min to 3 hours',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|meeting_ids ' || group_concat(meeting_id) END
FROM class_meetings
WHERE (julianday('2000-01-01 ' || end_time) - julianday('2000-01-01 ' || start_time)) * 24 * 60
      NOT BETWEEN 30 AND 180;

-- ---------------------------------------------------------------------------
-- Capacity
-- ---------------------------------------------------------------------------

SELECT 'enrolled students do not exceed class max_enrollment',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|class_ids ' || group_concat(class_id) END
FROM (
    SELECT c.class_id
    FROM classes c
    JOIN enrollments e ON e.class_id = c.class_id AND e.status IN ('Enrolled', 'Completed')
    GROUP BY c.class_id
    HAVING count(*) > c.max_enrollment
);

SELECT 'lecture rooms can seat class max_enrollment',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|meeting_ids ' || group_concat(m.meeting_id) END
FROM class_meetings m
JOIN classes c ON c.class_id = m.class_id
JOIN rooms   r ON r.room_id  = m.room_id
WHERE m.meeting_type = 'Lecture' AND r.capacity < c.max_enrollment;

SELECT 'lab meetings use lab rooms',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|meeting_ids ' || group_concat(m.meeting_id) END
FROM class_meetings m
JOIN rooms r ON r.room_id = m.room_id
WHERE m.meeting_type = 'Lab' AND r.room_type <> 'Lab';

-- ---------------------------------------------------------------------------
-- Enrollment status and grades
-- ---------------------------------------------------------------------------

SELECT 'completed enrollments have a letter grade',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|enrollment_ids ' || group_concat(enrollment_id) END
FROM enrollments
WHERE status = 'Completed' AND (grade IS NULL OR grade IN ('W', 'I'));

SELECT 'enrolled and waitlisted have no grade yet',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|enrollment_ids ' || group_concat(enrollment_id) END
FROM enrollments
WHERE status IN ('Enrolled', 'Waitlisted') AND grade IS NOT NULL;

SELECT 'grade W only on dropped enrollments',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|enrollment_ids ' || group_concat(enrollment_id) END
FROM enrollments
WHERE grade = 'W' AND status <> 'Dropped';

SELECT 'past term has no open enrollments',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|enrollment_ids ' || group_concat(e.enrollment_id) END
FROM enrollments e
JOIN classes c ON c.class_id = e.class_id
JOIN terms   t ON t.term_id  = c.term_id
WHERE t.name = 'Spring 2026' AND e.status IN ('Enrolled', 'Waitlisted');

SELECT 'current term has no completed enrollments',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|enrollment_ids ' || group_concat(e.enrollment_id) END
FROM enrollments e
JOIN classes c ON c.class_id = e.class_id
JOIN terms   t ON t.term_id  = c.term_id
WHERE t.name = 'Fall 2026' AND e.status = 'Completed';

SELECT 'registration happens before term starts',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|enrollment_ids ' || group_concat(e.enrollment_id) END
FROM enrollments e
JOIN classes c ON c.class_id = e.class_id
JOIN terms   t ON t.term_id  = c.term_id
WHERE e.enrolled_on >= t.start_date;

SELECT 'students on leave have no current enrollments',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|student_ids ' || group_concat(s.student_id) END
FROM students s
JOIN enrollments e ON e.student_id = s.student_id AND e.status = 'Enrolled'
WHERE s.status <> 'Active';

-- ---------------------------------------------------------------------------
-- Departments, advisors, prerequisites
-- ---------------------------------------------------------------------------

SELECT 'instructors teach in their own department',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|class_ids ' || group_concat(cl.class_id) END
FROM classes cl
JOIN courses     co ON co.course_id     = cl.course_id
JOIN instructors i  ON i.instructor_id  = cl.instructor_id
WHERE i.department_id <> co.department_id;

SELECT 'advisors belong to the student''s major',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|student_ids ' || group_concat(s.student_id) END
FROM students s
JOIN instructors i ON i.instructor_id = s.advisor_id
WHERE i.department_id IS NOT s.major_dept_id;

SELECT 'undeclared students have no advisor',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|student_ids ' || group_concat(student_id) END
FROM students
WHERE major_dept_id IS NULL AND advisor_id IS NOT NULL;

SELECT 'prerequisite graph has no cycles',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|course_ids ' || group_concat(DISTINCT course_id) END
FROM (
    WITH RECURSIVE chain(course_id, prereq_id, depth) AS (
        SELECT course_id, prereq_id, 1 FROM course_prerequisites
        UNION ALL
        SELECT c.course_id, p.prereq_id, c.depth + 1
        FROM chain c
        JOIN course_prerequisites p ON p.course_id = c.prereq_id
        WHERE c.depth < 20
    )
    SELECT course_id FROM chain WHERE course_id = prereq_id
);

-- Spring 2026 is the only past term in the data, so only students who took the
-- prerequisite in Spring can be checked. A prerequisite failed with D/F/NP must
-- not be followed by enrollment in the dependent course.
SELECT 'no enrollment after failing a prerequisite',
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL|enrollment_ids ' || group_concat(fall.enrollment_id) END
FROM enrollments fall
JOIN classes fc ON fc.class_id = fall.class_id AND fc.term_id = 2
JOIN course_prerequisites p ON p.course_id = fc.course_id
JOIN classes sc ON sc.course_id = p.prereq_id AND sc.term_id = 1
JOIN enrollments spring ON spring.class_id = sc.class_id AND spring.student_id = fall.student_id
WHERE spring.grade IN ('D', 'F', 'NP')
  AND fall.status IN ('Enrolled', 'Waitlisted');
