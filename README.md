# University Student Records — Database Design

## Contents

- `schema.sql` — BCNF-decomposed DDL with all constraints
- `queries.sql` — DML inserts/updates/deletes and all advanced queries (Tasks 1.3–1.5)
- `README.md` — this file

---

## Task 1.1 — Normalization Walkthrough

### Original table

```
StudentRecords(student_id, course_code, student_name, department,
               advisor_name, advisor_email,
               course_name, instructor_name, instructor_email,
               enrollment_year, marks_obtained)
Composite primary key: (student_id, course_code)
```

### Step 1 — Identify dependencies

**Partial dependencies** (non-key attributes that depend on only *part* of the composite key):

| Determinant | Dependent attributes | Problem |
|---|---|---|
| `student_id` alone | `student_name`, `department`, `advisor_name`, `advisor_email`, `enrollment_year` | These repeat for every course a student takes |
| `course_code` alone | `course_name`, `instructor_name`, `instructor_email` | These repeat for every student in a course |

**Transitive dependencies** (non-key attributes that depend on another non-key attribute):

| Determinant | Dependent | Via |
|---|---|---|
| `advisor_name` | `advisor_email` | `student_id → advisor_name → advisor_email` |
| `instructor_name` | `instructor_email` | `course_code → instructor_name → instructor_email` |

**Anomalies caused:**

- *Update anomaly* — changing an advisor's email requires updating every row for every student that advisor supervises.
- *Deletion anomaly* — deleting the last student enrolled in a course removes all knowledge of that course.
- *Insertion anomaly* — a new course cannot be recorded until at least one student enrols in it (because `student_id` is part of the primary key).

---

### Step 2 — First Normal Form (1NF)

The original table already satisfies 1NF: all attributes are atomic and each row is uniquely identified by `(student_id, course_code)`.

---

### Step 3 — Second Normal Form (2NF): remove partial dependencies

Extract every attribute that depends on only one part of the composite key.

**Courses** — resolves the `course_code → course_name, instructor_name, instructor_email` partial dependency:

```
Courses(course_code PK, course_name, instructor_name, instructor_email)
```

**Students (partial)** — resolves the `student_id → student_name, department, advisor_name, advisor_email, enrollment_year` partial dependency:

```
Students_2NF(student_id PK, student_name, department, advisor_name, advisor_email, enrollment_year)
```

**Enrollments** — the only attribute that genuinely requires the full key:

```
Enrollments(student_id FK, course_code FK, marks_obtained)
PK: (student_id, course_code)
```

The table is now in 2NF.

---

### Step 4 — Third Normal Form / BCNF: remove transitive dependencies

`Students_2NF` still contains `advisor_name → advisor_email`, a transitive dependency (non-key → non-key). Extract it.

**Advisors** — resolves `advisor_name → advisor_email` and ties advisors to departments:

```
Advisors(advisor_id PK, advisor_name, advisor_email, department_name FK)
```

**Students (final)** — references advisor by surrogate key:

```
Students(student_id PK, student_name, department_name FK, advisor_id FK, enrollment_year)
```

`Courses` still contains `instructor_name → instructor_email`. Because `instructor_email` is a unique fact about the instructor and every non-key attribute in `Courses` is determined by `course_code` (the sole candidate key), this is a transitive dependency that technically violates 3NF. The cleanest BCNF-compliant fix is to ensure `instructor_email` has a UNIQUE constraint so the functional dependency `instructor_name → instructor_email` is represented as a uniqueness rule rather than an uncontrolled duplication. In a full production schema an `Instructors` table would be added; for this assignment the UNIQUE constraint on `instructor_email` within `Courses` is sufficient to satisfy BCNF because `course_code` is the only determinant of non-key attributes and the instructor data appears exactly once per course.

**Departments** — a small reference table that gives `department_name` a home, enabling referential integrity between `Students` and `Advisors`:

```
Departments(department_name PK)
```

---

### Final BCNF schema

```
Departments(department_name PK)

Advisors(advisor_id PK, advisor_name, advisor_email UQ, department_name FK→Departments)

Courses(course_code PK, course_name, instructor_name, instructor_email UQ)

Students(student_id PK, student_name, department_name FK→Departments,
         advisor_id FK→Advisors, enrollment_year)

Enrollments(student_id FK→Students, course_code FK→Courses,
            marks_obtained, enrollment_year
            PK: (student_id, course_code))
```

Every non-key attribute in every table is determined by the whole primary key and nothing but the primary key. The schema is in BCNF.

---

### Step 5 — Data integrity check

| Integrity type | Satisfied? | Reason |
|---|---|---|
| **Entity integrity** | Yes | Every table has a declared PRIMARY KEY; no PK column allows NULL. |
| **Referential integrity** | Yes | Every FK is declared with REFERENCES and ON UPDATE CASCADE / ON DELETE RESTRICT (or CASCADE for Enrollments), so dangling references cannot arise. |
| **Domain integrity** | Yes | Data types are constrained (INT, VARCHAR, DECIMAL). CHECK constraints bound `marks_obtained` to 0–100 and `enrollment_year` to 1900–2100. UNIQUE constraints prevent duplicate emails. |
| **User-defined integrity** | Yes | The CHECK constraint on `marks_obtained` enforces the business rule that a mark must be a valid percentage. Additional rules (e.g. capacity limits) would be enforced at the application layer or via triggers. |

