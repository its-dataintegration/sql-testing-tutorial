-- Checks: each "-- @test <name>" block is one test.
-- A check returns the rows that BREAK the rule. No rows = pass.

-- ---------------------------------------------------------------------------
-- Scheduling conflicts (two meetings overlap if a.start < b.end AND b.start < a.end)
-- ---------------------------------------------------------------------------

-- @test no room is double-booked
SELECT a.room_id, a.day_of_week, a.meeting_id, b.meeting_id AS clashes_with
FROM class_meetings a
JOIN class_meetings b ON b.meeting_id > a.meeting_id
                     AND b.room_id = a.room_id
                     AND b.day_of_week = a.day_of_week
JOIN classes ca ON ca.class_id = a.class_id
JOIN classes cb ON cb.class_id = b.class_id AND cb.term_id = ca.term_id
WHERE a.start_time < b.end_time AND b.start_time < a.end_time;

-- @test no instructor is double-booked
SELECT ca.instructor_id, a.day_of_week, a.meeting_id, b.meeting_id AS clashes_with
FROM class_meetings a
JOIN class_meetings b ON b.meeting_id > a.meeting_id AND b.day_of_week = a.day_of_week
JOIN classes ca ON ca.class_id = a.class_id
JOIN classes cb ON cb.class_id = b.class_id
               AND cb.term_id = ca.term_id
               AND cb.instructor_id = ca.instructor_id
WHERE a.start_time < b.end_time AND b.start_time < a.end_time;

-- @test no student is double-booked
SELECT ea.student_id, ma.day_of_week, ma.class_id, mb.class_id AS clashes_with
FROM enrollments ea
JOIN enrollments ec ON ec.student_id = ea.student_id AND ec.class_id > ea.class_id
JOIN classes ca ON ca.class_id = ea.class_id
JOIN classes cc ON cc.class_id = ec.class_id AND cc.term_id = ca.term_id
JOIN class_meetings ma ON ma.class_id = ea.class_id
JOIN class_meetings mb ON mb.class_id = ec.class_id AND mb.day_of_week = ma.day_of_week
WHERE ea.status IN ('Enrolled', 'Completed')
  AND ec.status IN ('Enrolled', 'Completed')
  AND ma.start_time < mb.end_time AND mb.start_time < ma.end_time;

-- @test meetings are on weekdays between 07:00 and 22:00
SELECT meeting_id, day_of_week, start_time, end_time
FROM class_meetings
WHERE day_of_week > 5 OR start_time < '07:00' OR end_time > '22:00';

-- @test meetings last between 30 minutes and 3 hours
SELECT meeting_id, start_time, end_time
FROM class_meetings
WHERE (julianday('2000-01-01 ' || end_time) - julianday('2000-01-01 ' || start_time)) * 24 * 60
      NOT BETWEEN 30 AND 180;

-- ---------------------------------------------------------------------------
-- Capacity
-- ---------------------------------------------------------------------------

-- @test classes are not over max_enrollment
SELECT c.class_id, c.max_enrollment, count(*) AS enrolled
FROM classes c
JOIN enrollments e ON e.class_id = c.class_id AND e.status IN ('Enrolled', 'Completed')
GROUP BY c.class_id
HAVING count(*) > c.max_enrollment;

-- @test lecture rooms can seat the whole class
SELECT m.meeting_id, c.class_id, c.max_enrollment, r.capacity
FROM class_meetings m
JOIN classes c ON c.class_id = m.class_id
JOIN rooms   r ON r.room_id  = m.room_id
WHERE m.meeting_type = 'Lecture' AND r.capacity < c.max_enrollment;

-- @test lab meetings use lab rooms
SELECT m.meeting_id, r.room_id, r.room_type
FROM class_meetings m
JOIN rooms r ON r.room_id = m.room_id
WHERE m.meeting_type = 'Lab' AND r.room_type <> 'Lab';

-- ---------------------------------------------------------------------------
-- Enrollment status and grades
-- ---------------------------------------------------------------------------

