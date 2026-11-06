import random, unicodedata, sys
rng = random.Random(13213)  # seed cố định -> seed SQL xác định
ho = ["Nguyễn","Trần","Lê","Phạm","Hoàng","Huỳnh","Phan","Vũ","Võ","Đặng","Bùi","Đỗ","Hồ","Ngô","Dương"]
dem = ["Văn","Thị","Minh","Hoàng","Ngọc","Thanh","Quốc","Thu","Gia","Bảo","Anh","Hữu"]
ten = ["An","Bình","Châu","Dũng","Giang","Hà","Hải","Hiếu","Hương","Khánh","Lan","Long","Mai","Nam",
       "Ngân","Phúc","Quang","Quỳnh","Sơn","Tâm","Thảo","Trang","Trí","Tuấn","Uyên","Vy","Yến","Đức","Linh","Phong"]
pos = {"D01":["Chuyên viên nhân sự","Trưởng phòng"],"D02":["Kỹ sư","Kỹ thuật viên"],
       "D03":["Nhân viên kinh doanh","Trưởng nhóm"],"D04":["Kế toán viên","Kế toán trưởng"],
       "D05":["Công nhân","Tổ trưởng"]}
def ascii(s):
    s = s.replace("Đ","D").replace("đ","d")
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn").lower()
resigned = {7,15,23,38,49}
null_email, blank_email = 11, 29
rows, used = [], set()
for i in range(1, 51):
    while True:
        parts = [rng.choice(ho), rng.choice(dem)] + ([rng.choice(dem)] if i in (5,33) else []) + [rng.choice(ten)]
        name = " ".join(parts)
        if name not in used: used.add(name); break
    eid = f"E{i:04d}"
    dept = f"D{(i-1)%5+1:02d}"
    shift = f"S{(i-1)%3+1}"
    gender = "F" if parts[1] == "Thị" else rng.choice("MF")
    dob = f"{rng.randint(1975,2003)}-{rng.randint(1,12):02d}-{rng.randint(1,28):02d}"
    hire = f"{rng.randint(2015,2025)}-{rng.randint(1,12):02d}-{rng.randint(1,28):02d}"
    email = f"{ascii(parts[-1])}.{ascii(parts[0])[0]}{i:02d}@lab.invalid"
    email_sql = "NULL" if i == null_email else ("''" if i == blank_email else f"'{email}'")
    phone = f"09{rng.randint(10000000,99999999)}"
    salary = rng.randrange(8_000_000, 40_000_001, 500_000)
    status = "resigned" if i in resigned else "active"
    upd = f"2026-10-01 01:{i:02d}:00.000000"
    rows.append(f"('{eid}','{name}','{dob}','{gender}','{dept}','{rng.choice(pos[dept])}',{email_sql},'{phone}',{salary},'{shift}','{hire}','{status}','{upd}')")
print("-- Sinh tự động bởi sql/tools/gen_seed.py (seed 13213). Dữ liệu giả, không phải người thật.")
print("-- Chạy lại an toàn: INSERT IGNORE không nhân đôi và không ghi đè dữ liệu đã sửa. Reset: sql/90_reset.sql")
print("SET NAMES utf8mb4;\nUSE hr_db;\n")
print("INSERT IGNORE INTO departments (department_id, department_name) VALUES")
print(",\n".join(["('D01','Phòng Hành chính - Nhân sự')","('D02','Phòng Kỹ thuật')","('D03','Phòng Kinh doanh')","('D04','Phòng Kế toán')","('D05','Phòng Sản xuất')"]) + ";\n")
print("INSERT IGNORE INTO employees (employee_id, full_name, dob, gender, department_id, position, email, phone, base_salary, shift_id, hire_date, status, updated_at) VALUES")
print(",\n".join(rows) + ";")
