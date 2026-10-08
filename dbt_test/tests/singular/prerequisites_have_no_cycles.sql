with recursive chain(course_id, prereq_id, depth) as (
    select course_id, prereq_id, 1 from {{ source('school', 'course_prerequisites') }}
    union all
    select c.course_id, p.prereq_id, c.depth + 1
    from chain c
    join {{ source('school', 'course_prerequisites') }} p on p.course_id = c.prereq_id
    where c.depth < 20
)
select distinct course_id from chain where course_id = prereq_id
