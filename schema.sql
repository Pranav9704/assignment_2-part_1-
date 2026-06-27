-- =============================================================
-- schema.sql
-- University Student Records — BCNF Decomposition
-- Compatible with PostgreSQL and MySQL (notes where they differ)
-- =============================================================

-- Drop tables in reverse dependency order (safe re-run)
DROP TABLE IF EXISTS Enrollments;
DROP TABLE IF EXISTS Students;
DROP TABLE IF EXISTS Courses;
DROP TABLE IF EXISTS Advisors;
DROP TABLE IF EXISTS Departments;

-- Also drop the legacy flat table if it exists
DROP TABLE IF EXISTS StudentRecords;

-- -------------------------------------------------------------
-- 1. Departments
--    Resolves: stores the canonical department name.
--    Primary key: department_name
-- -------------------------------------------------------------
CREATE TABLE Departments (
    department_name VARCHAR(100) NOT NULL,
    CONSTRAINT pk_departments PRIMARY KEY (department_name)
);

-- -------------------------------------------------------------
-- 2. Advisors
--    Resolves transitive dependency: advisor_name → advisor_email
--    (both were non-key attributes of StudentRecords that depended
--     only on advisor_name, not on the full composite key).
--    Primary key: advisor_id
-- -------------------------------------------------------------
CREATE TABLE Advisors (
    advisor_id      INT             NOT NULL,
    advisor_name    VARCHAR(150)    NOT NULL,
    advisor_email   VARCHAR(255)    NOT NULL,
    department_name VARCHAR(100)    NOT NULL,
    CONSTRAINT pk_advisors      PRIMARY KEY (advisor_id),
    CONSTRAINT uq_advisor_email UNIQUE      (advisor_email),
    CONSTRAINT fk_advisor_dept  FOREIGN KEY (department_name)
        REFERENCES Departments (department_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- -------------------------------------------------------------
-- 3. Courses
--    Resolves partial dependency: course_code → course_name,
--    instructor_name, instructor_email.
--    These attributes depended only on course_code, not on the
--    full composite key (student_id, course_code).
--    Primary key: course_code
-- -------------------------------------------------------------
CREATE TABLE Courses (
    course_code         VARCHAR(20)     NOT NULL,
    course_name         VARCHAR(200)    NOT NULL,
    instructor_name     VARCHAR(150)    NOT NULL,
    instructor_email    VARCHAR(255)    NOT NULL,
    CONSTRAINT pk_courses           PRIMARY KEY (course_code),
    CONSTRAINT uq_instructor_email  UNIQUE      (instructor_email)
);

-- -------------------------------------------------------------
-- 4. Students
--    Resolves partial dependency: student_id → student_name,
--    department, advisor_id.
--    These attributes depended only on student_id, not on the
--    full composite key.
--    Primary key: student_id
-- -------------------------------------------------------------
CREATE TABLE Students (
    student_id      INT             NOT NULL,
    student_name    VARCHAR(150)    NOT NULL,
    department_name VARCHAR(100)    NOT NULL,
    advisor_id      INT             NOT NULL,
    enrollment_year INT             NOT NULL DEFAULT 2024,
    CONSTRAINT pk_students      PRIMARY KEY (student_id),
    CONSTRAINT fk_student_dept  FOREIGN KEY (department_name)
        REFERENCES Departments (department_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_student_adv  FOREIGN KEY (advisor_id)
        REFERENCES Advisors (advisor_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_enroll_year CHECK (enrollment_year BETWEEN 1900 AND 2100)
);

-- -------------------------------------------------------------
-- 5. Enrollments
--    The only remaining fact that truly depends on the full
--    composite key (student_id, course_code): marks_obtained.
--    Resolves: insertion anomaly (course can exist without a
--    student) and deletion anomaly (removing an enrollment does
--    not delete the student or course records).
--    Primary key: (student_id, course_code)
-- -------------------------------------------------------------
CREATE TABLE Enrollments (
    student_id      INT             NOT NULL,
    course_code     VARCHAR(20)     NOT NULL,
    marks_obtained  DECIMAL(5, 2)   NOT NULL DEFAULT 0.00,
    enrollment_year INT             NOT NULL DEFAULT 2024,
    CONSTRAINT pk_enrollments   PRIMARY KEY (student_id, course_code),
    CONSTRAINT fk_enroll_stu   FOREIGN KEY (student_id)
        REFERENCES Students (student_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_enroll_crs   FOREIGN KEY (course_code)
        REFERENCES Courses (course_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_marks        CHECK (marks_obtained BETWEEN 0 AND 100),
    CONSTRAINT chk_enroll_year2 CHECK (enrollment_year BETWEEN 1900 AND 2100)
);

-- -------------------------------------------------------------
-- Legacy flat table (for Task 1.3d — bulk DELETE demonstration)
-- -------------------------------------------------------------
CREATE TABLE StudentRecords (
    student_id      INT,
    student_name    VARCHAR(150),
    department      VARCHAR(100),
    advisor_name    VARCHAR(150),
    advisor_email   VARCHAR(255),
    course_code     VARCHAR(20),
    course_name     VARCHAR(200),
    instructor_name VARCHAR(150),
    instructor_email VARCHAR(255),
    enrollment_year INT,
    marks_obtained  DECIMAL(5, 2)
);
