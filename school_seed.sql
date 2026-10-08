-- =============================================================================
-- School schema + seed data (SQLite 3)
--
-- Usage:
--   sqlite3 school.db < school_seed.sql
--
-- Re-runnable: drops and recreates all tables each time.
-- =============================================================================

PRAGMA foreign_keys = OFF;

BEGIN TRANSACTION;

DROP VIEW  IF EXISTS v_student_schedule;
DROP VIEW  IF EXISTS v_class_roster;
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS class_meetings;
DROP TABLE IF EXISTS classes;
DROP TABLE IF EXISTS course_prerequisites;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS buildings;
DROP TABLE IF EXISTS terms;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS instructors;
DROP TABLE IF EXISTS departments;

COMMIT;

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- -----------------------------------------------------------------------------
-- Schema
-- -----------------------------------------------------------------------------

CREATE TABLE departments (
    department_id   INTEGER PRIMARY KEY,
    code            TEXT    NOT NULL UNIQUE,
    name            TEXT    NOT NULL
);

CREATE TABLE instructors (
    instructor_id   INTEGER PRIMARY KEY,
    department_id   INTEGER NOT NULL REFERENCES departments(department_id),
    first_name      TEXT    NOT NULL,
    last_name       TEXT    NOT NULL,
    email           TEXT    NOT NULL UNIQUE,
    title           TEXT    NOT NULL CHECK (title IN ('Lecturer', 'Assistant Professor', 'Associate Professor', 'Professor')),
    office          TEXT,
    hire_date       TEXT    NOT NULL  -- ISO-8601 date (YYYY-MM-DD)
);

CREATE TABLE students (
    student_id      INTEGER PRIMARY KEY,
    first_name      TEXT    NOT NULL,
    last_name       TEXT    NOT NULL,
    email           TEXT    NOT NULL UNIQUE,
    date_of_birth   TEXT    NOT NULL,
    enrollment_year INTEGER NOT NULL,
    major_dept_id   INTEGER REFERENCES departments(department_id),
    advisor_id      INTEGER REFERENCES instructors(instructor_id),
    status          TEXT    NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'On Leave', 'Graduated', 'Withdrawn'))
);

CREATE TABLE terms (
    term_id         INTEGER PRIMARY KEY,
    name            TEXT    NOT NULL UNIQUE,
    start_date      TEXT    NOT NULL,
    end_date        TEXT    NOT NULL,
    CHECK (end_date > start_date)
);

CREATE TABLE buildings (
    building_id     INTEGER PRIMARY KEY,
    code            TEXT    NOT NULL UNIQUE,
    name            TEXT    NOT NULL
);

CREATE TABLE rooms (
    room_id         INTEGER PRIMARY KEY,
    building_id     INTEGER NOT NULL REFERENCES buildings(building_id),
    room_number     TEXT    NOT NULL,
    capacity        INTEGER NOT NULL CHECK (capacity > 0),
    room_type       TEXT    NOT NULL CHECK (room_type IN ('Lecture', 'Lab', 'Seminar')),
    UNIQUE (building_id, room_number)
);

CREATE TABLE courses (
    course_id       INTEGER PRIMARY KEY,
    department_id   INTEGER NOT NULL REFERENCES departments(department_id),
    course_number   TEXT    NOT NULL,
    title           TEXT    NOT NULL,
    description     TEXT,
    credits         INTEGER NOT NULL CHECK (credits BETWEEN 1 AND 6),
    UNIQUE (department_id, course_number)
);

CREATE TABLE course_prerequisites (
    course_id       INTEGER NOT NULL REFERENCES courses(course_id),
    prereq_id       INTEGER NOT NULL REFERENCES courses(course_id),
    PRIMARY KEY (course_id, prereq_id),
    CHECK (course_id <> prereq_id)
);

