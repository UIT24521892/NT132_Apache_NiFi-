-- Kiểm tra seed (TC-06 phía nguồn): 50 nhân viên, 45 active, 5 resigned, 5 phòng ban, 3 ca.
USE hr_db;
SELECT COUNT(*) AS total, SUM(status='active') AS active, SUM(status='resigned') AS resigned FROM employees;
SELECT COUNT(*) AS departments FROM departments;
SELECT shift_id, COUNT(*) AS n FROM employees GROUP BY shift_id ORDER BY shift_id;
SELECT SUM(email IS NULL OR TRIM(email)='') AS email_null_or_blank FROM employees;
SELECT @@global.time_zone AS mysql_tz, NOW(6) AS now_utc;
SELECT employee_id, full_name, department_id, shift_id, status, updated_at FROM employees ORDER BY employee_id LIMIT 5;
