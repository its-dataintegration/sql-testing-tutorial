-- Spring 2026 is the only past term, so only prerequisites taken then can be checked:
-- failing one (D/F/NP) must not be followed by enrollment in the dependent course.
select fall.enrollment_id, fall.student_id, fc.course_id, p.prereq_id, spring.grade
from {{ source('school', 'enrollments') }} fall
join {{ source('school', 'classes') }} fc on fc.class_id = fall.class_id and fc.term_id = 2
join {{ source('school', 'course_prerequisites') }} p on p.course_id = fc.course_id
join {{ source('school', 'classes') }} sc on sc.course_id = p.prereq_id and sc.term_id = 1
join {{ source('school', 'enrollments') }} spring
  on spring.class_id = sc.class_id and spring.student_id = fall.student_id
where spring.grade in ('D', 'F', 'NP')
  and fall.status in ('Enrolled', 'Waitlisted')
