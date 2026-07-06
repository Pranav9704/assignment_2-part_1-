# University Student Records — Database Design

## Contents

- `schema.sql` — the BCNF-decomposed DDL, constraints and all
- `queries.sql` — inserts/updates/deletes plus all the advanced queries (Tasks 1.3–1.5)
- `README.md` — this file

---

## Task 1.1 — Normalization Walkthrough

### The original table

```
StudentRecords(student_id, course_code, student_name, department,
               advisor_name, advisor_email,
               course_name, instructor_name, instructor_email,
               enrollment_year, marks_obtained)
Composite primary key: (student_id, course_code)
```

### Step 1 — Spotting the dependencies

**Partial dependencies** (attributes that only depend on *part* of the composite key, not the whole thing):

| Determinant | Dependent attributes | Problem |
|---|---|---|
| `student_id` alone | `student_name`, `department`, `advisor_name`, `advisor_email`, `enrollment_year` | Same values repeated for every course that student takes |
| `course_code` alone | `course_name`, `instructor_name`, `instructor_email` | Same values repeated for every student in that course |

**Transitive dependencies** (a non-key attribute depending on another non-key attribute):

| Determinant | Dependent | Via |
|---|---|---|
| `advisor_name` | `advisor_email` | `student_id → advisor_name → advisor_email` |
| `instructor_name` | `instructor_email` | `course_code → instructor_name → instructor_email` |

**What this breaks:**

- *Update anomaly* — change one advisor's email and you'd have to update it on every row for every student they advise.
- *Deletion anomaly* — drop the last student enrolled in a course and you lose all record that the course ever existed.
- *Insertion anomaly* — can't add a new course until someone's actually enrolled in it, since `student_id` is part of the PK.

---

### Step 2 — First Normal Form (1NF)

The original table's already fine on this front — every attribute is atomic, and `(student_id, course_code)` uniquely identifies each row.

---

### Step 3 — Second Normal Form (2NF): getting rid of partial dependencies

Pull out anything that only depends on one half of the composite key.

**Courses** — fixes the `course_code → course_name, instructor_name, instructor_email` dependency:

```
Courses(course_code PK, course_name, instructor_name, instructor_email)
```

**Students (partial)** — fixes `student_id → student_name, department, advisor_name, advisor_email, enrollment_year`:

```
Students_2NF(student_id PK, student_name, department, advisor_name, advisor_email, enrollment_year)
```

**Enrollments** — the one thing left that actually needs the full key:

```
Enrollments(student_id FK, course_code FK, marks_obtained)
PK: (student_id, course_code)
```

That gets us to 2NF.

---

### Step 4 — Third Normal Form / BCNF: getting rid of transitive dependencies

`Students_2NF` still has `advisor_name → advisor_email` hiding in it — a non-key attribute depending on another non-key attribute. Pull that out too.

**Advisors** — resolves `advisor_name → advisor_email` and links advisors to a department:

```
Advisors(advisor_id PK, advisor_name, advisor_email, department_name FK)
```

**Students (final)** — now points at the advisor via a surrogate key instead:

```
Students(student_id PK, student_name, department_name FK, advisor_id FK, enrollment_year)
```

`Courses` still has `instructor_name → instructor_email` sitting in it. Since `instructor_email` is really just a fact about the instructor, and `course_code` is the only thing determining everything else in that table, this technically counts as a transitive dependency and would break strict 3NF. The simplest fix that still satisfies BCNF is putting a UNIQUE constraint on `instructor_email`, so the `instructor_name → instructor_email` rule is enforced as a uniqueness guarantee rather than something that could get duplicated inconsistently. A "real" production schema would probably split this into its own `Instructors` table, but for this assignment the UNIQUE constraint does the job — `course_code` is still the only determinant of non-key attributes, and instructor info only ever shows up once per course.

**Departments** — a small lookup table so `department_name` has somewhere to live, which lets `Students` and `Advisors` reference it properly:

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

Every non-key column in every table is determined by the whole primary key and nothing else. That's BCNF.

---

### Step 5 — Checking data integrity

| Integrity type | Satisfied? | Why |
|---|---|---|
| **Entity integrity** | Yes | Every table has a real PRIMARY KEY, and no PK column can be NULL. |
| **Referential integrity** | Yes | Every FK uses REFERENCES with ON UPDATE CASCADE / ON DELETE RESTRICT (CASCADE for Enrollments), so nothing can end up pointing at a row that doesn't exist. |
| **Domain integrity** | Yes | Column types are all constrained (INT, VARCHAR, DECIMAL), CHECK constraints keep `marks_obtained` between 0–100 and `enrollment_year` between 1900–2100, and UNIQUE constraints stop duplicate emails. |
| **User-defined integrity** | Yes | The CHECK on `marks_obtained` enforces the business rule that marks have to be a valid percentage. Anything more specific (like capacity limits) would live at the application layer or in triggers. |