-- A "class" is a specific offering (section) of a course in a given term.
CREATE TABLE classes (
    class_id        INTEGER PRIMARY KEY,
    course_id       INTEGER NOT NULL REFERENCES courses(course_id),
    term_id         INTEGER NOT NULL REFERENCES terms(term_id),
    section         TEXT    NOT NULL,
    instructor_id   INTEGER REFERENCES instructors(instructor_id),
    max_enrollment  INTEGER NOT NULL CHECK (max_enrollment > 0),
    UNIQUE (course_id, term_id, section)
);

-- Weekly schedule: one row per meeting slot.
-- day_of_week: 1 = Monday ... 7 = Sunday. Times are 24h HH:MM.
CREATE TABLE class_meetings (
    meeting_id      INTEGER PRIMARY KEY,
    class_id        INTEGER NOT NULL REFERENCES classes(class_id) ON DELETE CASCADE,
    room_id         INTEGER REFERENCES rooms(room_id),
    day_of_week     INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    start_time      TEXT    NOT NULL,
    end_time        TEXT    NOT NULL,
    meeting_type    TEXT    NOT NULL DEFAULT 'Lecture' CHECK (meeting_type IN ('Lecture', 'Lab', 'Discussion')),
    CHECK (end_time > start_time)
);

CREATE TABLE enrollments (
    enrollment_id   INTEGER PRIMARY KEY,
    student_id      INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    class_id        INTEGER NOT NULL REFERENCES classes(class_id) ON DELETE CASCADE,
    enrolled_on     TEXT    NOT NULL,
    status          TEXT    NOT NULL DEFAULT 'Enrolled' CHECK (status IN ('Enrolled', 'Dropped', 'Completed', 'Waitlisted')),
    grade           TEXT    CHECK (grade IN ('A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D', 'F', 'P', 'NP', 'W', 'I')),
    UNIQUE (student_id, class_id)
);

CREATE INDEX idx_instructors_dept     ON instructors(department_id);
CREATE INDEX idx_students_major       ON students(major_dept_id);
CREATE INDEX idx_classes_term         ON classes(term_id);
CREATE INDEX idx_classes_instructor   ON classes(instructor_id);
CREATE INDEX idx_meetings_class       ON class_meetings(class_id);
CREATE INDEX idx_meetings_room_day    ON class_meetings(room_id, day_of_week);
CREATE INDEX idx_enrollments_class    ON enrollments(class_id);

-- -----------------------------------------------------------------------------
-- Seed data
-- -----------------------------------------------------------------------------

INSERT INTO departments (department_id, code, name) VALUES
    (1, 'CS',   'Computer Science'),
    (2, 'MATH', 'Mathematics'),
    (3, 'PHYS', 'Physics'),
    (4, 'ENGL', 'English'),
    (5, 'HIST', 'History');

INSERT INTO instructors (instructor_id, department_id, first_name, last_name, email, title, office, hire_date) VALUES
    (1,  1, 'Ada',      'Lovelace',  'ada.lovelace@school.edu',    'Professor',           'SCI 301', '2008-08-15'),
    (2,  1, 'Alan',     'Turing',    'alan.turing@school.edu',     'Associate Professor', 'SCI 305', '2012-01-10'),
    (3,  1, 'Grace',    'Hopper',    'grace.hopper@school.edu',    'Assistant Professor', 'SCI 307', '2019-08-20'),
    (4,  2, 'Carl',     'Gauss',     'carl.gauss@school.edu',      'Professor',           'MTH 210', '2005-08-18'),
    (5,  2, 'Emmy',     'Noether',   'emmy.noether@school.edu',    'Associate Professor', 'MTH 214', '2014-08-22'),
    (6,  3, 'Marie',    'Curie',     'marie.curie@school.edu',     'Professor',           'SCI 120', '2007-01-05'),
    (7,  3, 'Richard',  'Feynman',   'richard.feynman@school.edu', 'Lecturer',            'SCI 124', '2021-08-16'),
    (8,  4, 'Toni',     'Morrison',  'toni.morrison@school.edu',   'Professor',           'HUM 402', '2010-08-17'),
    (9,  4, 'James',    'Baldwin',   'james.baldwin@school.edu',   'Assistant Professor', 'HUM 405', '2020-01-12'),
    (10, 5, 'Howard',   'Zinn',      'howard.zinn@school.edu',     'Associate Professor', 'HUM 210', '2011-08-19');

