-- RESET dữ liệu hr_db về seed ban đầu. CHỈ chạy khi cố ý reset (xóa mọi thay đổi TC-08).
-- Cách dùng: sudo mysql < sql/90_reset.sql && sudo mysql < sql/02_seed.sql
USE hr_db;
DELETE FROM employees;
DELETE FROM departments;
