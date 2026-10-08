-- An advisor belongs to the student's major department; undeclared students have no advisor.
select s.student_id, s.major_dept_id, i.department_id as advisor_dept
from {{ source('school', 'students') }} s
left join {{ source('school', 'instructors') }} i on i.instructor_id = s.advisor_id
where (s.advisor_id is not null and i.department_id is not s.major_dept_id)
   or (s.major_dept_id is null and s.advisor_id is not null)
