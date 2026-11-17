-- Baseline nguồn VM2: mỗi dòng là check_name, PASS/FAIL, actual.
-- Không thay TC-06 (còn cần normalized output từ NiFi). Chỉ SELECT.
USE hr_db;
SELECT 'employee_total', IF(COUNT(*)=50,'PASS','FAIL'), COUNT(*) FROM employees;
SELECT 'active', IF(COUNT(*)=45,'PASS','FAIL'), COUNT(*) FROM employees WHERE status='active';
SELECT 'resigned', IF(COUNT(*)=5,'PASS','FAIL'), COUNT(*) FROM employees WHERE status='resigned';
SELECT 'departments', IF(COUNT(*)=5,'PASS','FAIL'), COUNT(*) FROM departments;
SELECT 'shift_distribution',
  IF(SUM(shift_id='S1')=17 AND SUM(shift_id='S2')=17 AND SUM(shift_id='S3')=16,'PASS','FAIL'),
  CONCAT(SUM(shift_id='S1'),'/',SUM(shift_id='S2'),'/',SUM(shift_id='S3')) FROM employees;
SELECT 'email_null_blank', IF(SUM(email IS NULL OR TRIM(email)='')=2,'PASS','FAIL'),
  SUM(email IS NULL OR TRIM(email)='') FROM employees;
SELECT 'orphan_department', IF(COUNT(*)=0,'PASS','FAIL'), COUNT(*)
  FROM employees e LEFT JOIN departments d ON d.department_id=e.department_id WHERE d.department_id IS NULL;
SELECT 'utc_global_session',
  IF(@@global.time_zone IN ('+00:00','UTC') AND @@session.time_zone IN ('+00:00','UTC'),'PASS','FAIL'),
  CONCAT(@@global.time_zone,'/',@@session.time_zone);
SELECT 'employee_columns', IF(COUNT(*)=13,'PASS','FAIL'), COUNT(*)
  FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='hr_db' AND TABLE_NAME='employees';
SELECT 'updated_at_definition',
  IF(COUNT(*)=1,'PASS','FAIL'), COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA='hr_db' AND TABLE_NAME='employees' AND COLUMN_NAME='updated_at'
    AND DATA_TYPE='datetime' AND DATETIME_PRECISION=6 AND IS_NULLABLE='NO'
    AND LOWER(COLUMN_DEFAULT)='current_timestamp(6)'
    AND LOWER(EXTRA) LIKE '%on update current_timestamp(6)%';
