-- schema.sql
-- University Student Records - BCNF Decomposition
-- Should work on both Postgres and MySQL, noted a couple spots where they differ

-- dropping in reverse dependency order so this can be re-run safely
DROP TABLE IF EXISTS Enrollments;
DROP TABLE IF EXISTS Students;
DROP TABLE IF EXISTS Courses;
DROP TABLE IF EXISTS Advisors;
DROP TABLE IF EXISTS Departments;

-- also dropping the old flat table if it's still around
DROP TABLE IF EXISTS StudentRecords;

-- -------------------------------------------------------------
-- 1. Departments
--    Just the canonical list of department names.
--    PK: department_name
-- -------------------------------------------------------------
CREATE TABLE Departments (
    department_name VARCHAR(100) NOT NULL,
    CONSTRAINT pk_departments PRIMARY KEY (department_name)
);

-- -------------------------------------------------------------
-- 2. Advisors
--    This pulls out the transitive dependency advisor_name -> advisor_email
--    (in the original flat table those attributes only depended on
--    advisor_name, not the full composite key, so they didn't belong there).
--    PK: advisor_id
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
--    Pulls out the partial dependency: course_code -> course_name,
--    instructor_name, instructor_email. These only depended on
--    course_code, not on the full (student_id, course_code) key.
--    PK: course_code
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
--    Same idea - pulls out student_id -> student_name, department,
--    advisor_id, since those only depend on student_id and not on
--    the full composite key.
--    PK: student_id
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
--    The one thing left that actually depends on the full
--    composite key (student_id, course_code): marks_obtained.
--    Splitting this out is what fixes the insertion anomaly
--    (a course can now exist with no students enrolled) and the
--    deletion anomaly (dropping an enrollment doesn't wipe out
--    the student or course rows along with it).
--    PK: (student_id, course_code)
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
-- Legacy flat table - kept around just for the bulk DELETE demo
-- in Task 1.3d
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
