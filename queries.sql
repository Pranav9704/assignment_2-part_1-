-- =============================================================
-- queries.sql
-- Tasks 1.3 – 1.5: DML, advanced queries, and transactions
-- =============================================================


-- =============================================================
-- TASK 1.3 — Data Manipulation
-- =============================================================

-- ---- 1.3a: Insert sample data ----------------------------------

-- Departments
INSERT INTO Departments (department_name) VALUES
    ('Computer Science'),
    ('Mathematics'),
    ('Physics');

-- Advisors (two advisors required; inserting three for realism)
INSERT INTO Advisors (advisor_id, advisor_name, advisor_email, department_name) VALUES
    (1, 'Dr. Priya Sharma',   'p.sharma@university.edu',   'Computer Science'),
    (2, 'Dr. Rahul Mehta',    'r.mehta@university.edu',    'Mathematics'),
    (3, 'Dr. Anita Verma',    'a.verma@university.edu',    'Physics');

-- Courses (two required; inserting five to support later queries)
INSERT INTO Courses (course_code, course_name, instructor_name, instructor_email) VALUES
    ('CS101', 'Introduction to Programming',  'Prof. Sanjay Gupta',   's.gupta@university.edu'),
    ('CS202', 'Data Structures',              'Prof. Meena Joshi',    'm.joshi@university.edu'),
    ('CS303', 'Database Systems',             'Prof. Vikram Singh',   'v.singh@university.edu'),
    ('CS404', 'Operating Systems',            'Prof. Neha Kapoor',    'n.kapoor@university.edu'),
    ('MA101', 'Calculus I',                   'Prof. Arjun Tiwari',   'a.tiwari@university.edu');

-- Students (three required; inserting five)
INSERT INTO Students (student_id, student_name, department_name, advisor_id, enrollment_year) VALUES
    (101, 'Aakash Patel',   'Computer Science', 1, 2023),
    (102, 'Divya Nair',     'Computer Science', 1, 2024),
    (103, 'Rohan Bose',     'Mathematics',      2, 2024),
    (104, 'Sneha Iyer',     'Computer Science', 1, 2025),
    (105, 'Karan Malhotra', 'Mathematics',      2, 2023);

-- Enrollments (marks_obtained included)
INSERT INTO Enrollments (student_id, course_code, marks_obtained, enrollment_year) VALUES
    (101, 'CS101', 78.00, 2023),
    (101, 'CS202', 82.00, 2023),
    (102, 'CS101', 55.00, 2024),
    (102, 'CS303', 91.00, 2024),
    (103, 'MA101', 67.00, 2024),
    (104, 'CS101', 30.00, 2025),   -- below 35 threshold; used in 1.3c
    (104, 'CS202', 88.00, 2025),
    (105, 'MA101', 72.00, 2023),
    (105, 'CS101', 33.00, 2024);   -- below 35 threshold; used in 1.3c


-- ---- 1.3b: Update one instructor's email by primary key --------

-- Target exactly one row: course_code is the PK of Courses.
UPDATE Courses
SET    instructor_email = 'sanjay.gupta.new@university.edu'
WHERE  course_code = 'CS101';


-- ---- 1.3c: Delete enrollments where marks_obtained < 35 --------
-- Students and Courses rows are NOT deleted; only the junction rows.

DELETE FROM Enrollments
WHERE  marks_obtained < 35;


-- ---- 1.3d: Bulk DELETE on the legacy flat table ----------------
-- DELETE is preferred over TRUNCATE inside a transaction because:
--   • DELETE is a DML statement recognised by BEGIN/ROLLBACK in
--     every major database engine.
--   • In MySQL, TRUNCATE is DDL: it issues an implicit COMMIT,
--     so any open transaction is committed and cannot be rolled back.
--   • In PostgreSQL, TRUNCATE is transactional, but for cross-engine
--     portability the safest choice is always DELETE without a WHERE
--     clause — it can be rolled back in both engines.