INSERT INTO students (student_id, first_name, last_name, email, date_of_birth, enrollment_year, major_dept_id, advisor_id, status) VALUES
    (1,  'Liam',     'Nguyen',    'liam.nguyen@student.school.edu',     '2005-03-14', 2023, 1, 1,  'Active'),
    (2,  'Olivia',   'Patel',     'olivia.patel@student.school.edu',    '2004-11-02', 2022, 1, 2,  'Active'),
    (3,  'Noah',     'Garcia',    'noah.garcia@student.school.edu',     '2006-01-27', 2024, 2, 4,  'Active'),
    (4,  'Emma',     'Kim',       'emma.kim@student.school.edu',        '2005-07-09', 2023, 3, 6,  'Active'),
    (5,  'Elijah',   'Johnson',   'elijah.johnson@student.school.edu',  '2004-05-30', 2022, 4, 8,  'Active'),
    (6,  'Ava',      'Martinez',  'ava.martinez@student.school.edu',    '2006-09-18', 2024, 1, 3,  'Active'),
    (7,  'James',    'Brown',     'james.brown@student.school.edu',     '2005-12-05', 2023, 5, 10, 'Active'),
    (8,  'Sophia',   'Davis',     'sophia.davis@student.school.edu',    '2004-02-21', 2022, 2, 5,  'Active'),
    (9,  'Lucas',    'Wilson',    'lucas.wilson@student.school.edu',    '2006-06-11', 2024, 3, 7,  'Active'),
    (10, 'Mia',      'Anderson',  'mia.anderson@student.school.edu',    '2005-08-25', 2023, 1, 1,  'Active'),
    (11, 'Henry',    'Thomas',    'henry.thomas@student.school.edu',    '2004-10-13', 2022, 4, 9,  'On Leave'),
    (12, 'Isabella', 'Lee',       'isabella.lee@student.school.edu',    '2006-04-03', 2024, NULL, NULL, 'Active'),
    (13, 'Benjamin', 'Clark',     'benjamin.clark@student.school.edu',  '2005-01-19', 2023, 2, 4,  'Active'),
    (14, 'Charlotte','Lewis',     'charlotte.lewis@student.school.edu', '2004-07-07', 2022, 5, 10, 'Active'),
    (15, 'Daniel',   'Walker',    'daniel.walker@student.school.edu',   '2006-11-29', 2024, 1, 2,  'Active');

INSERT INTO terms (term_id, name, start_date, end_date) VALUES
    (1, 'Spring 2026', '2026-01-12', '2026-05-08'),
    (2, 'Fall 2026',   '2026-08-24', '2026-12-11');

INSERT INTO buildings (building_id, code, name) VALUES
    (1, 'SCI', 'Science Center'),
    (2, 'MTH', 'Mathematics Hall'),
    (3, 'HUM', 'Humanities Building');

INSERT INTO rooms (room_id, building_id, room_number, capacity, room_type) VALUES
    (1, 1, '101', 120, 'Lecture'),
    (2, 1, '110', 40,  'Lab'),
    (3, 1, '205', 60,  'Lecture'),
    (4, 1, '220', 30,  'Lab'),
    (5, 2, '100', 80,  'Lecture'),
    (6, 2, '150', 35,  'Seminar'),
    (7, 3, '101', 100, 'Lecture'),
    (8, 3, '310', 25,  'Seminar');

