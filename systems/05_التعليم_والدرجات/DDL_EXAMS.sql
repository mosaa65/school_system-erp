-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║           نظام الدرجات والتقويم الذكي (SGAS) - v3.3                        ║
-- ║           ملف 2: الاختبارات والفترات الامتحانية (Exams & Scheduling)        ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- التاريخ: 2026-02-14
-- الإصدار: 3.3 (Policy-aware validation + lock governance)
-- الاعتمادات: DDL_POLICIES, System 01, System 02, System 04

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. الفترات الامتحانية
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS exam_periods (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    academic_year_id INT UNSIGNED NOT NULL,
    semester_id INT UNSIGNED NOT NULL,
    name VARCHAR(100) NOT NULL COMMENT 'مثل: اختبار شهر محرم، اختبار منتصف الفصل الثاني',
    type ENUM('MONTHLY', 'MIDTERM', 'FINAL', 'DIAGNOSTIC', 'CUSTOM') DEFAULT 'MONTHLY',
    start_date DATE NOT NULL COMMENT 'تاريخ بداية الفترة',
    end_date DATE NOT NULL COMMENT 'تاريخ نهاية الفترة',
    is_active BOOLEAN DEFAULT TRUE,

    -- التوثيق
    created_by INT UNSIGNED NOT NULL COMMENT 'المستخدم الذي أنشأ الفترة (FK → users)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- قفل البيانات (Governance Layer)
    is_locked BOOLEAN DEFAULT FALSE COMMENT 'قفل الفترة لمنع التعديل',
    locked_at TIMESTAMP NULL,
    locked_by_user_id INT UNSIGNED NULL,

    CHECK (end_date >= start_date),

    INDEX idx_ep_year (academic_year_id),
    INDEX idx_ep_semester (semester_id),
    INDEX idx_ep_type (type),
    INDEX idx_ep_active (is_active),

    FOREIGN KEY (academic_year_id) REFERENCES academic_years(id),
    FOREIGN KEY (semester_id) REFERENCES semesters(id),
    FOREIGN KEY (created_by) REFERENCES users(id),
    FOREIGN KEY (locked_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='الفترات الامتحانية (مرتبطة بالعام والفصل)';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. جدولة الاختبارات
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS exam_schedules (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    exam_period_id INT UNSIGNED NOT NULL,
    subject_id INT UNSIGNED NOT NULL,
    grade_level_id INT UNSIGNED NOT NULL COMMENT 'الصف — الاختبار موحد لكل شعب الصف',
    exam_date DATE NOT NULL,

    -- وقت الاختبار
    start_time TIME NULL COMMENT 'وقت بداية الاختبار',
    duration_minutes SMALLINT UNSIGNED NULL COMMENT 'مدة الاختبار بالدقائق',

    max_score DECIMAL(5,2) NOT NULL COMMENT 'يجب أن يتبع grading_policy لنوع الفترة',

    -- التوثيق
    created_by INT UNSIGNED NOT NULL COMMENT 'المستخدم الذي جدول الاختبار',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uk_exam (exam_period_id, subject_id, grade_level_id),
    INDEX idx_es_date (exam_date),
    INDEX idx_es_subject (subject_id),

    FOREIGN KEY (exam_period_id) REFERENCES exam_periods(id) ON DELETE CASCADE,
    FOREIGN KEY (subject_id) REFERENCES subjects(id),
    FOREIGN KEY (grade_level_id) REFERENCES grade_levels(id),
    FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='جدول مواعيد الاختبارات (كل اختبار = فترة + مادة + صف)';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. درجات الطلاب في الاختبارات
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS student_exam_scores (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    exam_schedule_id INT UNSIGNED NOT NULL,
    enrollment_id INT UNSIGNED NOT NULL COMMENT 'FK → student_enrollments',

    -- الدرجة
    score DECIMAL(5,2) DEFAULT 0.00,

    -- الحضور والغياب
    is_present BOOLEAN DEFAULT TRUE,
    absence_type ENUM('بعذر', 'بدون_عذر') NULL COMMENT 'نوع الغياب — NULL إذا حاضر',
    excuse_details TEXT NULL COMMENT 'تفاصيل العذر (للغائبين بعذر)',

    -- ملاحظات
    teacher_notes TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_student_exam (exam_schedule_id, enrollment_id),
    INDEX idx_ses_enrollment (enrollment_id),
    INDEX idx_ses_present (is_present),

    FOREIGN KEY (exam_schedule_id) REFERENCES exam_schedules(id) ON DELETE CASCADE,
    FOREIGN KEY (enrollment_id) REFERENCES student_enrollments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='درجات الطلاب في الاختبارات (مع تصنيف الغياب)';

DELIMITER //

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. Triggers: التحقق من exam_schedules مع السياسات والقفل
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TRIGGER trg_exam_schedule_validate_insert
BEFORE INSERT ON exam_schedules
FOR EACH ROW
BEGIN
    DECLARE v_period_type VARCHAR(20);
    DECLARE v_period_year INT;
    DECLARE v_period_start DATE;
    DECLARE v_period_end DATE;
    DECLARE v_is_locked BOOLEAN;
    DECLARE v_policy_max DECIMAL(5,2);

    SELECT ep.type, ep.academic_year_id, ep.start_date, ep.end_date, ep.is_locked
    INTO v_period_type, v_period_year, v_period_start, v_period_end, v_is_locked
    FROM exam_periods ep
    WHERE ep.id = NEW.exam_period_id
    LIMIT 1;

    IF v_period_type IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'الفترة الامتحانية غير موجودة';
    END IF;

    IF v_is_locked = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'لا يمكن إضافة اختبار داخل فترة امتحانية مقفلة';
    END IF;

    IF NEW.exam_date < v_period_start OR NEW.exam_date > v_period_end THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'تاريخ الاختبار خارج نطاق الفترة الامتحانية';
    END IF;

    IF NEW.max_score <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'الدرجة العظمى للاختبار يجب أن تكون أكبر من صفر';
    END IF;

    SELECT gp.max_exam_score
    INTO v_policy_max
    FROM grading_policies gp
    WHERE gp.academic_year_id = v_period_year
      AND gp.grade_level_id = NEW.grade_level_id
      AND gp.subject_id = NEW.subject_id
      AND gp.exam_period_type = v_period_type
    LIMIT 1;

    IF v_policy_max IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'لا توجد سياسة درجات لهذا الصف/المادة/نوع الاختبار';
    END IF;

    IF NEW.max_score > v_policy_max THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'الدرجة العظمى للاختبار تتجاوز الحد المعتمد في السياسة';
    END IF;
END//

CREATE TRIGGER trg_exam_schedule_validate_update
BEFORE UPDATE ON exam_schedules
FOR EACH ROW
BEGIN
    DECLARE v_old_locked BOOLEAN;
    DECLARE v_new_type VARCHAR(20);
    DECLARE v_new_year INT;
    DECLARE v_new_start DATE;
    DECLARE v_new_end DATE;
    DECLARE v_new_locked BOOLEAN;
    DECLARE v_policy_max DECIMAL(5,2);

    SELECT ep.is_locked
    INTO v_old_locked
    FROM exam_periods ep
    WHERE ep.id = OLD.exam_period_id
    LIMIT 1;

    IF v_old_locked = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'لا يمكن تعديل اختبار مرتبط بفترة امتحانية مقفلة';
    END IF;

    SELECT ep.type, ep.academic_year_id, ep.start_date, ep.end_date, ep.is_locked
    INTO v_new_type, v_new_year, v_new_start, v_new_end, v_new_locked
    FROM exam_periods ep
    WHERE ep.id = NEW.exam_period_id
    LIMIT 1;

    IF v_new_type IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'الفترة الامتحانية الجديدة غير موجودة';
    END IF;

    IF v_new_locked = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'لا يمكن نقل/تعديل الاختبار إلى فترة امتحانية مقفلة';
    END IF;

    IF NEW.exam_date < v_new_start OR NEW.exam_date > v_new_end THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'تاريخ الاختبار خارج نطاق الفترة الامتحانية';
    END IF;

    IF NEW.max_score <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'الدرجة العظمى للاختبار يجب أن تكون أكبر من صفر';
    END IF;

    SELECT gp.max_exam_score
    INTO v_policy_max
    FROM grading_policies gp
    WHERE gp.academic_year_id = v_new_year
      AND gp.grade_level_id = NEW.grade_level_id
      AND gp.subject_id = NEW.subject_id
      AND gp.exam_period_type = v_new_type
    LIMIT 1;

    IF v_policy_max IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'لا توجد سياسة درجات لهذا الصف/المادة/نوع الاختبار';
    END IF;

    IF NEW.max_score > v_policy_max THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'الدرجة العظمى للاختبار تتجاوز الحد المعتمد في السياسة';
    END IF;
END//

CREATE TRIGGER trg_exam_schedule_lock_delete
BEFORE DELETE ON exam_schedules
FOR EACH ROW
BEGIN
    DECLARE v_is_locked BOOLEAN;

    SELECT ep.is_locked
    INTO v_is_locked
    FROM exam_periods ep
    WHERE ep.id = OLD.exam_period_id
    LIMIT 1;

    IF v_is_locked = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'لا يمكن حذف اختبار مرتبط بفترة امتحانية مقفلة';
    END IF;
END//

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. Triggers: التحقق من student_exam_scores + احترام قفل الفترة
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TRIGGER trg_exam_score_validate_insert
BEFORE INSERT ON student_exam_scores
FOR EACH ROW
BEGIN
    DECLARE v_max_score DECIMAL(5,2);
    DECLARE v_is_locked BOOLEAN;

    SELECT es.max_score, ep.is_locked
    INTO v_max_score, v_is_locked
    FROM exam_schedules es
    JOIN exam_periods ep ON es.exam_period_id = ep.id
    WHERE es.id = NEW.exam_schedule_id
    LIMIT 1;

    IF v_max_score IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'الاختبار غير موجود';
    END IF;

    IF v_is_locked = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'لا يمكن إدخال درجات في فترة امتحانية مقفلة';
    END IF;

    IF NEW.score > v_max_score THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'الدرجة المدخلة أعلى من الدرجة العظمى للاختبار';
    END IF;

    IF NEW.score < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'لا يمكن إدخال درجة سالبة';
    END IF;

    IF NEW.is_present = FALSE AND NEW.score > 0 THEN
        SET NEW.score = 0;
    END IF;

    IF NEW.is_present = FALSE AND NEW.absence_type IS NULL THEN
        SET NEW.absence_type = 'بدون_عذر';
    END IF;

    IF NEW.is_present = TRUE THEN
        SET NEW.absence_type = NULL;
        SET NEW.excuse_details = NULL;
    END IF;
END//

CREATE TRIGGER trg_exam_score_validate_update
BEFORE UPDATE ON student_exam_scores
FOR EACH ROW
BEGIN
    DECLARE v_max_score DECIMAL(5,2);
    DECLARE v_is_locked BOOLEAN;

    SELECT es.max_score, ep.is_locked
    INTO v_max_score, v_is_locked
    FROM exam_schedules es
    JOIN exam_periods ep ON es.exam_period_id = ep.id
    WHERE es.id = NEW.exam_schedule_id
    LIMIT 1;

    IF v_is_locked = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'لا يمكن تعديل درجات فترة امتحانية مقفلة';
    END IF;

    IF NEW.score > v_max_score THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'الدرجة المدخلة أعلى من الدرجة العظمى للاختبار';
    END IF;

    IF NEW.score < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'لا يمكن إدخال درجة سالبة';
    END IF;

    IF NEW.is_present = FALSE AND NEW.score > 0 THEN
        SET NEW.score = 0;
    END IF;

    IF NEW.is_present = FALSE AND NEW.absence_type IS NULL THEN
        SET NEW.absence_type = 'بدون_عذر';
    END IF;

    IF NEW.is_present = TRUE THEN
        SET NEW.absence_type = NULL;
        SET NEW.excuse_details = NULL;
    END IF;
END//

CREATE TRIGGER trg_exam_score_lock_delete
BEFORE DELETE ON student_exam_scores
FOR EACH ROW
BEGIN
    DECLARE v_is_locked BOOLEAN;

    SELECT ep.is_locked
    INTO v_is_locked
    FROM exam_schedules es
    JOIN exam_periods ep ON es.exam_period_id = ep.id
    WHERE es.id = OLD.exam_schedule_id
    LIMIT 1;

    IF v_is_locked = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'لا يمكن حذف درجات من فترة امتحانية مقفلة';
    END IF;
END//

DELIMITER ;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. Procedure: رصد آلي لدرجات جميع طلاب الصف عند جدولة اختبار
-- ═══════════════════════════════════════════════════════════════════════════════

DELIMITER //

CREATE PROCEDURE sp_populate_exam_scores(IN p_exam_schedule_id INT)
BEGIN
    DECLARE v_grade_level_id INT;
    DECLARE v_academic_year_id INT;

    SELECT es.grade_level_id, ep.academic_year_id
    INTO v_grade_level_id, v_academic_year_id
    FROM exam_schedules es
    JOIN exam_periods ep ON ep.id = es.exam_period_id
    WHERE es.id = p_exam_schedule_id
    LIMIT 1;

    INSERT IGNORE INTO student_exam_scores (exam_schedule_id, enrollment_id, score, is_present)
    SELECT p_exam_schedule_id, se.id, 0.00, TRUE
    FROM student_enrollments se
    JOIN classrooms c ON se.classroom_id = c.id
    WHERE c.grade_level_id = v_grade_level_id
      AND c.academic_year_id = v_academic_year_id
      AND se.academic_year_id = v_academic_year_id
      AND se.is_active = TRUE;
END//

DELIMITER ;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. Trigger: استدعاء sp_populate_exam_scores بعد جدولة اختبار
-- ═══════════════════════════════════════════════════════════════════════════════

DELIMITER //

CREATE TRIGGER trg_exam_schedule_auto_populate
AFTER INSERT ON exam_schedules
FOR EACH ROW
BEGIN
    CALL sp_populate_exam_scores(NEW.id);
END//

DELIMITER ;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. View: ملخص نتائج اختبار
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW v_exam_results_summary AS
SELECT
    es.id AS exam_schedule_id,
    ep.name AS period_name,
    ep.type AS period_type,
    sub.name_ar AS subject_name,
    gl.name_ar AS grade_level_name,
    es.exam_date,
    es.max_score,
    COUNT(ses.id) AS total_students,
    SUM(CASE WHEN ses.is_present THEN 1 ELSE 0 END) AS present_count,
    SUM(CASE WHEN NOT ses.is_present THEN 1 ELSE 0 END) AS absent_count,
    SUM(CASE WHEN ses.absence_type = 'بعذر' THEN 1 ELSE 0 END) AS excused_absent,
    SUM(CASE WHEN ses.absence_type = 'بدون_عذر' THEN 1 ELSE 0 END) AS unexcused_absent,
    ROUND(AVG(CASE WHEN ses.is_present THEN ses.score END), 2) AS avg_score,
    MAX(CASE WHEN ses.is_present THEN ses.score END) AS max_achieved_score,
    MIN(CASE WHEN ses.is_present THEN ses.score END) AS min_achieved_score,
    ROUND(AVG(CASE WHEN ses.is_present THEN (ses.score / NULLIF(es.max_score, 0)) * 100 END), 1) AS avg_percentage,
    SUM(
        CASE
            WHEN ses.is_present
             AND (ses.score / NULLIF(es.max_score, 0)) * 100 >= COALESCE(gp.passing_score, 50)
            THEN 1
            ELSE 0
        END
    ) AS passed_count,
    SUM(
        CASE
            WHEN ses.is_present
             AND (ses.score / NULLIF(es.max_score, 0)) * 100 < COALESCE(gp.passing_score, 50)
            THEN 1
            ELSE 0
        END
    ) AS failed_count
FROM exam_schedules es
JOIN exam_periods ep ON es.exam_period_id = ep.id
JOIN subjects sub ON es.subject_id = sub.id
JOIN grade_levels gl ON es.grade_level_id = gl.id
LEFT JOIN grading_policies gp ON gp.academic_year_id = ep.academic_year_id
    AND gp.grade_level_id = es.grade_level_id
    AND gp.subject_id = es.subject_id
    AND gp.exam_period_type = ep.type
LEFT JOIN student_exam_scores ses ON es.id = ses.exam_schedule_id
WHERE ep.is_active = TRUE
GROUP BY es.id, ep.name, ep.type, sub.name_ar, gl.name_ar, es.exam_date, es.max_score, gp.passing_score;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. جدول ربط الفترات الامتحانية بجلسات لجان الامتحانات (System 08)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS exam_session_periods (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    exam_session_id INT UNSIGNED NOT NULL COMMENT 'جلسة الامتحان اللوجستية (System 08)',
    exam_period_id INT UNSIGNED NOT NULL COMMENT 'الفترة الامتحانية الأكاديمية (System 05)',

    notes TEXT COMMENT 'ملاحظات',

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INT UNSIGNED NULL COMMENT 'المستخدم الذي أنشأ الربط',

    UNIQUE KEY uk_session_period (exam_session_id, exam_period_id),
    INDEX idx_esp_session (exam_session_id),
    INDEX idx_esp_period (exam_period_id),

    FOREIGN KEY (exam_session_id) REFERENCES exam_sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (exam_period_id) REFERENCES exam_periods(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='ربط الفترات الامتحانية الأكاديمية بجلسات لجان الامتحانات اللوجستية';

-- ═══════════════════════════════════════════════════════════════════════════════
SELECT '✅ DDL_EXAMS v3.3: تم إنشاء الاختبارات + الحوكمة + التحقق من السياسات بنجاح' AS message;
