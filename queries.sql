-- queries.sql
-- Tasks 1.3 to 1.5 - DML, some advanced queries, and transactions


-- =============================================================
-- TASK 1.3 - Data Manipulation
-- =============================================================

-- 1.3a - inserting sample data

-- Departments
INSERT INTO Departments (department_name) VALUES
    ('Computer Science'),
    ('Mathematics'),
    ('Physics');

-- Advisors - only 2 were needed but added a 3rd so it feels a bit more real
INSERT INTO Advisors (advisor_id, advisor_name, advisor_email, department_name) VALUES
    (1, 'Dr. Priya Sharma',   'p.sharma@university.edu',   'Computer Science'),
    (2, 'Dr. Rahul Mehta',    'r.mehta@university.edu',    'Mathematics'),
    (3, 'Dr. Anita Verma',    'a.verma@university.edu',    'Physics');

-- Courses - again, 2 were required, added a few extra since they get used later
INSERT INTO Courses (course_code, course_name, instructor_name, instructor_email) VALUES
    ('CS101', 'Introduction to Programming',  'Prof. Sanjay Gupta',   's.gupta@university.edu'),
    ('CS202', 'Data Structures',              'Prof. Meena Joshi',    'm.joshi@university.edu'),
    ('CS303', 'Database Systems',             'Prof. Vikram Singh',   'v.singh@university.edu'),
    ('CS404', 'Operating Systems',            'Prof. Neha Kapoor',    'n.kapoor@university.edu'),
    ('MA101', 'Calculus I',                   'Prof. Arjun Tiwari',   'a.tiwari@university.edu');

-- Students - 3 required, went with 5
INSERT INTO Students (student_id, student_name, department_name, advisor_id, enrollment_year) VALUES
    (101, 'Aakash Patel',   'Computer Science', 1, 2023),
    (102, 'Divya Nair',     'Computer Science', 1, 2024),
    (103, 'Rohan Bose',     'Mathematics',      2, 2024),
    (104, 'Sneha Iyer',     'Computer Science', 1, 2025),
    (105, 'Karan Malhotra', 'Mathematics',      2, 2023);

-- Enrollments (includes marks_obtained)
INSERT INTO Enrollments (student_id, course_code, marks_obtained, enrollment_year) VALUES
    (101, 'CS101', 78.00, 2023),
    (101, 'CS202', 82.00, 2023),
    (102, 'CS101', 55.00, 2024),
    (102, 'CS303', 91.00, 2024),
    (103, 'MA101', 67.00, 2024),
    (104, 'CS101', 30.00, 2025),   -- under 35, gets removed in 1.3c
    (104, 'CS202', 88.00, 2025),
    (105, 'MA101', 72.00, 2023),
    (105, 'CS101', 33.00, 2024);   -- under 35, gets removed in 1.3c


-- 1.3b - update one instructor's email using the primary key

-- course_code is the PK on Courses so this only touches one row
UPDATE Courses
SET    instructor_email = 'sanjay.gupta.new@university.edu'
WHERE  course_code = 'CS101';


-- 1.3c - delete enrollments where marks_obtained < 35
-- (this only removes rows from the junction table, students/courses stay untouched)

DELETE FROM Enrollments
WHERE  marks_obtained < 35;


-- 1.3d - bulk delete on the old flat table
-- Using DELETE here instead of TRUNCATE because:
--   - DELETE is DML, so BEGIN/ROLLBACK actually works with it on any engine
--   - MySQL treats TRUNCATE as DDL, which auto-commits and kills any open transaction
--   - Postgres actually allows TRUNCATE inside a transaction, but since this needs
--     to work the same way across engines, DELETE is just the safer bet

BEGIN;
    DELETE FROM StudentRecords;   -- wipes everything, but can still be rolled back
COMMIT;


-- =============================================================
-- TASK 1.4 - Advanced Querying
-- =============================================================

-- 1.4a - IN operator
-- students enrolled in CS101, CS202 or CS303

SELECT  s.student_name,
        c.course_name