INSERT INTO courses (course_id, department_id, course_number, title, description, credits) VALUES
    (1,  1, '101', 'Introduction to Programming',  'Fundamentals of programming using Python.',               4),
    (2,  1, '201', 'Data Structures',              'Lists, trees, graphs, hashing and algorithm analysis.',   4),
    (3,  1, '310', 'Database Systems',             'Relational model, SQL, normalization and transactions.',  3),
    (4,  2, '151', 'Calculus I',                   'Limits, derivatives and introductory integration.',       4),
    (5,  2, '152', 'Calculus II',                  'Integration techniques, sequences and series.',           4),
    (6,  2, '220', 'Linear Algebra',               'Vector spaces, matrices, eigenvalues.',                   3),
    (7,  3, '121', 'Physics I: Mechanics',         'Kinematics, Newtonian dynamics, energy and momentum.',    4),
    (8,  3, '122', 'Physics II: Electromagnetism', 'Electric and magnetic fields, circuits, waves.',          4),
    (9,  4, '101', 'College Writing',              'Academic writing, argumentation and research.',           3),
    (10, 4, '240', 'American Literature',          'Survey of American literature from 1850 to present.',     3),
    (11, 5, '110', 'World History',                'Global history from antiquity to the modern era.',        3),
    (12, 5, '250', 'History of Technology',        'How technology has shaped society.',                      3);

INSERT INTO course_prerequisites (course_id, prereq_id) VALUES
    (2,  1),   -- Data Structures       <- Intro to Programming
    (3,  2),   -- Database Systems      <- Data Structures
    (5,  4),   -- Calculus II           <- Calculus I
    (6,  4),   -- Linear Algebra        <- Calculus I
    (7,  4),   -- Physics I             <- Calculus I
    (8,  7),   -- Physics II            <- Physics I
    (8,  5),   -- Physics II            <- Calculus II
    (10, 9);   -- American Literature   <- College Writing

INSERT INTO classes (class_id, course_id, term_id, section, instructor_id, max_enrollment) VALUES
    -- Spring 2026
    (1,  1,  1, '001', 3,  100),  -- CS 101
    (2,  4,  1, '001', 4,  80),   -- MATH 151
    (3,  9,  1, '001', 9,  25),   -- ENGL 101
    (4,  11, 1, '001', 10, 90),   -- HIST 110
    (5,  7,  1, '001', 6,  60),   -- PHYS 121
    -- Fall 2026
    (6,  1,  2, '001', 3,  100),  -- CS 101
    (7,  1,  2, '002', 2,  40),   -- CS 101 (second section)
    (8,  2,  2, '001', 1,  60),   -- CS 201
    (9,  3,  2, '001', 2,  40),   -- CS 310
    (10, 5,  2, '001', 5,  80),   -- MATH 152
    (11, 6,  2, '001', 4,  35),   -- MATH 220
    (12, 8,  2, '001', 7,  60),   -- PHYS 122
    (13, 10, 2, '001', 8,  25),   -- ENGL 240
    (14, 12, 2, '001', 10, 25);   -- HIST 250