-- @test completed enrollments have a letter grade
SELECT enrollment_id, grade
FROM enrollments
WHERE status = 'Completed' AND (grade IS NULL OR grade IN ('W', 'I'));

-- @test enrolled and waitlisted students have no grade yet
SELECT enrollment_id, status, grade
FROM enrollments
WHERE status IN ('Enrolled', 'Waitlisted') AND grade IS NOT NULL;

-- @test grade W is only given on dropped enrollments
SELECT enrollment_id, status
FROM enrollments
WHERE grade = 'W' AND status <> 'Dropped';

-- @test past term has no open enrollments
SELECT e.enrollment_id, e.status
FROM enrollments e
JOIN classes c ON c.class_id = e.class_id
JOIN terms   t ON t.term_id  = c.term_id
WHERE t.name = 'Spring 2026' AND e.status IN ('Enrolled', 'Waitlisted');

-- @test current term has no completed enrollments
SELECT e.enrollment_id
FROM enrollments e
JOIN classes c ON c.class_id = e.class_id
JOIN terms   t ON t.term_id  = c.term_id
WHERE t.name = 'Fall 2026' AND e.status = 'Completed';

-- @test registration happens before the term starts
SELECT e.enrollment_id, e.enrolled_on, t.start_date
FROM enrollments e
JOIN classes c ON c.class_id = e.class_id
JOIN terms   t ON t.term_id  = c.term_id
WHERE e.enrolled_on >= t.start_date;

-- @test students who are not active have no current enrollments
SELECT s.student_id, s.status, e.class_id
FROM students s
JOIN enrollments e ON e.student_id = s.student_id AND e.status = 'Enrolled'
WHERE s.status <> 'Active';

-- ---------------------------------------------------------------------------
-- Departments, advisors, prerequisites
-- ---------------------------------------------------------------------------

-- @test instructors teach in their own department
SELECT cl.class_id, i.instructor_id
FROM classes cl
JOIN courses     co ON co.course_id    = cl.course_id
JOIN instructors i  ON i.instructor_id = cl.instructor_id
WHERE i.department_id <> co.department_id;

-- @test advisors belong to the student's major department
SELECT s.student_id, s.major_dept_id, i.department_id AS advisor_dept_id
FROM students s
JOIN instructors i ON i.instructor_id = s.advisor_id
WHERE i.department_id IS NOT s.major_dept_id;

-- @test undeclared students have no advisor
SELECT student_id, advisor_id
FROM students
WHERE major_dept_id IS NULL AND advisor_id IS NOT NULL;

-- @test prerequisite graph has no cycles
WITH RECURSIVE chain(course_id, prereq_id, depth) AS (
    SELECT course_id, prereq_id, 1 FROM course_prerequisites
    UNION ALL
    SELECT c.course_id, p.prereq_id, c.depth + 1
    FROM chain c
    JOIN course_prerequisites p ON p.course_id = c.prereq_id
    WHERE c.depth < 20
)
SELECT DISTINCT course_id FROM chain WHERE course_id = prereq_id;

-- @test no enrollment after failing a prerequisite
-- Spring 2026 is the only past term in the data, so only students who took the
-- prerequisite in Spring can be checked. A prerequisite failed with D/F/NP must
-- not be followed by enrollment in the dependent course.
SELECT fall.enrollment_id, fall.student_id, fc.course_id, p.prereq_id, spring.grade
FROM enrollments fall
JOIN classes fc ON fc.class_id = fall.class_id AND fc.term_id = 2
JOIN course_prerequisites p ON p.course_id = fc.course_id
JOIN classes sc ON sc.course_id = p.prereq_id AND sc.term_id = 1
JOIN enrollments spring ON spring.class_id = sc.class_id AND spring.student_id = fall.student_id
WHERE spring.grade IN ('D', 'F', 'NP')
  AND fall.status IN ('Enrolled', 'Waitlisted');