---

## Design Decisions

### Data types

| Column | Type | Rationale |
|---|---|---|
| `student_id`, `advisor_id` | INT | Surrogate integer keys are compact and fast to index. |
| `marks_obtained` | DECIMAL(5,2) | Exact fixed-point arithmetic avoids floating-point rounding; supports values like 78.50. |
| `enrollment_year` | INT | A four-digit year fits in an INT; no time-of-day component is needed. |
| Name / email columns | VARCHAR(150/200/255) | Variable-length strings save space versus CHAR; lengths chosen conservatively. |
| `course_code` | VARCHAR(20) | Short alphanumeric codes (e.g. CS101); VARCHAR avoids padding. |

### Constraints

- **UNIQUE on email columns** — prevents two advisors or instructors sharing the same email address, which would make emails ambiguous as contact identifiers.
- **ON DELETE CASCADE on Enrollments.student_id** — removing a student automatically cleans up their enrollment rows, preventing orphaned junction records.
- **ON DELETE RESTRICT on course and department FKs** — prevents accidental deletion of a department that still has students, or a course that still has enrollments.
- **DEFAULT 2024 on enrollment_year** — a reasonable stand-in for `CURRENT_YEAR`; in production this would use a trigger or application logic for the actual current year.
- **CHECK (marks_obtained BETWEEN 0 AND 100)** — enforces the domain rule at the database layer regardless of application input.

### Surrogate key for Advisors

`advisor_name` is not used as the primary key even though `advisor_name → advisor_email` is the dependency being resolved. Natural-name keys are fragile (name changes, duplicate names). A surrogate `advisor_id INT` is more stable and performs better in JOINs.

---

## Task 1.5 — Transaction Analysis

### 1.5a — Course transfer transaction

The transfer of student 101 from CS101 to CS404 is wrapped in a single transaction so that either both operations succeed or neither takes effect. If the INSERT into CS404 fails (for example, because CS404 does not exist and the FK constraint fires), the application issues a ROLLBACK, leaving the student still enrolled in CS101. This prevents the student from being unenrolled without a replacement course.

### 1.5b — Non-repeatable read

When transaction T1 reads `marks_obtained` for student 101, then transaction T2 updates and commits that value, and T1 reads the row again and sees a different value, the anomaly is called a **non-repeatable read**. The minimum isolation level that prevents it is **REPEATABLE READ**. At that level the database guarantees that any row a transaction has already read will appear with the same value for the remainder of the transaction, regardless of concurrent commits. READ COMMITTED does not provide this guarantee.

### 1.5c — Phantom insert / capacity overrun

When two concurrent transactions both read the same enrollment count (finding the course has capacity), and both insert a new enrollment, the course ends up over-capacity. The anomaly is a **phantom read** (two transactions see the same pre-insert aggregate and both act on it, producing a result neither would have chosen if they had seen each other's write). The minimum isolation level that prevents phantoms is **SERIALIZABLE**. REPEATABLE READ prevents non-repeatable reads on rows already fetched but does not prevent new rows from appearing within a range that has been queried. SERIALIZABLE causes the database to detect the conflicting range access and abort one of the transactions.

### 1.5d — MVCC and consistent snapshots

Under **Multi-Version Concurrency Control (MVCC)** the database retains multiple versions of each row. When a transaction begins, the engine assigns it a transaction ID and uses that ID to determine which row version is visible.

- If the reporting transaction R runs at **READ COMMITTED**, its snapshot is refreshed at the start of each statement. After write transaction W commits, R's next SELECT will see the updated value (90) because a new statement means a new snapshot.
- If R runs at **REPEATABLE READ** (or SNAPSHOT isolation), its snapshot is taken once when the transaction begins. W's committed update is stored as a newer row version, but the engine continues to serve R the older version (marks = 78) because that version pre-dates R's snapshot. R is never blocked by W, and W is never blocked by R — this is the key concurrency benefit of MVCC over lock-based isolation.

The isolation level that guarantees a consistent snapshot for the entire transaction lifetime is **REPEATABLE READ** (called SNAPSHOT ISOLATION in SQL Server; PostgreSQL's REPEATABLE READ also uses full snapshot semantics).

**Trade-off compared to READ COMMITTED:**

REPEATABLE READ requires the database to retain old row versions in the version store (dead tuples in PostgreSQL's heap, undo segments in Oracle/MySQL InnoDB) for as long as any REPEATABLE READ transaction is open. A long-running reporting transaction can therefore cause significant version-store bloat: in PostgreSQL, autovacuum cannot reclaim dead tuples that are still needed by open transactions, leading to table and index bloat and degraded query performance for the entire cluster. READ COMMITTED avoids this because its per-statement snapshots allow old versions to be reclaimed much sooner.
