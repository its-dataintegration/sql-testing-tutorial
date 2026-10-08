select cl.class_id, i.instructor_id, i.department_id as instructor_dept, co.department_id as course_dept
from {{ source('school', 'classes') }} cl
join {{ source('school', 'courses') }} co on co.course_id = cl.course_id
join {{ source('school', 'instructors') }} i on i.instructor_id = cl.instructor_id
where i.department_id <> co.department_id