FROM    Students    s
JOIN    Enrollments e ON e.student_id  = s.student_id
JOIN    Courses     c ON c.course_code = e.course_code
WHERE   e.course_code IN ('CS101', 'CS202', 'CS303');


-- 1.4b - BETWEEN + IS NOT NULL
-- students scoring 60-85 whose advisor actually has an email on file

SELECT  s.student_name,
        e.marks_obtained,
        a.advisor_email
FROM    Students    s
JOIN    Enrollments e ON e.student_id = s.student_id
JOIN    Advisors    a ON a.advisor_id = s.advisor_id
WHERE   e.marks_obtained BETWEEN 60 AND 85
  AND   a.advisor_email IS NOT NULL;


-- 1.4c - GROUP BY / HAVING
-- department-level averages, only keeping departments averaging above 55

SELECT  s.department_name,
        AVG(e.marks_obtained)   AS avg_marks,
        MIN(e.marks_obtained)   AS min_marks,
        MAX(e.marks_obtained)   AS max_marks
FROM    Students    s
JOIN    Enrollments e ON e.student_id = s.student_id
GROUP BY s.department_name
HAVING  AVG(e.marks_obtained) > 55;


-- 1.4d - INNER JOIN vs LEFT JOIN, side by side

-- INNER JOIN - drops any student with zero enrollments
SELECT  s.student_name,
        c.course_name,
        e.marks_obtained
FROM    Students    s
INNER JOIN Enrollments e ON e.student_id  = s.student_id
INNER JOIN Courses     c ON c.course_code = e.course_code;

-- LEFT JOIN - keeps everyone, unenrolled students just show NULL for course
SELECT  s.student_name,
        c.course_name,
        e.marks_obtained
FROM    Students    s
LEFT JOIN  Enrollments e ON e.student_id  = s.student_id
LEFT JOIN  Courses     c ON c.course_code = e.course_code;


-- 1.4e - correlated subquery, students scoring above their own department average

SELECT  s.student_name,
        e.marks_obtained,
        s.department_name
FROM    Students    s
JOIN    Enrollments e ON e.student_id = s.student_id
WHERE   e.marks_obtained > (
            SELECT  AVG(e2.marks_obtained)
            FROM    Students    s2
            JOIN    Enrollments e2 ON e2.student_id = s2.student_id
            WHERE   s2.department_name = s.department_name
        );


-- 1.4f - EXCEPT
-- students who enrolled in something in 2024 but nothing in 2025

SELECT student_id FROM Enrollments WHERE enrollment_year = 2024
EXCEPT
SELECT student_id FROM Enrollments WHERE enrollment_year = 2025;


-- 1.4g - second highest scorer per department
-- Went with the classic "max below the max" trick here rather than
-- messing with averages, since that approach isn't reliable.

SELECT  s.student_name,
        s.department_name,
        e.marks_obtained
FROM    Students    s
JOIN    Enrollments e ON e.student_id = s.student_id
WHERE   e.marks_obtained = (
    -- second highest = the biggest value that's still less than the dept max
    SELECT  MAX(e2.marks_obtained)
    FROM    Students    s2
    JOIN    Enrollments e2 ON e2.student_id = s2.student_id
    WHERE   s2.department_name = s.department_name
      AND   e2.marks_obtained < (
                SELECT  MAX(e3.marks_obtained)
                FROM    Students    s3
                JOIN    Enrollments e3 ON e3.student_id = s3.student_id
                WHERE   s3.department_name = s.department_name
            )
)
-- skip departments where there's really only one distinct mark to work with
  AND (
    SELECT COUNT(DISTINCT e4.marks_obtained)
    FROM   Students    s4
    JOIN   Enrollments e4 ON e4.student_id = s4.student_id
    WHERE  s4.department_name = s.department_name
  ) >= 2;


-- 1.4h - window functions: ROW_NUMBER, RANK, DENSE_RANK
-- running all three together so you can actually see how they diverge
-- once two students in the same department tie on marks