INSERT INTO class_meetings (class_id, room_id, day_of_week, start_time, end_time, meeting_type) VALUES
    -- Spring 2026
    (1,  1, 1, '09:00', '09:50', 'Lecture'),
    (1,  1, 3, '09:00', '09:50', 'Lecture'),
    (1,  1, 5, '09:00', '09:50', 'Lecture'),
    (1,  2, 4, '15:00', '16:50', 'Lab'),
    (2,  5, 1, '10:00', '10:50', 'Lecture'),
    (2,  5, 3, '10:00', '10:50', 'Lecture'),
    (2,  5, 5, '10:00', '10:50', 'Lecture'),
    (2,  6, 2, '11:00', '11:50', 'Discussion'),
    (3,  8, 2, '09:30', '10:45', 'Lecture'),
    (3,  8, 4, '09:30', '10:45', 'Lecture'),
    (4,  7, 2, '13:00', '14:15', 'Lecture'),
    (4,  7, 4, '13:00', '14:15', 'Lecture'),
    (5,  3, 1, '13:00', '13:50', 'Lecture'),
    (5,  3, 3, '13:00', '13:50', 'Lecture'),
    (5,  3, 5, '13:00', '13:50', 'Lecture'),
    (5,  4, 2, '15:00', '16:50', 'Lab'),
    -- Fall 2026
    (6,  1, 1, '09:00', '09:50', 'Lecture'),
    (6,  1, 3, '09:00', '09:50', 'Lecture'),
    (6,  1, 5, '09:00', '09:50', 'Lecture'),
    (6,  2, 4, '14:00', '15:50', 'Lab'),
    (7,  3, 2, '11:00', '12:15', 'Lecture'),
    (7,  3, 4, '11:00', '12:15', 'Lecture'),
    (7,  2, 5, '15:00', '16:50', 'Lab'),
    (8,  3, 1, '11:00', '11:50', 'Lecture'),
    (8,  3, 3, '11:00', '11:50', 'Lecture'),
    (8,  3, 5, '11:00', '11:50', 'Lecture'),
    (9,  3, 2, '14:00', '15:15', 'Lecture'),
    (9,  3, 4, '09:30', '10:45', 'Lecture'),
    (10, 5, 1, '10:00', '10:50', 'Lecture'),
    (10, 5, 3, '10:00', '10:50', 'Lecture'),
    (10, 5, 5, '10:00', '10:50', 'Lecture'),
    (11, 6, 2, '09:30', '10:45', 'Lecture'),
    (11, 6, 4, '14:00', '15:15', 'Lecture'),
    (12, 1, 1, '13:00', '13:50', 'Lecture'),
    (12, 1, 3, '13:00', '13:50', 'Lecture'),
    (12, 1, 5, '13:00', '13:50', 'Lecture'),
    (12, 4, 2, '15:30', '17:20', 'Lab'),
    (13, 8, 2, '13:00', '14:15', 'Lecture'),
    (13, 8, 4, '13:00', '14:15', 'Lecture'),
    (14, 8, 1, '15:00', '16:15', 'Lecture'),
    (14, 8, 3, '15:00', '16:15', 'Lecture');

INSERT INTO enrollments (student_id, class_id, enrolled_on, status, grade) VALUES
    -- Spring 2026 (completed, graded)
    (1,  1, '2025-11-10', 'Completed', 'A'),
    (1,  2, '2025-11-10', 'Completed', 'B+'),
    (2,  2, '2025-11-08', 'Completed', 'A-'),
    (3,  2, '2025-11-12', 'Completed', 'A'),
    (3,  3, '2025-11-12', 'Completed', 'B'),
    (4,  2, '2025-11-09', 'Completed', 'B'),
    (4,  5, '2025-11-09', 'Completed', 'A-'),
    (5,  3, '2025-11-15', 'Completed', 'A'),
    (5,  4, '2025-11-15', 'Completed', 'B+'),
    (6,  1, '2025-11-11', 'Completed', 'B+'),
    (6,  9, '2026-04-02', 'Waitlisted', NULL),
    (7,  4, '2025-11-14', 'Completed', 'A-'),
    (8,  2, '2025-11-07', 'Completed', 'A'),
    (9,  5, '2025-11-13', 'Completed', 'C+'),
    (10, 1, '2025-11-10', 'Completed', 'A-'),
    (11, 3, '2025-11-16', 'Dropped',   'W'),
    (12, 1, '2025-11-18', 'Completed', 'B'),
    (12, 4, '2025-11-18', 'Completed', 'A'),
    (13, 2, '2025-11-10', 'Completed', 'B-'),
    (14, 4, '2025-11-12', 'Completed', 'A'),
    (15, 1, '2025-11-19', 'Completed', 'C'),
    -- Fall 2026 (in progress)
    (1,  8,  '2026-04-01', 'Enrolled', NULL),
    (1,  10, '2026-04-01', 'Enrolled', NULL),
    (2,  9,  '2026-03-30', 'Enrolled', NULL),
    (2,  11, '2026-03-30', 'Enrolled', NULL),
    (3,  10, '2026-04-03', 'Enrolled', NULL),
    (3,  11, '2026-04-03', 'Enrolled', NULL),
    (4,  10, '2026-04-02', 'Enrolled', NULL),
    (4,  12, '2026-04-02', 'Enrolled', NULL),
    (5,  13, '2026-04-05', 'Enrolled', NULL),
    (5,  14, '2026-04-05', 'Enrolled', NULL),
    (6,  8,  '2026-04-02', 'Enrolled', NULL),
    (7,  14, '2026-04-04', 'Enrolled', NULL),
    (7,  6,  '2026-04-04', 'Enrolled', NULL),
    (8,  11, '2026-03-29', 'Enrolled', NULL),
    (8,  9,  '2026-03-29', 'Dropped',  NULL),
    (9,  6,  '2026-04-06', 'Enrolled', NULL),
    (9,  10, '2026-04-06', 'Enrolled', NULL),
    (10, 8,  '2026-04-01', 'Enrolled', NULL),
    (10, 11, '2026-04-01', 'Enrolled', NULL),
    (12, 7,  '2026-04-07', 'Enrolled', NULL),
    (12, 13, '2026-04-07', 'Enrolled', NULL),
    (13, 10, '2026-04-02', 'Enrolled', NULL),
    (13, 12, '2026-04-02', 'Enrolled', NULL),
    (14, 14, '2026-04-03', 'Enrolled', NULL),
    (14, 7,  '2026-04-03', 'Enrolled', NULL),
    (15, 8,  '2026-04-08', 'Enrolled', NULL),
    (15, 10, '2026-04-08', 'Enrolled', NULL);

