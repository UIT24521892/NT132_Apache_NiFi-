-- Schema nguồn hr_db cho PG-JDBC (SPECS 5.2). Dữ liệu giả. Chạy lại an toàn.
-- updated_at lưu UTC: mysqld đặt default-time-zone='+00:00' (infra/db/zz-nt132.cnf).
SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS hr_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE hr_db;

CREATE TABLE IF NOT EXISTS departments (
  department_id   CHAR(3)      NOT NULL,
  department_name VARCHAR(100) NOT NULL,
  PRIMARY KEY (department_id),
  CONSTRAINT chk_dept_id   CHECK (department_id REGEXP '^D[0-9]{2}$'),
  CONSTRAINT chk_dept_name CHECK (CHAR_LENGTH(TRIM(department_name)) > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS employees (
  employee_id   CHAR(5)       NOT NULL,
  full_name     VARCHAR(100)  NOT NULL,
  dob           DATE          NOT NULL,
  gender        ENUM('M','F') NOT NULL,
  department_id CHAR(3)       NOT NULL,
  position      VARCHAR(100)  NOT NULL,
  email         VARCHAR(255)  NULL,
  phone         VARCHAR(20)   NOT NULL,
  base_salary   DECIMAL(12,0) NOT NULL,
  shift_id      CHAR(2)       NOT NULL,
  hire_date     DATE          NOT NULL,
  status        ENUM('active','resigned') NOT NULL DEFAULT 'active',
  updated_at    DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (employee_id),
  KEY idx_emp_dept (department_id),
  CONSTRAINT fk_emp_dept FOREIGN KEY (department_id) REFERENCES departments (department_id),
  CONSTRAINT chk_emp_id    CHECK (employee_id REGEXP '^E[0-9]{4}$'),
  CONSTRAINT chk_emp_shift CHECK (shift_id IN ('S1','S2','S3')),
  CONSTRAINT chk_emp_name  CHECK (CHAR_LENGTH(TRIM(full_name)) > 0)
) ENGINE=InnoDB;
