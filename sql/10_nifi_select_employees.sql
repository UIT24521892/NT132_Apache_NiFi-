-- Câu SELECT cho ExecuteSQLRecord trong PG-JDBC (full snapshot mỗi 60s, SPECS 5.2).
-- Chỉ đọc cột cần thiết; KHÔNG lọc status ở đây: lọc active và masking do NiFi làm.
SELECT e.employee_id,
       e.full_name,
       e.email,
       e.department_id,
       d.department_name,
       e.shift_id,
       e.status,
       e.updated_at
FROM hr_db.employees e
JOIN hr_db.departments d ON d.department_id = e.department_id
ORDER BY e.employee_id
