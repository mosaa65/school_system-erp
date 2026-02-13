-- 🏫 School Management System
-- 📂 System 05: Teaching & Grading (التعليم والدرجات)
-- 👨‍💻 Engineer: عمار الشعيبي
-- 🏗️ Architectural Refactor: Antigravity AI (Based on Senior Architect Review)

-- التاريخ: 2026-01-16
-- الإصدار: 2.0 (Deep Refactored)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 0. سياسات الدرجات والأوزان (Grading Policies)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS grading_policies (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    academic_year_id INT UNSIGNED NOT NULL,
    grade_level_id INT UNSIGNED NOT NULL,
    subject_id INT UNSIGNED NOT NULL,
    
    -- الأوزان القصوى (تحديث v2.1 2026 - بناءً على نموذج التقييم الجديد)
    max_exam_score DECIMAL(5,2) DEFAULT 5.00 COMMENT 'الاختبار (5)',
    max_homework_score DECIMAL(5,2) DEFAULT 5.00 COMMENT 'الواجب (5)',
    max_attendance_score DECIMAL(5,2) DEFAULT 4.00 COMMENT 'المواظبة (4 حسب المعادلة)',
    max_activity_score DECIMAL(5,2) DEFAULT 5.00 COMMENT 'النشاط (5)',
    
    -- عناصر التقييم الجديدة
    max_reading_score DECIMAL(5,2) DEFAULT 5.00 COMMENT 'القراءة (5)',
    max_writing_score DECIMAL(5,2) DEFAULT 5.00 COMMENT 'الكتابة (5)',
    max_behavior_score DECIMAL(5,2) DEFAULT 5.00 COMMENT 'السلوك/المظهر (5)',
    max_community_score DECIMAL(5,2) DEFAULT 5.00 COMMENT 'المساهمة المجتمعية (5)',
    
    passing_score DECIMAL(5,2) DEFAULT 50.00 COMMENT 'درجة النجاح المئوية',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    created_by_user_id INT UNSIGNED NULL,
    
    UNIQUE KEY uk_policy (academic_year_id, grade_level_id, subject_id),
    FOREIGN KEY (academic_year_id) REFERENCES academic_years(id),
    FOREIGN KEY (grade_level_id) REFERENCES grade_levels(id),
    FOREIGN KEY (subject_id) REFERENCES subjects(id),
    FOREIGN KEY (created_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='سياسات الدرجات والأوزان لكل مادة وصف';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. الاختبارات والنتائج
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS exam_periods (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    academic_year_id INT UNSIGNED NOT NULL,
    semester_id INT UNSIGNED NOT NULL,
    name VARCHAR(100) NOT NULL COMMENT 'مثل: اختبار شهر محرم، اختبار منتصف الفصل الثاني',
    type ENUM('MONTHLY', 'MIDTERM', 'FINAL', 'DIAGNOSTIC') DEFAULT 'MONTHLY',
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- قفل البيانات (Intelligence Layer)
    is_locked BOOLEAN DEFAULT FALSE COMMENT 'قفل الفترة لمنع التعديل',
    locked_at TIMESTAMP NULL,
    locked_by_user_id INT UNSIGNED NULL,
    
    FOREIGN KEY (academic_year_id) REFERENCES academic_years(id),
    FOREIGN KEY (semester_id) REFERENCES semesters(id),
    FOREIGN KEY (locked_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='الفترات الامتحانية';

CREATE TABLE IF NOT EXISTS exam_schedules (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    exam_period_id INT UNSIGNED NOT NULL,
    subject_id INT UNSIGNED NOT NULL,
    grade_level_id INT UNSIGNED NOT NULL,
    exam_date DATE NOT NULL,
    max_score DECIMAL(5,2) NOT NULL COMMENT 'يجب أن يتبع grading_policy',
    
    UNIQUE KEY uk_exam (exam_period_id, subject_id, grade_level_id),
    FOREIGN KEY (exam_period_id) REFERENCES exam_periods(id) ON DELETE CASCADE,
    FOREIGN KEY (subject_id) REFERENCES subjects(id),
    FOREIGN KEY (grade_level_id) REFERENCES grade_levels(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='جدول مواعيد الاختبارات';

CREATE TABLE IF NOT EXISTS student_exam_scores (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    exam_schedule_id INT UNSIGNED NOT NULL,
    enrollment_id INT UNSIGNED NOT NULL COMMENT 'Correct FK: To student_enrollments',
    score DECIMAL(5,2) DEFAULT 0.00,
    is_present BOOLEAN DEFAULT TRUE,
    excuse_details TEXT NULL COMMENT 'للطلاب الغائبين بعذر',
    teacher_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_student_exam (exam_schedule_id, enrollment_id),
    FOREIGN KEY (exam_schedule_id) REFERENCES exam_schedules(id) ON DELETE CASCADE,
    FOREIGN KEY (enrollment_id) REFERENCES student_enrollments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='درجات الطلاب في الاختبارات';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. الواجبات المنزلية
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS homeworks (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    academic_year_id INT UNSIGNED NOT NULL,
    employee_id INT UNSIGNED NOT NULL COMMENT 'المعلم',
    classroom_id INT UNSIGNED NOT NULL,
    subject_id INT UNSIGNED NOT NULL,
    homework_date DATE DEFAULT (CURRENT_DATE),
    title VARCHAR(200) NOT NULL,
    content TEXT,
    max_grade DECIMAL(4,1) DEFAULT 5.0,
    
    FOREIGN KEY (academic_year_id) REFERENCES academic_years(id),
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (classroom_id) REFERENCES classrooms(id),
    FOREIGN KEY (subject_id) REFERENCES subjects(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='تعريف الواجبات';

CREATE TABLE IF NOT EXISTS student_homeworks (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    homework_id INT UNSIGNED NOT NULL,
    enrollment_id INT UNSIGNED NOT NULL,
    status ENUM('COMPLETED', 'INCOMPLETE', 'LATE', 'EXCUSED') DEFAULT 'COMPLETED',
    grade DECIMAL(4,1) DEFAULT NULL,
    teacher_feedback TEXT,
    
    UNIQUE KEY uk_student_homework (homework_id, enrollment_id),
    FOREIGN KEY (homework_id) REFERENCES homeworks(id) ON DELETE CASCADE,
    FOREIGN KEY (enrollment_id) REFERENCES student_enrollments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='رصد واجبات الطلاب';

-- ═══════════════════════════════════════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. تجميع النتائج (Normalization applied: Views are preferred for logic)
-- ═══════════════════════════════════════════════════════════════════════════════

-- -----------------------------------------------------------------------------
-- 3.0 جدول حالات اعتماد الدرجات (جديد - داخلي)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_grading_statuses (
    id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name_ar VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO lookup_grading_statuses (name_ar) VALUES
('مسودة'), ('قيد المراجعة'), ('معتمد'), ('مرحل للأرشيف');

CREATE TABLE IF NOT EXISTS monthly_grades (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    enrollment_id INT UNSIGNED NOT NULL,
    subject_id INT UNSIGNED NOT NULL,
    month_id INT UNSIGNED NOT NULL,
    
    attendance_score DECIMAL(5,2) DEFAULT 0 COMMENT 'يحسب آلياً: عدد أيام الحضور / 5',
    homework_score DECIMAL(5,2) DEFAULT 0,
    activity_score DECIMAL(5,2) DEFAULT 0,
    exam_score DECIMAL(5,2) DEFAULT 0 COMMENT 'متوسط الاختبارات',
    
    -- العناصر الجديدة (New Components)
    reading_score DECIMAL(5,2) DEFAULT 0 COMMENT 'القراءة',
    writing_score DECIMAL(5,2) DEFAULT 0 COMMENT 'الكتابة / الخط',
    behavior_score DECIMAL(5,2) DEFAULT 0 COMMENT 'السلوك والمظهر والكتب',
    community_score DECIMAL(5,2) DEFAULT 0 COMMENT 'المساهمة المجتمعية',
    
    UNIQUE KEY uk_monthly (enrollment_id, subject_id, month_id),
    FOREIGN KEY (enrollment_id) REFERENCES student_enrollments(id),
    FOREIGN KEY (subject_id) REFERENCES subjects(id),
    FOREIGN KEY (month_id) REFERENCES academic_months(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='المحصلة الشهرية للمادة';

CREATE TABLE IF NOT EXISTS semester_grades (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    enrollment_id INT UNSIGNED NOT NULL,
    subject_id INT UNSIGNED NOT NULL,
    semester_id INT UNSIGNED NOT NULL,
    
    semester_work_total DECIMAL(5,2) COMMENT 'مجموع المحصلات الشهرية',
    final_exam_score DECIMAL(5,2) COMMENT 'درجة الاختبار النهائي للفصل',
    
    -- الاعتماد والحوكمة (Governance Layer)
    status_id TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'FK to lookup_grading_statuses',
    approved_by_user_id INT UNSIGNED NULL COMMENT 'صاحب القرار النهائي',
    approved_at TIMESTAMP NULL,
    
    UNIQUE KEY uk_semester (enrollment_id, subject_id, semester_id),
    FOREIGN KEY (enrollment_id) REFERENCES student_enrollments(id),
    FOREIGN KEY (subject_id) REFERENCES subjects(id),
    FOREIGN KEY (semester_id) REFERENCES semesters(id),
    FOREIGN KEY (status_id) REFERENCES lookup_grading_statuses(id),
    FOREIGN KEY (approved_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='نتيجة الفصل الدراسي';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. تحضير الدروس
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS lesson_preparation (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    employee_id INT UNSIGNED NOT NULL,
    subject_id INT UNSIGNED NOT NULL,
    classroom_id INT UNSIGNED NOT NULL,
    prep_date DATE NOT NULL,
    lesson_title VARCHAR(255) NOT NULL,
    objectives TEXT,
    strategies TEXT,
    aids TEXT,
    is_approved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (subject_id) REFERENCES subjects(id),
    FOREIGN KEY (classroom_id) REFERENCES classrooms(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='تحضير خطط الدروس';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. سجل التدقيق والذكاء (Audit & Analytics Layer)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS student_grade_audit (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    grade_table ENUM('student_exam_scores', 'student_homeworks', 'monthly_grades', 'semester_grades') NOT NULL,
    record_id INT UNSIGNED NOT NULL,
    
    -- البيانات
    old_score DECIMAL(5,2),
    new_score DECIMAL(5,2),
    
    -- الهوية والسبب
    changed_by_user_id INT UNSIGNED NOT NULL,
    change_reason VARCHAR(255),
    
    -- التوقيت
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    
    FOREIGN KEY (changed_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='سجل تعديلات الدرجات (الشفافية والحوكمة)';

CREATE OR REPLACE VIEW v_sgas_class_ranking AS
SELECT 
    sg.semester_id,
    c.id AS classroom_id,
    c.name_ar AS classroom_name,
    s.id AS student_id,
    s.full_name AS student_name,
    SUM(sg.semester_work_total + IFNULL(sg.final_exam_score, 0)) AS total_marks,
    RANK() OVER (PARTITION BY c.id, sg.semester_id ORDER BY SUM(sg.semester_work_total + IFNULL(sg.final_exam_score, 0)) DESC) as rank_in_class
FROM semester_grades sg
JOIN student_enrollments se ON sg.enrollment_id = se.id
JOIN students s ON se.student_id = s.id
JOIN classrooms c ON se.classroom_id = c.id
GROUP BY sg.semester_id, c.id, s.id, s.full_name;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. الإجراءات المخزنة (Stored Procedures)
-- ═══════════════════════════════════════════════════════════════════════════════

DELIMITER //

-- احتساب درجة المواظبة الشهرية
-- المعادلة: الدرجة = عدد أيام الحضور ÷ 5
CREATE PROCEDURE IF NOT EXISTS sp_calculate_monthly_attendance(
    IN p_month_id INT,
    IN p_classroom_id INT
)
BEGIN
    -- تحديث درجات الطلاب في الصف المحدد للشهر المحدد
    UPDATE monthly_grades mg
    JOIN (
        SELECT 
            enrollment_id,
            COUNT(*) as days_present
        FROM student_attendance sa
        WHERE MONTH(sa.attendance_date) = (SELECT order_num FROM lookup_hijri_months WHERE id = p_month_id) -- تبسيط: نحتاج ربط أدق بالأشهر الأكاديمية
          AND sa.status_id = (SELECT id FROM lookup_attendance_statuses WHERE code = 'PRESENT')
        GROUP BY enrollment_id
    ) attendance_counts ON mg.enrollment_id = attendance_counts.enrollment_id
    SET mg.attendance_score = (attendance_counts.days_present / 5)
    WHERE mg.month_id = p_month_id
      AND mg.enrollment_id IN (SELECT id FROM student_enrollments WHERE classroom_id = p_classroom_id);
      
    -- ملاحظة: هذا الإجراء يفترض وجود ربط صحيح بين المعرف month_id والشهر الفعلي في التواريخ
    -- سيتم تحسين منطق التواريخ عند تفعيل التقويم الأكاديمي بشكل كامل
END //

DELIMITER ;


-- ═══════════════════════════════════════════════════════════════════════════════
-- رسالة اكتمال التنفيذ
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT '✅ تم تحديث جداول نظام التعليم والدرجات (SGAS) بنجاح!' AS message;
SELECT '📌 تنبيه: تم نقل لوجستيات اللجان والمقاعد إلى System 08' AS note;