BEGIN;
    DELETE FROM StudentRecords;   -- removes all rows; rollback-safe
COMMIT;


-- =============================================================
-- TASK 1.4 — Advanced Querying
-- =============================================================

-- ---- 1.4a: IN operator -----------------------------------------
-- Students enrolled in CS101, CS202, or CS303.

SELECT  s.student_name,
        c.course_name
FROM    Students    s
JOIN    Enrollments e ON e.student_id  = s.student_id
JOIN    Courses     c ON c.course_code = e.course_code
WHERE   e.course_code IN ('CS101', 'CS202', 'CS303');


-- ---- 1.4b: BETWEEN and IS NOT NULL -----------------------------
-- Students with marks between 60 and 85 who have a non-null advisor email.

SELECT  s.student_name,
        e.marks_obtained,
        a.advisor_email
FROM    Students    s
JOIN    Enrollments e ON e.student_id = s.student_id
JOIN    Advisors    a ON a.advisor_id = s.advisor_id
WHERE   e.marks_obtained BETWEEN 60 AND 85
  AND   a.advisor_email IS NOT NULL;


-- ---- 1.4c: GROUP BY / HAVING -----------------------------------
-- Per-department aggregate marks; only departments with avg > 55.

SELECT  s.department_name,
        AVG(e.marks_obtained)   AS avg_marks,
        MIN(e.marks_obtained)   AS min_marks,
        MAX(e.marks_obtained)   AS max_marks
FROM    Students    s
JOIN    Enrollments e ON e.student_id = s.student_id
GROUP BY s.department_name
HAVING  AVG(e.marks_obtained) > 55;


-- ---- 1.4d: INNER JOIN then LEFT JOIN ---------------------------

-- INNER JOIN: only students who have at least one enrollment.
SELECT  s.student_name,
        c.course_name,
        e.marks_obtained
FROM    Students    s
INNER JOIN Enrollments e ON e.student_id  = s.student_id
INNER JOIN Courses     c ON c.course_code = e.course_code;

-- LEFT JOIN: all students appear; unenrolled students show NULL course.
SELECT  s.student_name,
        c.course_name,
        e.marks_obtained
FROM    Students    s
LEFT JOIN  Enrollments e ON e.student_id  = s.student_id
LEFT JOIN  Courses     c ON c.course_code = e.course_code;


-- ---- 1.4e: Correlated subquery — above-department-average marks -

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


-- ---- 1.4f: EXCEPT set operation --------------------------------
-- Students enrolled in 2024 but not in 2025.

SELECT student_id FROM Enrollments WHERE enrollment_year = 2024
EXCEPT
SELECT student_id FROM Enrollments WHERE enrollment_year = 2025;


-- ---- 1.4g: Second-highest scorer per department ----------------
-- Correlated subquery approach:
-- "Higher than the average of all marks except the maximum" is not
-- robust; instead we use the classic "higher than all but one" pattern.

SELECT  s.student_name,
        s.department_name,
        e.marks_obtained