-- -----------------------------------------------------------------------------
-- Convenience views
-- -----------------------------------------------------------------------------

-- Who is in each class, and who teaches it.
CREATE VIEW v_class_roster AS
SELECT
    t.name                                   AS term,
    d.code || ' ' || c.course_number         AS course,
    c.title                                  AS course_title,
    cl.section                               AS section,
    i.first_name || ' ' || i.last_name       AS instructor,
    s.student_id                             AS student_id,
    s.first_name || ' ' || s.last_name       AS student,
    e.status                                 AS enrollment_status,
    e.grade                                  AS grade
FROM enrollments e
JOIN students    s  ON s.student_id    = e.student_id
JOIN classes     cl ON cl.class_id     = e.class_id
JOIN courses     c  ON c.course_id     = cl.course_id
JOIN departments d  ON d.department_id = c.department_id
JOIN terms       t  ON t.term_id       = cl.term_id
LEFT JOIN instructors i ON i.instructor_id = cl.instructor_id;

-- Each student's weekly timetable (excludes dropped enrollments).
CREATE VIEW v_student_schedule AS
SELECT
    s.student_id                             AS student_id,
    s.first_name || ' ' || s.last_name       AS student,
    t.name                                   AS term,
    d.code || ' ' || c.course_number         AS course,
    cl.section                               AS section,
    m.meeting_type                           AS meeting_type,
    m.day_of_week                            AS day_of_week,
    CASE m.day_of_week
        WHEN 1 THEN 'Mon' WHEN 2 THEN 'Tue' WHEN 3 THEN 'Wed'
        WHEN 4 THEN 'Thu' WHEN 5 THEN 'Fri' WHEN 6 THEN 'Sat'
        WHEN 7 THEN 'Sun'
    END                                      AS day,
    m.start_time                             AS start_time,
    m.end_time                               AS end_time,
    b.code || ' ' || r.room_number           AS room,
    i.first_name || ' ' || i.last_name       AS instructor
FROM enrollments    e
JOIN students       s  ON s.student_id    = e.student_id
JOIN classes        cl ON cl.class_id     = e.class_id
JOIN courses        c  ON c.course_id     = cl.course_id
JOIN departments    d  ON d.department_id = c.department_id
JOIN terms          t  ON t.term_id       = cl.term_id
JOIN class_meetings m  ON m.class_id      = cl.class_id
LEFT JOIN rooms     r  ON r.room_id       = m.room_id
LEFT JOIN buildings b  ON b.building_id   = r.building_id
LEFT JOIN instructors i ON i.instructor_id = cl.instructor_id
WHERE e.status IN ('Enrolled', 'Completed');

COMMIT;
