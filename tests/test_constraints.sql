-- Negative tests: each statement below breaks a schema rule and MUST be
-- rejected by SQLite. run_tests.sh runs each block on its own inside a
-- transaction that is rolled back, with foreign_keys = ON.
--
-- A block starts with a line "-- @test <name>" and runs until the next one.

-- @test reject student with unknown major
INSERT INTO students (first_name, last_name, email, date_of_birth, enrollment_year, major_dept_id)
VALUES ('X', 'Y', 'x.y@student.school.edu', '2005-01-01', 2024, 999);

-- @test reject duplicate student email
INSERT INTO students (first_name, last_name, email, date_of_birth, enrollment_year)
VALUES ('Liam', 'Clone', 'liam.nguyen@student.school.edu', '2005-01-01', 2024);

-- @test reject invalid student status
UPDATE students SET status = 'Expelled' WHERE student_id = 1;

-- @test reject student without email
INSERT INTO students (first_name, last_name, date_of_birth, enrollment_year)
VALUES ('No', 'Email', '2005-01-01', 2024);

-- @test reject invalid instructor title
UPDATE instructors SET title = 'Wizard' WHERE instructor_id = 1;

-- @test reject deleting a department that has instructors
DELETE FROM departments WHERE department_id = 1;

-- @test reject term ending before it starts
INSERT INTO terms (name, start_date, end_date) VALUES ('Bad Term', '2027-05-01', '2027-01-01');

-- @test reject duplicate room number in a building
INSERT INTO rooms (building_id, room_number, capacity, room_type) VALUES (1, '101', 50, 'Lecture');

-- @test reject room with zero capacity
INSERT INTO rooms (building_id, room_number, capacity, room_type) VALUES (1, '999', 0, 'Lecture');

-- @test reject invalid room type
INSERT INTO rooms (building_id, room_number, capacity, room_type) VALUES (1, '998', 20, 'Gym');

-- @test reject course with too many credits
INSERT INTO courses (department_id, course_number, title, credits) VALUES (1, '999', 'Too Big', 10);

-- @test reject duplicate course number in a department
INSERT INTO courses (department_id, course_number, title, credits) VALUES (1, '101', 'Dup', 3);

-- @test reject course that is its own prerequisite
INSERT INTO course_prerequisites (course_id, prereq_id) VALUES (1, 1);

-- @test reject duplicate class section
INSERT INTO classes (course_id, term_id, section, instructor_id, max_enrollment) VALUES (1, 2, '001', 3, 50);

-- @test reject class with unknown instructor
INSERT INTO classes (course_id, term_id, section, instructor_id, max_enrollment) VALUES (1, 2, '009', 999, 50);

-- @test reject class with zero max_enrollment
INSERT INTO classes (course_id, term_id, section, instructor_id, max_enrollment) VALUES (1, 2, '010', 3, 0);

-- @test reject meeting on day 8
INSERT INTO class_meetings (class_id, room_id, day_of_week, start_time, end_time) VALUES (1, 1, 8, '09:00', '10:00');

-- @test reject meeting ending before it starts
INSERT INTO class_meetings (class_id, room_id, day_of_week, start_time, end_time) VALUES (1, 1, 2, '10:00', '09:00');

-- @test reject invalid meeting type
INSERT INTO class_meetings (class_id, room_id, day_of_week, start_time, end_time, meeting_type)
VALUES (1, 1, 2, '09:00', '10:00', 'Party');

-- @test reject meeting for unknown class
INSERT INTO class_meetings (class_id, room_id, day_of_week, start_time, end_time) VALUES (999, 1, 2, '09:00', '10:00');

-- @test reject duplicate enrollment
INSERT INTO enrollments (student_id, class_id, enrolled_on) VALUES (1, 8, '2026-04-01');

-- @test reject enrollment for unknown student
INSERT INTO enrollments (student_id, class_id, enrolled_on) VALUES (999, 8, '2026-04-01');

-- @test reject invalid grade
UPDATE enrollments SET grade = 'A+' WHERE enrollment_id = 1;

-- @test reject invalid enrollment status
UPDATE enrollments SET status = 'Maybe' WHERE enrollment_id = 1;