FROM    Students    s
JOIN    Enrollments e ON e.student_id = s.student_id
WHERE   e.marks_obtained = (
    -- The second-highest is the maximum value that is strictly less
    -- than the maximum value in the same department.
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
-- Exclude departments that have only one distinct mark (single-student depts).
  AND (
    SELECT COUNT(DISTINCT e4.marks_obtained)
    FROM   Students    s4
    JOIN   Enrollments e4 ON e4.student_id = s4.student_id
    WHERE  s4.department_name = s.department_name
  ) >= 2;


-- ---- 1.4h: Window functions — ROW_NUMBER, RANK, DENSE_RANK -----
-- All three applied together so differences are visible when two
-- students in the same department share equal marks.

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
-- TASK 1.5 — Transactions and Isolation
-- =============================================================

-- ---- 1.5a: Transfer student 101 from CS101 to CS404 -----------
-- The block rolls back automatically if the INSERT fails.

BEGIN;

    -- Step 1: Remove existing enrollment in CS101.
    DELETE FROM Enrollments
    WHERE  student_id  = 101
      AND  course_code = 'CS101';

    -- Step 2: Enroll in CS404.
    -- If CS404 does not exist in Courses the FK constraint fires an
    -- error, the EXCEPTION block (PostgreSQL) or application logic
    -- catches it, and ROLLBACK is issued.
    INSERT INTO Enrollments (student_id, course_code, marks_obtained, enrollment_year)
    VALUES (101, 'CS404', 0.00, 2024);

COMMIT;

-- Rollback branch (executed by application on caught exception,
-- or manually if running interactively and the INSERT above fails):
-- ROLLBACK;

-- ---- 1.5b: Concurrency anomaly — non-repeatable read -----------
-- Scenario: Transaction T1 reads marks_obtained for student 101.
--           Transaction T2 updates that value and commits.
--           T1 reads the same row again and sees a different value.
--
-- Anomaly name: NON-REPEATABLE READ
--
-- Minimum isolation level that prevents it: REPEATABLE READ
--   At REPEATABLE READ, a transaction always sees the same version
--   of any row it has already read, regardless of concurrent commits.
--   (READ COMMITTED does NOT prevent this anomaly.)

-- ---- 1.5c: Concurrency anomaly — phantom / lost update ---------
-- Scenario: Two transactions both read the enrollment count for a
--           course, both see capacity available, and both insert a
--           new row — exceeding the course's maximum capacity.
--
-- Anomaly name: PHANTOM READ (or more precisely a write-skew /
--               phantom insert when the check involves an aggregate)
--
-- The classic phantom: a transaction re-executes a range query and
-- finds new rows inserted by a concurrent committed transaction.
-- Here both transactions read the same aggregate (count < limit)
-- and both proceed to insert, so this is also described as a
-- PHANTOM READ scenario.
--
-- Minimum isolation level that prevents it: SERIALIZABLE
--   REPEATABLE READ prevents non-repeatable reads on existing rows
--   but does NOT prevent phantoms caused by newly inserted rows.
--   Only SERIALIZABLE (or explicit range locking) prevents this.

-- ---- 1.5d: MVCC — consistent snapshot read ---------------------
-- Under MVCC each transaction works against the snapshot of the
-- database that existed at the moment the transaction (or the
-- statement, depending on isolation level) began.
--
-- Scenario:
--   • Reporting transaction R starts; reads student 101's
--     marks_obtained = 78.
--   • Write transaction W updates marks_obtained to 90 and commits.
--   • R re-reads the same row.
--
-- What R sees on the second read depends on isolation level:
--   • At READ COMMITTED (default in many engines): R sees 90 — the
--     newly committed value — because the snapshot is refreshed at
--     the start of each statement.
--   • At REPEATABLE READ / SNAPSHOT: R still sees 78 — the value
--     from the snapshot taken when R began — because MVCC serves
--     the old row version to R and never blocks W.
--
-- Isolation level that guarantees a consistent snapshot throughout
-- the entire transaction:
--   REPEATABLE READ (also called SNAPSHOT ISOLATION in some engines,
--   e.g. SQL Server's SNAPSHOT isolation level or PostgreSQL's
--   REPEATABLE READ which uses full snapshot semantics).
--
-- Trade-off of REPEATABLE READ vs READ COMMITTED:
--   • Benefit: the transaction always sees a consistent, stable view
--     of data — no non-repeatable reads.
--   • Trade-off: the database must retain older row versions in the
--     version store (PostgreSQL: dead tuples; Oracle/SQL Server:
--     undo segments) for the entire duration of long-running
--     transactions, increasing storage and vacuum/cleanup overhead.
--     Very long REPEATABLE READ transactions can bloat the version
--     store and slow autovacuum (PostgreSQL) or fill the tempdb /
--     undo tablespace (SQL Server / Oracle), degrading performance
--     for the entire database cluster.
