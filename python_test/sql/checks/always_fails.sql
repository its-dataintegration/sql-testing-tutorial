-- Deliberately failing test, to see what a failure looks like and to confirm
-- pytest reports it and exits non-zero. Delete this file to remove it.

-- @test this test always fails
SELECT 'deliberate failure' AS reason, 'python_test/sql/checks/always_fails.sql' AS file;