---

## Design Decisions

### Data types

| Column | Type | Why |
|---|---|---|
| `student_id`, `advisor_id` | INT | Surrogate integer keys are small and quick to index. |
| `marks_obtained` | DECIMAL(5,2) | Fixed-point so there's no floating-point rounding weirdness; handles values like 78.50 fine. |
| `enrollment_year` | INT | A 4-digit year fits comfortably in an INT — no need for a full date/time. |
| Name / email columns | VARCHAR(150/200/255) | Variable length saves space compared to CHAR; lengths are just conservative guesses. |
| `course_code` | VARCHAR(20) | Short alphanumeric codes like CS101 — VARCHAR avoids wasted padding. |

### Constraints

- **UNIQUE on the email columns** — stops two advisors (or instructors) from sharing an email, which would make it useless as a unique contact identifier.
- **ON DELETE CASCADE on Enrollments.student_id** — deleting a student cleans up their enrollment rows automatically instead of leaving orphaned junction rows behind.
- **ON DELETE RESTRICT on the course/department FKs** — stops you from accidentally deleting a department that still has students, or a course that still has people enrolled.
- **DEFAULT 2024 on enrollment_year** — just a stand-in for "current year" for this assignment; a real system would pull that from a trigger or the application layer.
- **CHECK (marks_obtained BETWEEN 0 AND 100)** — enforces the rule at the database level no matter what the application sends in.

### Why Advisors gets a surrogate key

`advisor_name` isn't used as the PK even though it's the attribute the dependency is built around. Names make bad keys — people share names, and names change. A surrogate `advisor_id INT` is more stable and just performs better in joins anyway.

---

## Task 1.5 — Transaction Analysis

### 1.5a — Moving a student between courses

Moving student 101 from CS101 to CS404 is wrapped in one transaction, so either both steps go through or neither does. If inserting into CS404 fails — say, because CS404 doesn't actually exist and the FK constraint kicks in — the app rolls back, and the student stays enrolled in CS101 instead of ending up with no course at all.

### 1.5b — Non-repeatable read

T1 reads student 101's marks. T2 comes along, updates that value, and commits. T1 reads the same row again and now sees something different. That's a **non-repeatable read**. The lowest isolation level that stops it is **REPEATABLE READ** — at that level, once a transaction has read a row, it keeps seeing the same value for the rest of the transaction no matter what else gets committed. READ COMMITTED doesn't give you that guarantee.

### 1.5c — Phantom insert / going over capacity

Two transactions both check the enrollment count for a course, both see room available, and both insert a new enrollment — and now the course is over capacity. This is a **phantom read**: both transactions acted on the same pre-insert count, and neither would have gone ahead if it had seen the other's write. The lowest isolation level that actually prevents this is **SERIALIZABLE**. REPEATABLE READ stops non-repeatable reads on rows you've already fetched, but it won't stop new rows from showing up in a range you've already queried. SERIALIZABLE catches that conflicting range access and aborts one of the transactions.

### 1.5d — MVCC and consistent snapshots

Under **MVCC**, the database keeps multiple versions of each row around. When a transaction starts, it gets assigned an ID, and that ID determines which version of each row it's allowed to see.

- If reporting transaction R runs at **READ COMMITTED**, its snapshot refreshes at the start of every statement. So once write transaction W commits, R's next SELECT sees the new value (90), because a new statement means a fresh snapshot.
- If R runs at **REPEATABLE READ** (or SNAPSHOT isolation), its snapshot gets locked in once, right when the transaction starts. W's update creates a newer row version, but R keeps getting served the old one (marks = 78) since that's the version that existed when R's snapshot was taken. Neither transaction blocks the other — that's really the whole point of MVCC over lock-based isolation.

So the isolation level that keeps a consistent snapshot for the entire transaction is **REPEATABLE READ** (SQL Server calls this SNAPSHOT isolation; Postgres's REPEATABLE READ works the same way, with full snapshot semantics).

**Trade-off vs READ COMMITTED:**

REPEATABLE READ means the database has to hold onto old row versions (dead tuples in Postgres, undo segments in Oracle/InnoDB) for as long as any REPEATABLE READ transaction stays open. A long-running report can cause real version-store bloat — in Postgres specifically, autovacuum can't clean up dead tuples that some open transaction might still need, so tables and indexes bloat and query performance suffers cluster-wide. READ COMMITTED sidesteps this because its per-statement snapshots let old versions get cleaned up much sooner.