SELECT  s.student_name,
        s.department_name,
        e.marks_obtained,
        ROW_NUMBER()  OVER (PARTITION BY s.department_name
                            ORDER BY e.marks_obtained DESC) AS row_num,
        RANK()        OVER (PARTITION BY s.department_name
                            ORDER BY e.marks_obtained DESC) AS rank_val,
        DENSE_RANK()  OVER (PARTITION BY s.department_name
                            ORDER BY e.marks_obtained DESC) AS dense_rank_val
FROM    Students    s
JOIN    Enrollments e ON e.student_id = s.student_id
ORDER BY s.department_name, e.marks_obtained DESC;


-- =============================================================
-- TASK 1.5 - Transactions and Isolation
-- =============================================================

-- 1.5a - move student 101 from CS101 to CS404
-- if the insert fails partway through, the whole block should roll back

BEGIN;

    -- drop the existing CS101 enrollment
    DELETE FROM Enrollments
    WHERE  student_id  = 101
      AND  course_code = 'CS101';

    -- add the new CS404 enrollment
    -- if CS404 isn't actually in the Courses table, the FK constraint
    -- throws, the app (or an EXCEPTION block in Postgres) catches it,
    -- and we roll back
    INSERT INTO Enrollments (student_id, course_code, marks_obtained, enrollment_year)
    VALUES (101, 'CS404', 0.00, 2024);

COMMIT;

-- if running this by hand and the insert above fails, roll back manually:
-- ROLLBACK;

-- 1.5b - non-repeatable read
-- T1 reads student 101's marks. T2 updates that same value and commits.
-- T1 reads again and now sees something different.
--
-- This is a non-repeatable read.
--
-- Lowest isolation level that stops it: REPEATABLE READ.
-- At that level a transaction keeps seeing whatever version of a row
-- it first read, no matter what else gets committed in the meantime.
-- READ COMMITTED won't save you here.

-- 1.5c - phantom / lost update
-- Two transactions both check how many students are enrolled in a
-- course, both see room available, and both go ahead and insert -
-- pushing the course over capacity.
--
-- This is a phantom read (some would call it write-skew since the
-- check is really on an aggregate rather than a single row, but the
-- underlying cause is the same).
--
-- The textbook phantom case: re-running a range query and finding new
-- rows that got committed by someone else in between. Here both
-- transactions are reading the same count and both act on it, so it
-- lands in the same bucket.
--
-- Only SERIALIZABLE actually prevents this (or manual range locking).
-- REPEATABLE READ stops non-repeatable reads on rows that already
-- exist, but it won't stop new rows from sneaking in.

-- 1.5d - MVCC and consistent snapshots
-- Under MVCC, each transaction works off a snapshot of the database
-- taken at some point - either when the transaction starts, or when
-- each statement starts, depending on the isolation level.
--
-- Scenario:
--   - Transaction R starts up and reads student 101's marks as 78.
--   - Transaction W comes along, updates it to 90, and commits.
--   - R reads the same row again.
--
-- What R sees the second time depends on the isolation level:
--   - Under READ COMMITTED (the default in a lot of engines), R will
--     see 90, because the snapshot refreshes at the start of every
--     statement.
--   - Under REPEATABLE READ / SNAPSHOT isolation, R still sees 78,
--     since it's working off the snapshot from when it began, and
--     MVCC just hands it the older row version without blocking W.
--
-- So the isolation level that keeps a consistent snapshot for the
-- whole transaction is REPEATABLE READ (some engines call this
-- SNAPSHOT isolation - SQL Server's SNAPSHOT level and Postgres's
-- REPEATABLE READ both work this way).
--
-- Trade-off vs READ COMMITTED:
--   - You get a stable, consistent view of the data the whole time -
--     no non-repeatable reads to worry about.
--   - But the database has to hang onto older row versions (dead
--     tuples in Postgres, undo segments in Oracle/SQL Server) for as
--     long as the transaction stays open. Long-running REPEATABLE
--     READ transactions can bloat that version store and slow down
--     autovacuum or fill up tempdb/undo space, which ends up hurting
--     performance for everyone on the database, not just that one
--     transaction.
